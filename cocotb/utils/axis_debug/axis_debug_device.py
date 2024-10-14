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
    
    def parse(packet, devices):
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
        
        return expected_types[type](packet, devices)
    
    def _parse_identify(packet, devices):
        import logging
        logging.getLogger("cocotb.packet_parser_v1").info(f"Parse Identify: Received {packet}")
        assert len(packet) == 2, f"Identify should have length 2, packet len is {len(packet)}, for packet {packet}"
        return {"version": 0x01, "type": PacketParserV1.Identify}

    def _parse_identify_response(packet, devices):
        import logging
        logging.getLogger("cocotb.packet_parser_v1").info(f"Parse Identify Response: Received {packet}")
        assert len(packet) == 6, f"Identify response should have length 6, packet len is {len(packet)}, for packet {packet}"
        
        device_type = packet[2]
        device_id = packet[3]
        addr_width = packet[4]
        data_width = packet[5]

        dev_id = (device_type, device_id)
        if dev_id in devices:
            assert devices[dev_id]["addr_width"] == addr_width, f"addr_width of newly received identify response doesn't match existing device"
            assert devices[dev_id]["data_width"] == data_width, f"data_width of newly received identify response doesn't match existing device"

        return {"version": 0x01, 
                "type": PacketParserV1.IdentifyResponse, 
                "device_type": device_type, 
                "device_id": device_id, 
                "addr_width": addr_width, 
                "data_width":data_width
        }
    
    
    def _parse_read_request(packet, devices):
        import logging
        logging.getLogger("cocotb.packet_parser_v1").info(f"Parse Read Request: Received {packet}")
        device_type = packet[2]
        device_id = packet[3]
        dev_id = (device_type, device_id)
        assert dev_id in devices, f"Tried to parse read request, but device {dev_id} not found in known devices {devices}" 
        
        addr_width = devices[dev_id]["addr_width"]    
        data_width = devices[dev_id]["data_width"]    
        assert len(packet) == 4 + addr_width, f"Read request should have length 4 + {addr_width}, packet len is {len(packet)}, for packet {packet}"

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
    
    def _parse_read_response(packet, devices):
        import logging
        logging.getLogger("cocotb.packet_parser_v1").info(f"Parse Read Response: Received {packet}")
        
        device_type = packet[2]
        device_id = packet[3]
        dev_id = (device_type, device_id)
        assert dev_id in devices, f"Tried to parse read response, but device {dev_id} not found in known devices {devices}" 
        
        addr_width = devices[dev_id]["addr_width"]    
        data_width = devices[dev_id]["data_width"]    
        assert len(packet) == 4 + data_width + addr_width, f"Read response should have length 4 + {data_width} + {addr_width}, packet len is {len(packet)}, for packet {packet}"
        read_addr = packet[4:4+addr_width]
        assert len(read_addr) == addr_width, f"Tried to read {addr_width} addr bytes, but couldn't, for packet {packet}" 
        read_data = packet[4+addr_width:4+addr_width+data_width]
        assert len(read_data) == data_width, f"Tried to read {data_width} data bytes, but couldn't, for packet {packet}" 
        
        return {"version": 0x01, 
                "type": PacketParserV1.ReadResponse, 
                "device_type": device_type, 
                "device_id": device_id, 
                "addr_width": addr_width, 
                "data_width":data_width,
                "data": int.from_bytes(read_data, byteorder="big")
        }
    
    def _parse_write_request(packet, devices):
        import logging
        logging.getLogger("cocotb.packet_parser_v1").info(f"Parse Write Request: Received {packet}")
        
        device_type = packet[2]
        device_id = packet[3]
        dev_id = (device_type, device_id)
        assert dev_id in devices, f"Tried to parse write request, but device {dev_id} not found in known devices {devices}" 
        
        addr_width = devices[dev_id]["addr_width"]    
        data_width = devices[dev_id]["data_width"]    
        assert len(packet) == 4 + data_width + addr_width, f"Write request should have length 4 + {data_width} + {addr_width}, packet len is {len(packet)}, for packet {packet}"
        read_addr = packet[4:4+addr_width]
        assert len(read_addr) == addr_width, f"Tried to read {addr_width} addr bytes, but couldn't, for packet {packet}" 
        read_data = packet[4+addr_width:4+addr_width+data_width]
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
        header = [0x01, PacketParserV1.ReadRequest]
        dev_type = list(device_type.to_bytes(1, byteorder="big"))
        dev_id = list(device_id.to_bytes(1, byteorder="big"))
        addr = list(addr.to_bytes(addr_width, byteorder="big"))
        return header + dev_type + dev_id + addr
    
    def write(device_type, device_id, addr, addr_width, write, write_width):
        header = [0x01, PacketParserV1.WriteRequest]
        dev_type = list(device_type.to_bytes(1, byteorder="big"))
        dev_id = list(device_id.to_bytes(1, byteorder="big"))
        addr = list(addr.to_bytes(addr_width, byteorder="big"))
        write = list(write.to_bytes(write_width, byteorder="big"))
        return header + dev_type + dev_id + addr + write

