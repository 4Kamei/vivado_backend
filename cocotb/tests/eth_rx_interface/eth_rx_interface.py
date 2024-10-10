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
    
    pause_at = [i for i in range(66) if i % 3 == 0]

    gtx_interface = GtxInterface(dut.i_clk, 
                                 block_writer, 
                                 gtx_output_bus, 
                                 output_width = int(dut.DATAPATH_WIDTH),
                                 pause_at = pause_at)

    stream_sink = EthStreamSink(dut.i_clk, sink_input_bus)

    for _ in range(3):
        await RisingEdge(dut.i_clk)
    
    pkt_lens = []

    for i in range(8, 16):
        for j in range(8, 16):
            for i_ctrl in [True, False]:
                for j_ctrl in [True, False]:
                    pkt_lens.append((i, i_ctrl))
                    pkt_lens.append((j, j_ctrl))

    for (pkt_len, ctrl) in pkt_lens:
            #TODO add errors into the stream and see if 'abort' is triggered'
            #Errors that can be detected:
            #   Error characters
            #   Incorrect header -> 00/11
            #   Incorrect block header/Unexpected block headers
            d_in = [p for p in range(i)]        
            if ctrl:
                block_writer.queue_control(0x00)
            block_writer.queue_data(d_in, with_eth_header=True)
            d_out = await stream_sink.recv(timeout=100)
            print(list(map(hex, d_in)))
            print(list(map(hex, d_out)))
            assert d_in == d_out, "Send and received data mismactch"
