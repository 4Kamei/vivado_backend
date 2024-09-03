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
    

    output_bus = get_axis_bus(dut, "m_axis")
    input_bus = get_axis_bus(dut, "s_axis")


    axis_source = AxiStreamSource(input_bus, dut.i_clk) 
    axis_sink = AxiStreamSink(output_bus, dut.i_clk)
          
    write_data = Queue()

    async def sender():
        for k in range(1000):
            rand_len = random.randint(1, 10)
            s = bytearray([random.randint(0, 255) for _ in range(rand_len)])
            #TODO finish the fifo + write a uart TX + do a loopback test
            await axis_source.send(s)
            #await axis_source.wait()    
            write_data.put(s)
            for i in range(random.randint(0, 20)):
                await RisingEdge(dut.i_clk)

    
    #Deassert reset to start the TB
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)
   
    jh = cocotb.start_soon(sender())

    while True:
        received = await axis_sink.recv()
        k = write_data.get()
        if write_data.empty():
            break
        assert to_hex_str(k) == to_hex_str(received.tdata), "Send and received data mismatch"
        dut._log.info(f"Send and Received {to_hex_str(k)}")

    await jh

@cocotb.test()
async def slave_throttled_random(dut):


    cocotb.start_soon(Clock(dut.i_clk, 10, "ps").start())
    
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 0
    await RisingEdge(dut.i_clk)
    
    output_bus = get_axis_bus(dut, "m_axis")
    input_bus = get_axis_bus(dut, "s_axis")


    def every_other_clock_pause():
        p = 1
        while True:
            sequence_len = random.randint(1, 32)
            sequence = [p] * sequence_len
            p = 1 - p
            for k in sequence:
                yield k 

    axis_source = AxiStreamSource(input_bus, dut.i_clk) 
    axis_sink = AxiStreamSink(output_bus, dut.i_clk)
    axis_sink.set_pause_generator(every_other_clock_pause())

    
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)
    
    write_data = []

    for k in range(1000):
        rand_len = random.randint(1, 3)
        s = bytearray([random.randint(0, 255) for _ in range(rand_len)])
        #TODO finish the fifo + write a uart TX + do a loopback test
        await axis_source.send(s)
        dut._log.info(f"Sent {k}")
        # wait for operation to complete (optional)
        #await axis_source.wait()    
        #await axis_sink.recv()
        write_data.append(s)

    for k in write_data:
        received = await axis_sink.recv()
        assert to_hex_str(k) == to_hex_str(received.tdata), "Send and received data mismatch"
        dut._log.info(f"Send and Received {to_hex_str(k)}")

    #for i in range(10):
    #    await RisingEdge(dut.i_clk)
