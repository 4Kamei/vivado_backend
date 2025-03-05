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


def get_signal_map(pattern_file, start_time, end_time):
        header_map = {
            "Sample in Window":"time",
            "gtx_sfp1_rx_data[31:0]":"data",
            "gtx_sfp1_rx_datavalid":"data_valid",
            "gtx_sfp1_rx_header[1:0]":"header",
            "gtx_sfp1_rx_headervalid":"header_valid",
        }

        header_indices = {
            "data":None,
            "data_valid": None,
            "header": None,
            "header_valid": None,
            "time": None,
        }

        had_header = False
        had_next_line = False

        pattern_out = []

        with open(f"test_specific_patterns/{pattern_file}", "r") as f:
            for line in f:
                line = line.replace("\n", "")
                if not had_header:
                    for i, p in enumerate(line.split(",")):
                        if p in header_map:
                            header_indices[header_map[p]] = i
                    had_header = True
                    continue
                if not had_next_line:
                    had_next_line = True
                    continue
               
                line_s = line.split(",")
                time = int(line_s[header_indices["time"]])
                if time >= start_time and time < end_time:
                    pattern_out.append({
                        "data":         int(line_s[header_indices["data"]], 16),    
                        "data_valid":   int(line_s[header_indices["data_valid"]], 16),    
                        "header":       int(line_s[header_indices["header"]], 16),    
                        "header_valid": int(line_s[header_indices["header_valid"]], 16),    
                    })

        return pattern_out


@cocotb.test()
async def can_receive_blocks_specific(dut):
    
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

    
    patterns = [
        ("ping_0.csv", 1000, 1058)    
    ]
 
    stream_sink = EthStreamSink(dut.i_clk, sink_input_bus)

    signals = {
        "data": dut.i_data,
        "data_valid": dut.i_data_valid,
        "header": dut.i_header,
        "header_valid": dut.i_header_valid,
    }

    for pattern_file, start_cycle, end_cycle in patterns:
        await tb.reset()

        signal_map = get_signal_map(pattern_file, start_cycle, end_cycle)
    
        for signal_row in signal_map:
            await RisingEdge(dut.i_clk)
            print(f"Setting {hex(signal_row['data'])} with {signal_row['header']} - {signal_row['data_valid']}, {signal_row['header_valid']}")
            for signal in signal_row:
                signals[signal].value = signal_row[signal]
            
        print(await stream_sink.recv())

@cocotb.test()
async def can_receive_blocks_rand(dut):
    
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
            d_in = [random.randint(0, 255) for _ in range(pkt_len)]        
            if ctrl:
                block_writer.queue_control(0x00)
            block_writer.queue_data(d_in, with_eth_header=True)
            d_out = await stream_sink.recv(timeout=100)
            print(list(map(hex, d_in)))
            print(list(map(hex, d_out)))
            assert d_in == d_out, "Send and received data mismactch"
