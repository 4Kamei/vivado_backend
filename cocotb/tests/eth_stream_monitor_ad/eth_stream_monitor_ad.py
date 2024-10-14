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
async def saves_packets_with_trigger(dut):
    
    tb = TB(dut)
    await tb.reset()

    eth_stream_output = bus_by_regex(dut, "o_eths_master_(.*)")
    eth_stream_input  = bus_by_regex(dut, "i_eths_slave_(.*)")

    axis_dbg_input     = bus_by_regex(dut, "._s_axis_(.*)", as_cocotb_bus=True)
    axis_dbg_output    = bus_by_regex(dut, "._m_axis_(.*)", as_cocotb_bus=True)

    stream_source  = EthStreamSource(dut.i_clk_stream, eth_stream_input)
    stream_sink    = EthStreamSink(dut.i_clk_stream, eth_stream_output) 
    
    axis_dbg_sink   = AxiStreamSink(axis_dbg_output, dut.i_clk_dbg, dut.i_rst_n, reset_active_level=False)
    axis_dbg_source = AxiStreamSource(axis_dbg_input, dut.i_clk_dbg, dut.i_rst_n, reset_active_level=False)
    
    bus_mgr = DebugBusManager(dut.i_clk_dbg, axis_dbg_sink, axis_dbg_source)

    out = await bus_mgr.wait_initialize(timeout=20)
    
    assert len(out) == 1, f"Expected to find exactly one device, found {len(out)}"
    debug_device = out[0]
    
    for _ in range(10):
        await debug_device.activate_trigger()

        in_data = [random.randint(0, 255) for _ in range(random.randint(1, 100))]

        #TODO for the real testbench, play with this value
        #This is hard, as we may miss the packet. Completely expected behaviour IRL, 
        #but painful to deal with in sim
        for _ in range(15):
            await RisingEdge(dut.i_clk_dbg)

        stream_source.send_nowait(in_data)  
        stream_source.send_nowait([random.randint(0, 255) for _ in range(random.randint(10, 30))])

        while not await debug_device.is_triggered():
            await RisingEdge(dut.i_clk_dbg)
        
        await stream_sink.recv()
        await stream_sink.recv()

        out_data = await debug_device.readout_packet(trim_invalid=True)
        
        
        assert in_data == out_data, f"Sent data:\n{in_data}\n does not match Received data:\n{out_data}\n"

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
    
    axis_dbg_sink   = AxiStreamSink(axis_dbg_output, dut.i_clk_dbg, dut.i_rst_n, reset_active_level=False)
    axis_dbg_source = AxiStreamSource(axis_dbg_input, dut.i_clk_dbg, dut.i_rst_n, reset_active_level=False)
    
    bus_mgr = DebugBusManager(dut.i_clk_dbg, axis_dbg_sink, axis_dbg_source)


    out = await bus_mgr.wait_initialize(timeout=20)
    
    assert len(out) == 1, f"Expected to find exactly one device, found {len(out)}"
    debug_device = out[0]


    #from remote_pdb import RemotePdb; rpdb = RemotePdb("127.0.0.1", 4000)
    #rpdb.set_trace()

    sent_packets = 0
    for _ in range(10):
        stream_source.send_nowait([random.randint(0, 255) for _ in range(random.randint(0, 100))])
        await stream_sink.recv()
        sent_packets += 1
        counter = await debug_device.read_pkt_counter()
        assert counter == sent_packets, "Number of packets sent and number counted don't match"
