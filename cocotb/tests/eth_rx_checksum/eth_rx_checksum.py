import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import random

from cocotb_util.ether_block_writer import EtherBlockWriter
from cocotb_util.gtx_interface import GtxInterface
from cocotb_util.eth_stream import EthStreamSink, EthStreamSource

from ether_util import l2_checksum

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

def get_random_packet(length):
    pkt = bytearray([i for i in range(length)])
    checksum = l2_checksum(pkt)
    return pkt, bytearray(checksum)

@cocotb.test()
async def test_finds_block_lock(dut):
    
    tb = TB(dut)
    await tb.reset()
    
    sink_input_bus = {
            "data" : dut.o_eths_master_data, 
            "keep" : dut.o_eths_master_keep,
            "valid": dut.o_eths_master_valid,
            "abort": dut.o_eths_master_abort,
            "last" : dut.o_eths_master_last
        }
    
    source_output_bus = {
            "data" : dut.i_eths_slave_data, 
            "keep" : dut.i_eths_slave_keep,
            "valid": dut.i_eths_slave_valid,
            "abort": dut.i_eths_slave_abort,
            "last" : dut.i_eths_slave_last
        }


    stream_sink   = EthStreamSink(dut.i_clk, sink_input_bus)
    stream_source = EthStreamSource(dut.i_clk, source_output_bus)

    for _ in range(3):
        await RisingEdge(dut.i_clk)
    
    for i in range(100):
        for corrupt in [True, False]:
            packet_data, checksum = get_random_packet(64 + i)
            if corrupt:
                checksum[0] = ~checksum[0] & 255
            
            data_out = packet_data + checksum
            stream_source.send_nowait(data_out)
                
            #Have a bit of a delay, so that the packet makes it's way through the logic
            for _ in range(5):
                await RisingEdge(dut.i_clk)

            if corrupt:
                await stream_sink.wait_idle()
                assert stream_sink.empty() == True, "Expected packet with corrupted checksum to be aborted"
            else:
                data_in = bytearray(await stream_sink.recv())
                #assert data_in == data_out, f"Sent data:\n{data_in}\n does not match received data:\n{data_out}\n"
            
            for _ in range(5):
                await RisingEdge(dut.i_clk)
