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

#TODO read 1 byte + transmit 1 byte, but with tvalid THEN tready
#TODO Force reads with spurious transmits

#Functionality to verify
#k   Ignores packets that aren't meant for you
#   Correctly identifies
#   Correctly reads from addresses  
#   Correctly transmits to address
#   When writing and transmit doesn't ack, ignores any incoming packets
#   Whev reading and read  doesn't ack, ignores any incoming packets


@cocotb.test()
async def test_all_types_unthrottled(dut):
    await test_all_types(dut)

@cocotb.test()
async def test_all_types_throttled_onoff_slave(dut):
    def source_pause_gen():
        k = 0
        while True:
            k = 1 - k
            yield k

    await test_all_types(dut, source_pause_gen=source_pause_gen)

@cocotb.test()
async def test_all_types_throttled_slave(dut):
    def source_pause_gen():
        while True:
            yield random.randint(0, 1)

    await test_all_types(dut, source_pause_gen=source_pause_gen)

@cocotb.test()
async def test_all_types_throttled_onoff_master(dut):
    def sink_pause_gen():
        k = 0
        while True:
            k = 1 - k
            yield k
        
    await test_all_types(dut, sink_pause_gen=sink_pause_gen)

@cocotb.test()
async def test_all_types_throttled_master(dut):
    def sink_pause_gen():
        while True:
            yield random.randint(0, 1)
    
    await test_all_types(dut, sink_pause_gen=sink_pause_gen)

@cocotb.test()
async def test_all_types_throttled_both(dut):
    def source_pause_gen():
        while True:
            yield random.randint(0, 1)

    def sink_pause_gen():
        while True:
            yield random.randint(0, 1)
    
    await test_all_types(dut, source_pause_gen=source_pause_gen, sink_pause_gen=sink_pause_gen)


class TB():

    def __init__(self, dut, axis_source, axis_sink):
        self.dut = dut
        cocotb.start_soon(Clock(dut.i_clk, 10, "ps").start())
        cocotb.start_soon(Clock(dut.i_clk_extern, 12, "ps").start())
        self.axis_source = axis_source
        self.axis_sink = axis_sink
        self.log = dut._log

    async def reset(self):
        #Assert reset to setup the TB
        await RisingEdge(self.dut.i_clk)
        self.dut.i_rst_n.value = 0
        await RisingEdge(self.dut.i_clk)   
        self.dut.i_rst_n.value = 1
        await RisingEdge(self.dut.i_clk)   
    
    async def transmit(self, data, expect_response=None):
        #Identify Packet
        await self.axis_source.send(data)
        in_data = await self.axis_sink.recv()
        assert in_data.tdata == bytearray(data), "Received different packet than what was written"
        if expect_response:
            output_packet = await self.axis_sink.recv()
            assert output_packet.tdata == bytearray(expect_response), "Packet response differed from expected"
        
        assert self.axis_sink.count() == 0, "Produced more packets than expected"
    
    async def transmit_identify(self):
        self.log.info("Sending IDENTIFY")
        expect_response = [
                0x01, 
                0x01, 
                int(self.dut.AXIS_DEVICE_TYPE.value), 
                int(self.dut.AXIS_DEVICE_ID.value), 
                int(1),
                int(8)
        ]
        await self.transmit([0x01, 0x00], expect_response=expect_response) 
        
        assert self.axis_sink.count() == 0, "Produced more packets than expected"
        self.log.info("Parsed IDENTIFY")
    
    async def transmit_read(self, addr=None, wrong_id=False, wrong_type=False, wrong_version=False):
        self.log.info("Sending READ")
        if addr == None:
            addr = random.randint(0, 2 ** (8 * int(1)) - 1)

        addr_bytes = addr.to_bytes(int(1), byteorder="big")
        addr_bytes = list(map(lambda x: int(x), addr_bytes))

        device_type = int(self.dut.AXIS_DEVICE_TYPE)
        device_id   = int(self.dut.AXIS_DEVICE_ID)
        version     = 0x01
        
        await self.transmit(
                [version, 0x02, device_type, device_id] 
              + addr_bytes)
        
        self.log.info("Transmitted and received reply")

        assert self.axis_sink.count() == 0, "Produced more packets than expected"
        self.log.info("Parsed READ")
        return await self.axis_sink.recv()
        #TODO assert input packet data is the transmitted data
        
    async def transmit_write(self, addr=None, data=None, wrong_id=False, wrong_type=False, wrong_version=False):
        if addr == None:
            addr = random.randint(0, 2 ** (8 * int(1)) - 1)
        if data == None:
            data = random.randint(0, 2 ** (8 * int(8)) - 1)

        self.log.info(f"Sending WRITE to {addr}")
        
        addr_bytes = addr.to_bytes(int(1), byteorder="big")
        addr_bytes = list(map(lambda x: int(x), addr_bytes))

        data_bytes = data.to_bytes(int(8), byteorder="big")
        data_bytes = list(map(lambda x: int(x), data_bytes))
    
        device_type = int(self.dut.AXIS_DEVICE_TYPE)
        device_id   = int(self.dut.AXIS_DEVICE_ID)
        version     = 0x01

        await self.transmit(
                [version, 0x04, device_type, device_id] 
              + addr_bytes + data_bytes)
        
        assert self.axis_sink.count() == 0, "Produced more packets than expected"
        self.log.info("Parsed WRITE")

async def test_all_types(dut, source_pause_gen=None, sink_pause_gen=None):


    output_bus = get_axis_bus(dut, "m_axis")
    input_bus = get_axis_bus(dut, "s_axis")

    axis_source = AxiStreamSource(input_bus, dut.i_clk, dut.i_rst_n, reset_active_level=False) 
    axis_sink = AxiStreamSink(output_bus, dut.i_clk, dut.i_rst_n, reset_active_level=False)
    if source_pause_gen != None:
        axis_source.set_pause_generator(source_pause_gen())
    if sink_pause_gen != None:
        axis_sink.set_pause_generator(sink_pause_gen())

    tb = TB(dut, axis_source, axis_sink)
    await tb.reset()
    
    packet_types = ["identify", "read", "write", "nop"]
    
    await tb.transmit_identify()

    for _ in range(3000):
        await RisingEdge(dut.i_clk)

    await tb.transmit_write(addr=0, data=1)
    
    reg_data = 0
    while reg_data == 0:
        tb.log.info("Checking if we're ready to read the counters")
        reply = await tb.transmit_read(addr=0)
        reg_data = int.from_bytes(reply.tdata[-8:], byteorder="big")
    
    local_counter  = int.from_bytes((await tb.transmit_read(addr=1)).tdata[-8:], byteorder="big")
    extern_counter = int.from_bytes((await tb.transmit_read(addr=2)).tdata[-8:], byteorder="big")

    tb.log.info(f"local={local_counter}, extern={extern_counter}")

    #write 1 to 0
    #read  0 until we get '1' back


