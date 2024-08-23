import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

from cocotbext.axi import AxiStreamBus, AxiStreamMonitor, AxiStreamSink

from cocotb_bus.bus import Bus
import random

CLOCK_FREQUENCY = 1_000_000#1000000
BAUD_RATE = 115200#_12000

def get_axis_bus(dut, pattern):
    signals = filter(lambda x: x[0] in ["o", "i"], map(str, dir(dut)))
    axis_dict = {}
    for signal in signals:
        if pattern in signal:
            signal_type = signal.split("_")[-1]
            axis_dict[signal_type] = signal

    bus = Bus(dut, "", axis_dict, bus_separator="")
    bus._optional_signals = []
    return bus

def to_hex_str(input):
    return "0x" + "_".join(list(map(lambda x: hex(x)[2:], input)))

class TB():

    def __init__(self, dut, clock_freq, baud_rate):
        self.dut = dut
        self.baud_rate = baud_rate
        self.clock_freq = clock_freq
    
    def start(self):
        clock_period = int(10 ** 12/self.clock_freq) #picos
        print("clock period is {}".format(clock_period))
        clock = Clock(self.dut.i_clk, clock_period, "ps")
        cocotb.start_soon(clock.start())

    def info(self, msg):
        self.dut._log.info(msg)

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
        #self.info(f"Transmitted {byte}")
        await self.wait_clock()
        await self.wait_clock()


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

    random.seed(2343)

    dut = TB(device, CLOCK_FREQUENCY, BAUD_RATE)  
    dut.start()

    bus = get_axis_bus(dut.dut, "m_axis")

    dut.info(bus)
    dut.info(bus._signals)
    dut.info(bus._name)

    def every_other_clock_pause():
        while True:
            yield random.randint(0, 1)

    axis_sink = AxiStreamSink(bus, dut.dut.i_clk, dut.dut.i_rst_n, reset_active_level=False)
    axis_sink.set_pause_generator(every_other_clock_pause())
    #axis_sink.pause = True

    dut.info(axis_sink._pause_cr)

    #await dut.write_verify(0xAA)
    await dut.reset()
    #Wait for a whole transmit cycle after the reset
    for i in range(10):
        await dut.wait_clock()

    num_repeats = 10

    for _ in range(num_repeats):
        num_bytes_to_send = random.randint(0, 16-1)
        send_bytes = [random.randint(0, 256-1) for _ in range(num_bytes_to_send)] 
        
        ba = to_hex_str(send_bytes)
        pkt_len = len(send_bytes)
        dut.info(f"Sending packet {ba} length {pkt_len}")

        await dut.transmit(num_bytes_to_send)
        for i in range(num_bytes_to_send):
            await dut.transmit(send_bytes[i])

        #await axis_sink.wait(timeout=40, timeout_unit="us")
        #TODO have a timeout on the recv so that we don't deadlock,,,, somehow

        data = await axis_sink.recv()
        
        dut.info(f"Got data {to_hex_str(data)}")
        assert to_hex_str(data.tdata) == to_hex_str(send_bytes)    
        
        await dut.wait_clock()