class DebugBusManager:
    
    def __init__(self, dut_clk, input_bus, output_bus):
        from cocotb_util import DataQueue
        from threading import Lock

        #All the 'input_bus' and 'output_bus' need to expose, are two function
        #   input_bus should     have an async 'read' with a timeout
        #   output_bus should have an async 'write'
        
        self.clk = dut_clk
        self.input_bus = input_bus
        self.output_bus = output_bus
        self.devices = {}

        self.packet_queue_lock = Lock()

        self.identify_packet_queue = DataQueue()

        #Input and output queues for each device that's registered on this bus
        self.device_map = {}

        #TODO need a packet queue, as packets may come in out-of-order, 
        #How to do the packet receiving? Need to forward the right packets to the right places
    
    async def _get_packet_from_queue(self, queue, timeout=None):
    
        async def recv(self):
            pkt_q = queue
            while True:
                if pkt_q.size() != 0:
                    return True, pkt_q.get(1)[0]
                if not await self._receive_packet(timeout=timeout):
                    return False, None
        
        with self.packet_queue_lock:
            return await recv(self)

    async def get_identify_responses(self, timeout=None):
        return await self._get_packet_from_queue(self.identify_packet_queue, timeout=timeout)

    async def get_packet(self, device_type, device_id, timeout=None):
        dev_id = (device_type, device_id)
        assert dev_id in self.device_map, f"Tried to get packet for device {dev_id} but no such device exists"
        return await self._get_packet_from_queue(self.device_map[dev_id], timeout)

    async def write(self, data):
        await self.output_bus.write(data)

    async def _receive_packet(self, timeout=None):
        from cocotb_util import WithTimeout
        if self.clk == None:
            result, maybe_data = await self.input_bus.recv(timeout)    
        else:
            result, maybe_data = await WithTimeout(self.input_bus.recv(), self.clk, timeout)
        if not result:
            return False
        if not isinstance(maybe_data, bytes):
            #Assume it's an AxiStreamFrame
            maybe_data = maybe_data.tdata
        packet = PacketParserV1.parse(maybe_data, self.devices)
        pkt_type = packet["type"]        
        if self.device_map == {}: #Meaning, we are not initalised yet
            assert pkt_type in [PacketParserV1.Identify, PacketParserV1.IdentifyResponse], f"In not initalized state, we received a non-identify packet {packet}"
            
            if pkt_type == PacketParserV1.IdentifyResponse:
                self.identify_packet_queue.put(packet)

        else:            
            device_id = (packet["device_type"], packet["device_id"])
            assert device_id in self.device_map, f"Received packet for {device_id} but it's not found in self.device_map"
            self.device_map[device_id].put(packet)
        
        return True

    async def wait_initialize(self, timeout=20):
        from cocotb.queue import Queue as CocotbQueue
        from cocotb_util import DataQueue
        #Sends the 'identify' packet, waits for responses from all the devices on the bus
        #then returns 'AxisDebugDevice' (or subclasses) for each received device
        identify_packet = PacketParserV1.identify()
        
        await self.output_bus.write(identify_packet)
        
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
            4: AxisDebugStreamMonitor,
        }
        
        devices = []

        for packet in packets:
            assert packet["device_type"] in constructors, f"Packet type {packet} not supported"
            assert (packet["device_type"], packet["device_id"]) not in self.device_map, f"Device with packet {packet} already registered"
            constructor = constructors[packet["device_type"]]
            input_queue = DataQueue()
            dev_id = (packet["device_type"], packet["device_id"])
            self.device_map[dev_id] = input_queue
            self.devices[dev_id] = {"data_width": packet["data_width"], "addr_width": packet["addr_width"]} 
            device_wrapper = constructor(
                    bus_mgr = self,
                    data_width = packet["data_width"], 
                    addr_width = packet["addr_width"],
                    device_type = packet["device_type"],
                    device_id = packet["device_id"])
            devices.append(device_wrapper)
        return devices


