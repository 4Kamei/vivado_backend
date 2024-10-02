import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import random

from cocotb_util.ether_block_writer import EtherBlockWriter
from cocotb_util.gtx_interface import GtxInterface
from cocotb_util.eth_stream import EthStreamSink

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

    gtx_output_bus = {
        "data": dut.i_data,
        "datavalid": dut.i_data_valid,
        "header": dut.i_header,
        "headervalid": dut.i_header_valid
    }
   
    sink_input_bus = {
            "data" : dut.o_eths_master_data, 
            "keep" : dut.o_eths_master_keep,
            "valid": dut.o_eths_master_valid,
            "abort": dut.o_eths_master_abort,
            "last" : dut.o_eths_master_last
        }

    def random_bit():
        return random.randomint(0, 1)

    block_writer = EtherBlockWriter(random_bit = random_bit)

    gtx_interface = GtxInterface(dut.i_clk, block_writer, gtx_output_bus, output_width = int(dut.DATAPATH_WIDTH))

    stream_sink = EthStreamSink(dut.i_clk, sink_input_bus)

    for _ in range(58):
        await RisingEdge(dut.i_clk)

    for i in range(10, 20):
        d_in = [random.randint(0, 255) for _ in range(i)]        
        block_writer.queue_data(d_in, with_eth_header=True)
        d_out = await stream_sink.recv(timeout=100)
        print(list(map(hex, d_in)))
        print(list(map(hex, d_out)))
        assert d_in == d_out, "Send and received data mismactch"
