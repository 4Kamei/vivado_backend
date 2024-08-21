import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

CLOCK_FREQUENCY = 200_000_000#1000000
BAUD_RATE = 115200#_12000

class TB():

    def __init__(self, dut, clock_freq, baud_rate):
        self.dut = dut
        self.baud_rate = baud_rate
        self.clock_freq = clock_freq
    
    def start(self):
        clock_period = int(10 ** 12/self.clock_freq) #picos
        print("clock period is {}".format(clock_period))
        clock = Clock(self.dut.i_clk, clock_period, "ps")
        cocotb.fork(clock.start())

    async def reset(self):
        self.dut.i_uart_rx.value = 1
        await ClockCycles(self.dut.i_clk, 1)
        self.dut.i_rst_n.value = 0
        await ClockCycles(self.dut.i_clk, 1)
        self.dut.i_rst_n.value = 1

    async def wait_clock(self):
        await Timer(int(10 ** 9/self.baud_rate), "ns")

    async def transmit(self, byte, num_bits=8):    
        self.dut.i_uart_rx.value = 0

        await self.wait_clock()
    
        for i in range(num_bits):
            bit = (byte >> i) & 1
            self.dut.i_uart_rx.value = bit
            await self.wait_clock()

        self.dut.i_uart_rx.value = 1


    async def verify_receive(self, byte):
        iters = 0
        while True:
            iters += 1
            if iters >= UART_PACKET_END_TIMEOUT:
                assert False, "Waiting for o_rx_en to rise after reading packet timed out"
            if self.dut.o_rx_en.value == 1:
                break 
            await RisingEdge(self.dut.i_clk)
        data = self.dut.o_rx_data
        assert data == byte, f"read data {data}, and send data {byte} don't match"

    async def write_verify(self, byte):
        await self.transmit(byte)
        await self.verify_receive(byte)
        await self.wait_clock()

@cocotb.test()
async def test_uart_receive_with_reset(device):

    dut = TB(device, CLOCK_FREQUENCY, BAUD_RATE)  
    dut.start()
    #await dut.write_verify(0xAA)
    await dut.reset()
    #Wait for a whole transmit cycle after the reset
    for i in range(10):
        await dut.wait_clock()
     
    
    #Transmit a partial signal, reset after a few bits, then transmit a different one
    #Verify that the received is what was trasmitted, ignoring everything before a reset
    #values = [0x00, 0xAA, 0xFF, 0x55]
    #for partial_transmit in values:
    #    for full_transmit in values:
    #        for num_bits_to_send in range(8):
    #            await dut.transmit(partial_transmit, num_bits=num_bits_to_send)
    #            await dut.reset()
    #            await dut.write_verify(full_transmit)
