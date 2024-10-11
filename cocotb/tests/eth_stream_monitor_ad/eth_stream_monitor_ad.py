import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import random

from cocotbext.axi import AxiStreamSink, AxiStreamSource

from cocotb_util.eth_stream import EthStreamSink, EthStreamSource

from cocotb_util import bus_by_regex

from cocotb_bus.bus import Bus

class TB:

    def __init__(self, dut):
        clock_dbg = Clock(dut.i_clk_dbg, 322, "ps")
        cocotb.start_soon(clock_dbg.start())
        clock_stream = Clock(dut.i_clk_stream, 1000, "ps")
        cocotb.start_soon(clock_stream.start())
        self.dut = dut
        
    async def reset(self):
        await RisingEdge(self.dut.i_clk_dbg)
        self.dut.i_rst_n.value = 1
        await RisingEdge(self.dut.i_clk_dbg)
        self.dut.i_rst_n.value = 0
        await RisingEdge(self.dut.i_clk_dbg)
        self.dut.i_rst_n.value = 1

@cocotb.test()
async def test_finds_block_lock(dut):
    
    tb = TB(dut)
    await tb.reset()

    eth_stream_output = bus_by_regex(dut, "o_eths_master_(.*)")
    eth_stream_input  = bus_by_regex(dut, "i_eths_slave_(.*)")

    axis_dbg_input     = bus_by_regex(dut, "._s_axis_(.*)", as_cocotb_bus=True)
    axis_dbg_output    = bus_by_regex(dut, "._m_axis_(.*)", as_cocotb_bus=True)

    stream_source  = EthStreamSource(dut.i_clk_stream, eth_stream_input)
    stream_sink    = EthStreamSink(dut.i_clk_stream, eth_stream_output) 

    axis_dbg_sink   = AxiStreamSink(axis_dbg_input, dut.i_clk_dbg, dut.i_rst_n, reset_active_level=False)
    axis_dbg_source = AxiStreamSource(axis_dbg_output, dut.i_clk_dbg, dut.i_rst_n, reset_active_level=False)
    
    stream_source.send_nowait([0x12])

    await stream_sink.recv()

