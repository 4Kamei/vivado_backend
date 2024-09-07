import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from queue import Queue

from cocotbext.axi import AxiStreamBus, AxiStreamMonitor, AxiStreamSource, AxiStreamSink

from cocotb_bus.bus import Bus
import random

def get_axis_bus(dut, pattern):
    signals = filter(lambda x: x[0] in ["o", "i"], map(str, dir(dut)))
    axis_dict = {}
    for signal in signals:
        if pattern in signal:
            signal_type = signal.split("_")[-1]
            axis_dict[signal_type] = signal

    bus = Bus(dut, "", axis_dict, bus_separator="")
    bus._optional_signals = []
    return bus

def to_hex_str(input):
    return "0x" + "_".join(list(map(lambda x: hex(x + 256)[3:], input)))


#TODO read 1 byte + write 1 byte, but with tvalid THEN tready
#TODO Force reads with spurious writes

@cocotb.test()
async def master_throttled_random(dut):
    cocotb.start_soon(Clock(dut.i_clk, 10, "ps").start())
    
    #Assert reset to setup the TB
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 0
    await RisingEdge(dut.i_clk)   
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)   

    output_bus = get_axis_bus(dut, "m_axis")
    input_bus = get_axis_bus(dut, "s_axis")

    axis_source = AxiStreamSource(input_bus, dut.i_clk) 
    axis_sink = AxiStreamSink(output_bus, dut.i_clk)
          
    write_data = Queue()
    
    #Passes through unknown packets
    await axis_source.send([0x02, 0x00, 0xaa, 0xbb, 0xcc])
    await axis_sink.recv()
    
    #Passes through unknown packets
    await axis_source.send([0x01, 0x00, 0xaa, 0xbb, 0xcc])
    await axis_sink.recv()
        
