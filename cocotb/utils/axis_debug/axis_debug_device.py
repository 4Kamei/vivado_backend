from asyncio import Queue as AsyncQueue

#Some other class does the bus initialization, + finds all the devices
#Then returns subclasses of this, tailored to each specific device type

class PacketParserV1:

    Identify=0x00
    IdentifyResponse = 0x01
    ReadRequest = 0x02
    ReadResponse = 0x03
    WriteRequest = 0x04

    AllPacketTypes = [
        Identify,
        IdentifyResponse,
        ReadRequest,
        ReadResponse,
        WriteRequest,
    ]
    
    def parse(packet, data_width: int | None = None, addr_width: int | None = None):
        version = packet[0]
        if version != 1:
            raise Exception(f"Received invalid version header {version}, expected 0x01, for packet {packet}")
        
        type = packet[1]

        expected_types = {
            0x00: PacketParserV1._parse_identify,
            0x01: PacketParserV1._parse_identify_response,
            0x02: PacketParserV1._parse_read_request,
            0x03: PacketParserV1._parse_read_response,
            0x04: PacketParserV1._parse_write_request,
        }
        
        # (needs_addr_width, needs_data_width)
        required_params = {
            0x00: (False, False),
            0x01: (False, False),
            0x02: (True, False),
            0x03: (False, True),
            0x04: (True, True),
        }
        
        if type not in expected_types:
            raise Exception(f"Received packet type not implemented! Packet type {type}, for packet {packet}")
        
        needs_addr, needs_data = required_params[type]
        
        if needs_addr and addr_width == None:
            raise Exception(f"Packet with type {type} requires addr_width to be provided")
        
        if needs_data and data_width == None:
            raise Exception(f"Packet with type {type} requires data_width to be provided")

        return expected_types[type](packet, data_width, addr_width)
    
    def _parse_identify(packet, data_width, addr_width):
        assert len(packet) == 2, f"Identify should have length 2, packet len is {len(packet)}, for packet {packet}"
        return {"version": 0x01, "type": PacketParserV1.Identify}

    def _parse_identify_response(packet, data_width, addr_width):
        assert len(packet) == 6, f"Identify response should have length 6, packet len is {len(packet)}, for packet {packet}"
        
        device_type = packet[2]
        device_id = packet[3]
        addr_width = packet[4]
        data_width = packet[5]

        return {"version": 0x01, 
                "type": PacketParserV1.IdentifyResponse, 
                "device_type": device_type, 
                "device_id": device_id, 
                "addr_width": addr_width, 
                "data_width":data_width
        }
    
    
    def _parse_read_request(packet, data_width, addr_width):
        assert len(packet) == 4 + addr_width, f"Read request should have length 4 + {addr_width}, packet len is {len(packet)}, for packet {packet}"
        
        device_type = packet[2]
        device_id = packet[3]
        read_data = packet[4:4+addr_width]
        
        assert len(read_data) == addr_width, f"Tried to read {addr_width} data bytes, but couldn't, for packet {packet}" 
        
        return {"version": 0x01, 
                "type": PacketParserV1.ReadRequest, 
                "device_type": device_type, 
                "device_id": device_id, 
                "addr_width": addr_width, 
                "data_width":data_width,
                "addr": int.from_bytes(read_data, byteorder="big")
        }
    
    def _parse_read_response(packet, data_width, addr_width):
        assert len(packet) == 4 + data_width, f"Read response should have length 4 + {data_width}, packet len is {len(packet)}, for packet {packet}"
        
        device_type = packet[2]
        device_id = packet[3]
        read_data = packet[4:4+data_width]
        
        assert len(read_data) == data_width, f"Tried to read {data_width} data bytes, but couldn't, for packet {packet}" 
        
        return {"version": 0x01, 
                "type": PacketParserV1.ReadResponse, 
                "device_type": device_type, 
                "device_id": device_id, 
                "addr_width": addr_width, 
                "data_width":data_width,
                "data": int.from_bytes(read_data, byteorder="big")
        }
    
    def _parse_write_request(packet, data_width, addr_width):
        assert len(packet) == 4 + data_width + addr_width, f"Write request should have length 4 + {data_width} + {addr_width}, packet len is {len(packet)}, for packet {packet}"
        
        device_type = packet[2]
        device_id = packet[3]
        read_addr = packet[4:4+addr_width]
        assert len(read_addr) == addr_width, f"Tried to read {addr_width} addr bytes, but couldn't, for packet {packet}" 
        read_data = packet[4:4+data_width]
        assert len(read_data) == data_width, f"Tried to read {data_width} data bytes, but couldn't, for packet {packet}" 
        
        return {"version": 0x01, 
                "type": PacketParserV1.WriteRequest, 
                "device_type": device_type, 
                "device_id": device_id, 
                "addr_width": addr_width, 
                "data_width":data_width,
                "addr": int.from_bytes(read_addr, byteorder="big"),
                "data": int.from_bytes(read_data, byteorder="big")
        }
    

    def identify():
        return [0x01, 0x00]

    def read(device_type, device_id, addr, addr_width):
        header = [0x01, 0x02]
        dev_type = list(device_type.to_bytes(1, byteorder="big"))
        dev_id = list(device_id.to_bytes(1, byteorder="big"))
        addr = list(addr.to_bytes(addr_width, byteorder="big"))
        return header + dev_type + dev_id + addr
    
    def write(device_type, device_id, addr, addr_width, write, write_width):
        header = [0x01, 0x02]
        dev_type = list(device_type.to_bytes(1, byteorder="big"))
        dev_id = list(device_id.to_bytes(1, byteorder="big"))
        addr = list(addr.to_bytes(addr_width, byteorder="big"))
        write = list(write.to_bytes(write_width, byteorder="big"))
        return header + dev_type + dev_id + addr + write

