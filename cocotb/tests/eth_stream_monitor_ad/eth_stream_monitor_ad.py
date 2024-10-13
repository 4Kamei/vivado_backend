import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer

from cocotbext.axi import AxiStreamSink, AxiStreamSource

from cocotb_util.eth_stream import EthStreamSink, EthStreamSource
from cocotb_util import bus_by_regex
from cocotb_util import WithTimeout

from cocotb_bus.bus import Bus

from axis_debug.axis_debug_device import DebugBusManager

import random

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
async def counts_packets(dut):
    
    tb = TB(dut)
    await tb.reset()

    eth_stream_output = bus_by_regex(dut, "o_eths_master_(.*)")
    eth_stream_input  = bus_by_regex(dut, "i_eths_slave_(.*)")

    axis_dbg_input     = bus_by_regex(dut, "._s_axis_(.*)", as_cocotb_bus=True)
    axis_dbg_output    = bus_by_regex(dut, "._m_axis_(.*)", as_cocotb_bus=True)

    stream_source  = EthStreamSource(dut.i_clk_stream, eth_stream_input)
    stream_sink    = EthStreamSink(dut.i_clk_stream, eth_stream_output) 

    class Test():
        def __init__(self, m):
            self.m = m    
        async def recv(self):
            o = await self.m.recv()
            print(f"RECV CALLED, RETURNED DATA IS {o}")
            return o
    
    axis_dbg_sink   = Test(AxiStreamSink(axis_dbg_output, dut.i_clk_dbg, dut.i_rst_n, reset_active_level=False))
    axis_dbg_source = AxiStreamSource(axis_dbg_input, dut.i_clk_dbg, dut.i_rst_n, reset_active_level=False)
    
    bus_mgr = DebugBusManager(dut.i_clk_dbg, axis_dbg_sink, axis_dbg_source)


    out = await bus_mgr.wait_initialize(timeout=20)
    
    #assert len(out) == 1, f"Expected to find exactly one device, found {len(out)}"
    #debug_device = out[0]


    #from remote_pdb import RemotePdb; rpdb = RemotePdb("127.0.0.1", 4000)
    #rpdb.set_trace()

    await axis_dbg_source.write([0x01, 0x02, 0x04, 0x0, 0x0, 0x01])

    print("RECEIVED DATA", await axis_dbg_sink.recv())
    print("RECEIVED DATA", await axis_dbg_sink.recv())

    counter = await debug_device.read_pkt_counter()
    

    print(counter)
    
    for _ in range(100):
        await RisingEdge(dut.i_clk_dbg)
    

