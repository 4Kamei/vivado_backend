import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import random

from cocotbext.axi import AxiStreamSink, AxiStreamSource, AxiStreamFrame

from cocotb_util import bus_by_regex

class CamDut:

    def __init__(self, dut, stream_in, stream_out):
        self.stream_in = stream_in
        self.stream_out = stream_out
        self.log = dut._log

    async def send_update(self, addr, data):
        addr = addr.to_bytes(6, byteorder="little")
        data = data.to_bytes(1, byteorder="little")
        self.log.info(f"DUT: Send update at {addr} {data}")
        await self.stream_out.write(
                AxiStreamFrame(
                    tdata = data + addr, 
                    tuser=[3]
                )
            )

        return await self.handle_response()

    async def send_lookup(self, addr):
        addr = addr.to_bytes(6, byteorder="little")
        self.log.info(f"DUT: Send lookup at {addr}")
        await self.stream_out.write(
                AxiStreamFrame(
                    tdata = bytearray([0]) + addr, 
                    tuser=[0]
                )
            )
        
        return await self.handle_response()
    
    async def handle_response(self):
        resp = await self.stream_in.recv()  
        
    
        self.log.info(f"Got response: {resp}")
        pkt_types = {
                4: "update_succ",
                5: "update_succ_and_evict",
                1: "lookup_succ",
                2: "lookup_fail"
        }

        assert resp.tuser in pkt_types, f"Got unexpected packet type {resp.tuser}, expected one of {list(pkt_types)}"
        
        pkt_type = pkt_types[resp.tuser]

        data = int.from_bytes(resp.tdata[0:1], byteorder="little")
        addr = int.from_bytes(resp.tdata[1:], byteorder="little")

        self.log.info(f"Bytes of response are data: {hex(data)}, addr: {hex(addr)}")

        return pkt_type, addr, data

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

class CamMemoryItem:

    def __init__(self, items_in_bucket):
        self.items_in_bucket = items_in_bucket;
        self.items = [None for _ in range(items_in_bucket)]
        self.timestamp = 0
    

    #Returns, in order of priority: Slot that has addr 'addr', empty slot, oldest element in the bucket
    def find_slot(self, new_addr):
        #First, see if we have ADDR in items. 
        for i, item in enumerate(self.items):
            if item == None:
                continue
            timestamp, addr, data = item
            if addr == new_addr:
                return i
        #if new_addr is not in items, then we need to insert, rather than update. Check if we find any empty 'none' slots
        for i, item in enumerate(self.items):
            if item == None:
                return i

        #We are inserting, AND we don't have any empty slots. We need to evict the oldest item
        oldest_timestamp = None
        oldest_index = None
        for i, item in enumerate(self.items):
            timestamp, addr, data = item
            if oldest_timestamp == None or timestamp < oldest_timestamp:
                oldest_timestamp = timestamp
                oldest_index = i
        return oldest_index

    def update(self, addr, data):
        from math import ceil, log2
        slot = self.find_slot(addr)
        occupied = self.items[slot]
        print("Occupied while update?", occupied, slot, self.items[slot])
        self.items[slot] = (self.timestamp, addr, data)
        self.timestamp += 1
        timestamps = set()
    
        print("Occupied while update? Returning: ", occupied, slot, self.items[slot])
        return occupied

    def get(self, addr):
        slot_index = self.find_slot(addr)
        if self.items[slot_index] == None:
            return None

        ts, item_addr, item_data = self.items[slot_index]
        if item_addr != addr:
            return None

        return item_data

    def __map_item(self, item):
        if item == None:
            return f"[                   ]"
        ts = hex(2 ** 8 + item[0])[3:]
        addr = hex(2 ** 48 + item[1])[3:]
        data = hex(2 ** 8 + item[2])[3:]
        return f"[{ts}: {addr} {data}]"

    def __str__(self):
        items = " ".join(map(self.__map_item, self.items))
        header = hex(self.timestamp)
        return f"{header} : {items}"

class AxisCamModel:

    def __init__(self, num_buckets, items_in_bucket):
        self.num_buckets = num_buckets
        self.items_in_bucket = items_in_bucket
        self.memory = [CamMemoryItem(items_in_bucket) for _ in range(num_buckets)]
        from math import log2
        num_buckets_log2 = log2(num_buckets)
        assert int(num_buckets_log2) == num_buckets_log2, f"Num buckets must be a power of two {num_buckets}"

    def hash(self, number):
        if isinstance(number, list):
            number = int.from_bytes(number, byteorder="little")
        return (number & 0xffff) 
    
    def index_of(self, addr):
        return hash(addr) % self.num_buckets
    
    def update(self, addr, data):
        index = self.index_of(addr)
        item = self.memory[index]
        out = item.update(addr, data)
        print("Got item out = ", out)
        if out != None:
            return "update_succ_and_evict", out[1], out[2]
        else:
            return "update_succ", addr, data
    
    def get(self, addr):
        index = self.index_of(addr)
        item = self.memory[index]
        out = item.get(addr)
        if out == None:
            return "lookup_fail", addr, 0
        else:
            return "lookup_succ", addr, out

    def __str__(self):
        return "\n".join(map(str, self.memory))

@cocotb.test()
async def can_receive_blocks_rand(dut):
    
    print(dir(dut))

    sink_bus =   bus_by_regex(dut, "._m_(.*)", as_cocotb_bus=True)
    source_bus = bus_by_regex(dut, "._s_(.*)", as_cocotb_bus=True)

    tb = TB(dut)
    await tb.reset()

    stream_sink     = AxiStreamSink(sink_bus, dut.i_clk, dut.i_rst_n, reset_active_level=False)
    stream_source   = AxiStreamSource(source_bus, dut.i_clk, dut.i_rst_n, reset_active_level=False)
   
    model = AxisCamModel(int(dut.NUM_BUCKETS), int(dut.NUM_ITEMS_IN_BUCKET))
   
    cam_dut = CamDut(dut, stream_sink, stream_source)

    used_addrs = set()

    stats = {
            "lookup_succ" : 0,
            "lookup_fail" : 0,
            "update_succ" : 0,
            "update_succ_and_evict": 0
    }
    
    command_queue = []

    for _ in range(10000):
        if random.randint(0, 10) == 0 and len(used_addrs) > 0:
            addr = random.choice(list(used_addrs))
        else:
            addr = random.randint(0, 256 * 256 - 1)
            used_addrs.add(addr)
            
        command = [
                "update",
                "get"
        ][random.randint(0, 1)]
        
        if command == "update":
            data = random.randint(0, 255)
            command_queue.append(("update", addr, data))
            command_queue.append(("get", addr, None))
        
        if command == "get":
            command_queue.append(("get", addr, None))

    for command, addr, data in command_queue:
                

        if command == "update":
            dut._log.info(f"update : {addr} {data}")
            dut_out = await cam_dut.send_update(addr, data)
            model_out = model.update(addr, data)
        if command == "get":
            dut._log.info(f"get    : {addr}")
            dut_out = await cam_dut.send_lookup(addr)
            model_out = model.get(addr)
            
        dut._log.info(f"Index of item in memory is {model.index_of(addr)}")
        dut._log.info(f"Model memory contents are \n{str(model)}")
        if dut_out != model_out:
            assert False, f"DUT and Model output didn't match.\nDUT_OUT   = {dut_out[0]}, {hex(dut_out[1])}, {hex(dut_out[2])}\nMODEL_OUT = {model_out[0]}, {hex(model_out[1])}, {hex(model_out[2])}"
        stats[model_out[0]] += 1

    print(stats)