class DebugBusManager:
    
    def __init__(self, dut_clk, input_bus, output_bus):
        from cocotb_util import DataQueue

        #All the 'input_bus' and 'output_bus' need to expose, are two function
        #   input_bus should have an async 'read' with a timeout
        #   output_bus should have an async 'write'
        
        self.clk = dut_clk
        self.input_bus = input_bus
        self.output_bus = output_bus
        self.devices = []
   
        self.identify_packet_queue = DataQueue()

        #Input and output queues for each device that's registered on this bus
        self.device_map = {}

        #TODO need a packet queue, as packets may come in out-of-order, 
        #How to do the packet receiving? Need to forward the right packets to the right places

    async def get_identify_responses(self, timeout=None):
        from cocotb_util import WithTimeout
    
        async def recv(self):
            pkt_q = self.identify_packet_queue
            while True:
                if pkt_q.size() != 0:
                    return pkt_q.get(1)[0]
                await self._receive_packet()

        return await WithTimeout(recv(self), self.clk, timeout=timeout)    

    async def _receive_packet(self, timeout=None):
        from cocotb_util import WithTimeout
        result, maybe_data = await WithTimeout(self.input_bus.recv(), self.clk, timeout)
        if not result:
            return False
        packet = PacketParserV1.parse(maybe_data.tdata)
        pkt_type = packet["type"]        
        if self.device_map == {}: #Meaning, we are not initalised yet
            assert pkt_type in [PacketParserV1.Identify, PacketParserV1.IdentifyResponse], f"In not initalized state, we received a non-identify packet {packet}"
            
            if pkt_type == PacketParserV1.IdentifyResponse:
                self.identify_packet_queue.put(packet)

        else:            
            device_id = (packet["device_type"], packet["device_id"])
            assert device_id in self.device_map, f"Received packet for {device_id} but it's not found in self.device_map"
            self.device_map[device_id].put(packet)

    async def wait_initialize(self, timeout=20):
        from cocotb_util import WithTimeout
        from cocotb.queue import Queue as CocotbQueue
        #Sends the 'identify' packet, waits for responses from all the devices on the bus
        #then returns 'AxisDebugDevice' (or subclasses) for each received device
        identify_packet = PacketParserV1.identify()
        result, _ = await WithTimeout(self.output_bus.send(identify_packet), self.clk, timeout)
        if not result:
            raise Exception(f"Did not receive any response packet within {timeout}")
        
        packets = []

        #Receive packets, or timeout if we don't receive any in a 
        while True:
            result, maybe_data = await self.get_identify_responses(timeout=timeout)
            if not result:
                break
            packets.append(maybe_data)
            
        #By device ID
        constructors = {
            0: AxisDebugDevice,
            1: AxisDebugDevice,
            2: AxisDebugDevice,
            3: AxisDebugDevice,
            4: AxisDebugDevice,
        }
        
        devices = []

        for packet in packets:
            assert packet["device_type"] in constructors, f"Packet type {packet} not supported"
            assert (packet["device_type"], packet["device_id"]) not in self.device_map, f"Device with packet {packet} already registered"
            constructor = constructors[packet["device_type"]]
            queue_tuple = (CocotbQueue(), CocotbQueue())
            self.device_map[(packet["device_type"], packet["device_id"])] = queue_tuple
            device_wrapper = constructor(
                    input_queue = queue_tuple[0], 
                    output_queue = queue_tuple[1], 
                    data_width = packet["data_width"], 
                    addr_width = packet["addr_width"],
                    device_type = packet["device_type"],
                    device_id = packet["device_id"])
            devices.append(device_wrapper)
        return devices


class AxisDebugDevice:

    def __init__(self, 
                 input_queue = None, 
                 output_queue = None,
                 data_width: int = None,
                 addr_width: int = None,
                 device_type: int = None,
                 device_id: int = None):
        
        assert device_type  != None, "device_type: [int] needs to be provided"
        assert device_id    != None, "device_id: [int] needs to be provided"
        assert data_width   != None, "data_width: [int] needs to be provided"
        assert addr_width   != None, "addr_width: [int] needs to be provided"
        assert input_queue  != None, "input_queue: [cocotb.queue.Queue] needs to be provided"
        assert output_queue  != None, "output_queue: [cocotb.queue.Queue] needs to be provided"
        
        self.device_type = device_type
        self.device_id = device_id
        self.data_width = data_width
        self.addr_width = addr_width
        #Any 'send' bytes are written to the output_queue
        #And 'recv' bytes are read  from the input_queue
        self.input_queue = input_queue
        self.output_queue = output_queue
    
    async def send_read(self, addr):
        #Does reading from the address, 
        
        pass 



    #Send a packet 
    def _send_packet(self, addr, data):
        
        pass
