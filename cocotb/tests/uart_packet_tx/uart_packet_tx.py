import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer


from cocotbext.axi import AxiStreamBus, AxiStreamMonitor, AxiStreamSource
from cocotbext.uart import UartSource, UartSink

from cocotb_bus.bus import Bus
import random

CLOCK_FREQUENCY = 20_000_000
BAUD_RATE = 1_000_000

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

@cocotb.test()
async def test_uart_internals(dut):
    clock = Clock(dut.i_clk, int(1000_000 * 1_000_000 / CLOCK_FREQUENCY), "ps")
    cocotb.fork(clock.start())
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)
    
    random.seed(2343)

    def pause_gen():
        while True:
            yield random.randint(0, 1)

    bus = get_axis_bus(dut, "s_axis")
    axis_source = AxiStreamSource(bus, dut.i_clk)
    axis_source.set_pause_generator(pause_gen())
    uart_sink = UartSink(dut.o_uart_tx, baud=BAUD_RATE, bits=8)

    dut.i_rst_n.value = 0
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)
    
    for _ in range(1000):
        data_len = random.randint(1, 10)
        data = [random.randint(0, 255) for _ in range(data_len)]
        ba = bytearray(data)
        await axis_source.write(ba)

        pkt_len = await uart_sink.read(1)
        pkt_len = int.from_bytes(pkt_len, byteorder='big', signed=False)
        out_data = []   
        for _ in range(pkt_len):
            out_data.append(int.from_bytes(await uart_sink.read(), byteorder='big', signed=False))
        

        assert ba == bytearray(out_data), "Send and Received data mismatch" 
    
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

