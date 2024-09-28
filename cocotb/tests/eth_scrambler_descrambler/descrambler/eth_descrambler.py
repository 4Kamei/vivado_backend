import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, FallingEdge, Timer
import random
from queue import Queue
from cocotbext.axi import AxiStreamSource, AxiStreamSink
from cocotb_bus.bus import Bus

class Descrambler:
    def __init__(self, initial_state):
        self.reg = initial_state

    def compute(self, input_data):
        output_data = []
        for bit in input_data:
            output_data.append(self.input(bit))
        return int("".join(map(str, output_data)), 2)

    def input(self, bit):
        out = bit ^ self.reg[38] ^ self.reg[57]
        self.reg = [bit] + self.reg[0:57]
        pre_len = len(self.reg)
        assert pre_len == len(self.reg)
        return out

class Sender:

    def __init__(self, dut, axis_source, data):
        self.axis_source = axis_source
        self.queue = Queue()
        self.dut = dut
        self.data = data

    async def run(self):
        for data_row in self.data:
            await self.axis_source.send(data_row[::-1]) 
            
@cocotb.test()
async def scrambler(dut):
    
    clock = Clock(dut.i_clk, 1000, "ps")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 0
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)

    def random_pause_generator():
        while True:
            yield random.randint(0, 1)

    descrambler = Descrambler([1] * 58)    

    dut.i_descrambler_bypass.value = 0

    input_bus = {
        "tready": "o_ready",
        "tvalid": "i_valid",
        "tdata": "i_data"
    }
    input_bus = Bus(dut, "", input_bus, bus_separator="")
    input_bus._optional_signals = []
 
    output_bus = {
        "tready": "i_ready",
        "tvalid": "o_valid",
        "tdata": "o_data"
    }
    output_bus = Bus(dut, "", output_bus, bus_separator="")
    output_bus._optional_signals = []

    axis_source = AxiStreamSource(input_bus, dut.i_clk)
    axis_sink = AxiStreamSink(output_bus, dut.i_clk)
    axis_source.set_pause_generator(random_pause_generator())
    axis_sink.set_pause_generator(random_pause_generator())
   
    had_valid = False
    max_until_valid = 4

    num_data = 2000
    data = [[random.randint(0, 255) for _ in range(4)] for _ in range(num_data)]

    sender = Sender(dut, axis_source, data)
    cocotb.start_soon(sender.run())
    
    def byte_to_bits(in_byte):
        return list(map(int, bin(in_byte+ 256)[3:]))
    
    for i, data_in in enumerate(data):
        data_out_descrambled = await axis_sink.recv()
    
        data_in_bytes = [p for k in map(byte_to_bits, data_in) for p in k]
        data_in_bytes_int = int("".join(map(str, data_in_bytes)), 2)
        data_in_bytes_descrambled = descrambler.compute(data_in_bytes)
        data_out_descrambled = int.from_bytes(data_out_descrambled.tdata, byteorder="little")
        
        dut._log.info(f"{hex(data_out_descrambled)} <-> {hex(data_in_bytes_int)}")
        
        if data_out_descrambled == data_in_bytes_descrambled:
            if not had_valid:
                dut._log.info(f"Synchronised in {i} cycles")
            had_valid = True
        else:
            max_until_valid -= 1
            if max_until_valid == 0:
                assert False, "Could not synchronise in max_until_valid cycles"

        if had_valid:
            assert data_out_descrambled == data_in_bytes_descrambled, "descrambler output doesn't match model"