class AxisDebugDevice:

    def __init__(self, 
                 bus_mgr     = None,
                 data_width: int = None,
                 addr_width: int = None,
                 device_type: int = None,
                 device_id: int = None):
        
        assert device_type  != None, "device_type: [int] needs to be provided"
        assert device_id    != None, "device_id: [int] needs to be provided"
        assert data_width   != None, "data_width: [int] needs to be provided"
        assert addr_width   != None, "addr_width: [int] needs to be provided"
        assert bus_mgr      != None, "bus_mgr: [DebugBusManager] needs to be provided"
        
        self.device_type = device_type
        self.device_id = device_id
        self.data_width = data_width
        self.addr_width = addr_width
        #Any 'send' bytes are written to the output_queue
        #And 'recv' bytes are read  from the input_queue
        self.bus_mgr = bus_mgr
    
    async def write(self, addr, write_data, timeout=50):
        await self.bus_mgr.write(PacketParserV1.write(
                    self.device_type, 
                    self.device_id, 
                    addr, 
                    self.addr_width, 
                    write_data, 
                    self.data_width
                ))
        #Get the echo'd back write 
        has_response, response = await self.bus_mgr.get_packet(self.device_type, self.device_id, timeout)
        assert has_response, f"Failed to get response to read at addr={addr} in {timeout} cycles"  
        assert response["type"] == PacketParserV1.WriteRequest, f"Expected the received packet to be a write request, instead got {response}"



    async def read(self, addr, timeout=50):
        await self.bus_mgr.write(PacketParserV1.read(
                    self.device_type, 
                    self.device_id, 
                    addr, 
                    self.addr_width 
                ))
        #Get the echo'd back read request
        has_response, response = await self.bus_mgr.get_packet(self.device_type, self.device_id, timeout)
        assert has_response, f"Failed to get response to read at addr={addr} in {timeout} cycles"  
        assert response["type"] == PacketParserV1.ReadRequest, f"Expected the received packet to be a read request, instead got {response}"
        

        has_response, response = await self.bus_mgr.get_packet(self.device_type, self.device_id, timeout)
        assert has_response, f"Failed to get response to read at addr={addr} in {timeout} cycles"  
        assert response["type"] == PacketParserV1.ReadResponse, f"Expected the received packet to be a read request, instead got {response}"

        return response["data"] 
        

class AxisDebugStreamMonitor(AxisDebugDevice):
    
    async def read_pkt_counter(self):
        return await self.read(0)

    async def activate_trigger(self):
        await self.write(1, 1)

    async def is_triggered(self):
        return await self.read(1) == 0
    
    #Trim invalid will trim all rows of data where ~valid, as the entire transaction is saved by the monitor
    async def readout_packet(self, trim_invalid=False):
        from bitstruct import unpack
        
        packet_length = await self.read(2)
        
        packet = []

        is_aborted = False

        for i in range(packet_length):
            read_addr = i + 32768
            data_row = await self.read(read_addr);
            data_row_bytes = data_row.to_bytes(5, byteorder="big")
            padding, data_int, keep, abort, valid = unpack('u4u32u2u1u1', data_row_bytes)
            assert padding == 0, f"The padding received was not 0, which is expected from the SV implementation (if it isn't remove this assert)"
            is_aborted = is_aborted or abort == 1
            data_bytes = data_int.to_bytes(4, byteorder="little")
            for byte in list(data_bytes[0:keep+1]):
                packet.append(byte)
        
        return packet

        #Wait until we're triggered, then read the length, then read the bytes from the memory
        #Assemble everything, return the packet
