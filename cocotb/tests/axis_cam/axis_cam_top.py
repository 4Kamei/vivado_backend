import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import random

from cocotbext.axi import AxiStreamSink, AxiStreamSource, AxiStreamFrame

from cocotb_util import bus_by_regex


async def send_update(stream, addr, data):
    return await stream.write(
            AxiStreamFrame(
                tdata = data + addr, 
                tuser=[1]
            )
        )

async def send_lookup(stream, addr):
    return await stream.write(
            AxiStreamFrame(
                tdata = [0] + addr, 
                tuser=[0]
            )
        )

class TB:

    def __init__(self, dut):
        clock = Clock(dut.i_clk, 1000, "ps")
        cocotb.start_soon(clock.start())
        self.dut = dut
        
    async def reset(self):
        await RisingEdge(self.dut.i_clk)
        self.dut.i_rst_n.value = 1
        await RisingEdge(self.dut.i_clk)
        self.dut.i_rst_n.value = 0
        await RisingEdge(self.dut.i_clk)
        self.dut.i_rst_n.value = 1



@cocotb.test()
async def can_receive_blocks_rand(dut):
    
    print(dir(dut))

    sink_bus =   bus_by_regex(dut, "._m_(.*)", as_cocotb_bus=True)
    source_bus = bus_by_regex(dut, "._s_(.*)", as_cocotb_bus=True)

    tb = TB(dut)
    await tb.reset()

    stream_sink     = AxiStreamSink(sink_bus, dut.i_clk, dut.i_rst_n, reset_active_level=False)
    stream_source   = AxiStreamSource(source_bus, dut.i_clk, dut.i_rst_n, reset_active_level=False)
    
    for _ in range(3):
        await RisingEdge(dut.i_clk)
    
    await send_update(stream_source, [1, 2, 3, 4, 5, 6], [0x43])
    await send_update(stream_source, [1, 2, 3, 4, 5, 6], [0x23])

    for _ in range(30):
        await RisingEdge(dut.i_clk)
    
    await send_lookup(stream_source, [1, 2, 3, 4, 5, 6])
    
    for _ in range(30):
        await RisingEdge(dut.i_clk)

 
