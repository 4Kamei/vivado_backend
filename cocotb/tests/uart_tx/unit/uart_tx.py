import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

CLOCK_FREQUENCY = 12_000_000
BAUD_RATE = 10000

@cocotb.test()
@cocotb.test()
async def test_uart_internals(dut):
    clock = Clock(dut.i_clk, 10, "ns")
    cocotb.fork(clock.start())
    dut.i_rst_n.value = 0
    await Timer(10, "ns")
    dut.i_rst_n.value = 1
    await Timer(10, "ns")
    dut.i_tx_data.value = 0xF0
    dut.i_tx_en.value = 1
    await Timer(1000, "ns")
    dut.i_tx_en.value = 0
    await Timer(14000, "ns")
    assert False, "not a real test"
    
class TB():

    def __init__(self, dut, clock_freq, baud_rate):
        self.dut = dut
        self.baud_rate = baud_rate
        self.clock_freq = clock_freq
    
    def start(self):

        clock_period = int(0.5 * 10 ** 12/self.clock_freq) #picos
        print("clock period is {}".format(clock_period))
        clock = Clock(self.dut.i_uart_clk, 2*clock_period, "ps")
        cocotb.fork(clock.start())

    async def reset(self):
        self.dut.i_uart_in.value = 1
        await ClockCycles(self.dut.i_uart_clk, 1)
        self.dut.i_reset.value = 1
        await ClockCycles(self.dut.i_uart_clk, 1)
        self.dut.i_reset.value = 0

    async def wait_clock(self):
        await Timer(10 ** 9/self.baud_rate, "ns")

    async def transmit(self, byte):
    
        self.dut.i_uart_in.value = 0

        await self.wait_clock()

        for i in range(8):
            bit = (byte >> i) & 1
            self.dut.i_uart_in.value = bit
            await self.wait_clock()

        self.dut.i_uart_in.value = 1

    async def verify_receive(self, byte):
        await RisingEdge(self.dut.o_data_out_strobe)
        data = self.dut.o_data
        assert data == byte, f"read data {data}, and send data {byte} don't match"

    async def write_verify(self, byte):
        await self.transmit(byte)
        await self.verify_receive(byte)
        await self.wait_clock()

#@cocotb.test()
async def test_uart_receive(device):

    dut = TB(device, CLOCK_FREQUENCY, BAUD_RATE)  
    dut.start()
    await dut.reset()
    for i in range(256):
        await dut.write_verify(i)
