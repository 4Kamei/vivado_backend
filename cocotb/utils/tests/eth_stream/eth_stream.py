import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import random

from cocotb_util.eth_stream import EthStreamSink, EthStreamSource

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
        await RisingEdge(self.dut.i_clk)

@cocotb.test()
async def test_finds_block_lock(dut):
    
    tb = TB(dut)
    await tb.reset()
  
    sink_input_bus = {
            "data" : dut.o_eth_master_data, 
            "keep" : dut.o_eth_master_keep,
            "valid": dut.o_eth_master_valid,
            "abort": dut.o_eth_master_abort,
            "last" : dut.o_eth_master_last
    }
    
    source_output_bus = {
            "data" : dut.i_eth_slave_data, 
            "keep" : dut.i_eth_slave_keep,
            "valid": dut.i_eth_slave_valid,
            "abort": dut.i_eth_slave_abort,
            "last" : dut.i_eth_slave_last
    }

    stream_sink   =   EthStreamSink(dut.i_clk, sink_input_bus)
    stream_source = EthStreamSource(dut.i_clk, source_output_bus)

    stream_source.send_nowait([0x01])
    stream_source.send_nowait([0x01, 0x02, 0x03, 0x04])
    #stream_source.send_nowait([0x01, 0x02])

    for _ in range(3):
        await RisingEdge(dut.i_clk)
    
    stream_source.send_nowait([i for i in range(23)])
    #stream_source.send_nowait([0x01, 0x02, 0x03, 0x04])
         
    for _ in range(50):
        await RisingEdge(dut.i_clk)
   
    dut._log.info(await stream_sink.recv())
    dut._log.info(await stream_sink.recv())
    dut._log.info(await stream_sink.recv())

