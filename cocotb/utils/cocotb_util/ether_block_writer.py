from cocotb_util import DataQueue, FixedWidth

def run():
    q = EtherBlockWriter()
    
    for _ in range(10):
        hdr, payload = q.next_block()
        print(hdr, hex(payload + 2 ** 64)[3:])
    
    q.queue_control(0x1e)   #1e == 0x0011110 but we read 8 hence 0x00111100 => 3C

    hdr, payload = q.next_block()
    print(hdr, hex(payload + 2 ** 64)[3:])

    q.queue_control(0x1e)   #1e == 0x0011110 but we read 8 hence 0x00111100 => 3C
    q.queue_ordered_set({"type": 0xF, "data": [0x00, 0x00, 0x01]})
    q.queue_ordered_set({"type": 0xF, "data": [0x00, 0x00, 0x01]})
                        
    hdr, payload = q.next_block()
    print(hdr, hex(payload + 2 ** 64)[3:])

    hdr, payload = q.next_block()
    print(hdr, hex(payload + 2 ** 64)[3:])
    
    hdr, payload = q.next_block()
    print(hdr, hex(payload + 2 ** 64)[3:])

    data_bytes = [
    0xff,0xff,0xff,0xff,0xff,0xff,0x1c,0x34,
    0xda,0x09,0x8f,0x51,0x08,0x00,0x45,0x00,
    0x01,0x65,0x03,0x45,0x00,0x00,0x40,0x11,
    0x76,0x44,0x00,0x00,0x00,0x00,0xff,0xff,
    0xff,0xff,0x00,0x44,0x00,0x43,0x01,0x51,
    0xa8,0x4d,0x01,0x01,0x06,0x00,0x61,0xb8,
    0x89,0xaa,0x05,0x79,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x1c,0x34,
    0xda,0x09,0x8f,0x51,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x63,0x82,
    0x53,0x63,0x35,0x01,0x01,0x37,0x0e,0x01,
    0x79,0x03,0x06,0x0c,0x0f,0x1a,0x1c,0x21,
    0x2a,0x33,0x3a,0x3b,0x77,0x39,0x02,0x05,
    0xc0,0x3c,0x2d,0x64,0x68,0x63,0x70,0x63,
    0x64,0x2d,0x31,0x30,0x2e,0x30,0x2e,0x36,
    0x3a,0x4c,0x69,0x6e,0x75,0x78,0x2d,0x36,
    0x2e,0x39,0x2e,0x32,0x3a,0x78,0x38,0x36,
    0x5f,0x36,0x34,0x3a,0x47,0x65,0x6e,0x75,
    0x69,0x6e,0x65,0x49,0x6e,0x74,0x65,0x6c,
    0x0c,0x0a,0x6b,0x61,0x6d,0x65,0x69,0x2d,
    0x6d,0x61,0x69,0x6e,0x74,0x01,0x01,0x91,
    0x01,0x01,0xff,0xe8,0x90,0x33,0x98]

    q.queue_data(data_bytes)
    
    for _ in range(40):
        hdr, payload = q.next_block()
        print(hdr, hex(payload + 2 ** 64)[3:])
    
    q.queue_data(data_bytes)
    
    for _ in range(40):
        hdr, payload = q.next_block()
        print(hdr, hex(payload + 2 ** 64)[3:])

#Schedules arbitrary lengths of data bytes/control/ordered sets into blocks with the correct headers
class EtherBlockWriter():
    def __init__(self, random_bit = None):
        #Used for controlling what's written out as blocks
        self.data_queue = DataQueue()
        self.control_queue = DataQueue()
        self.ordered_set_queue = DataQueue()
        self.error_queue = DataQueue()
        self.current_packet = None 
        if not random_bit:
            import random
            self.random_bit = lambda: random.randint(0, 1)
    def next_block(self):
        if self.current_packet == None:
            control_signals = self.control_queue.size()
            ordered_sets = self.ordered_set_queue.size()
            has_data = self.data_queue.size() > 0

            if control_signals == 0 and ordered_sets == 0 and has_data:
                self.current_packet = self.data_queue.get(1)[0]
                return self.__format_packet(
                        0x78, self.current_packet.get(7))
            
            if control_signals <= 4 and ordered_sets == 0 and has_data:
                self.current_packet = self.data_queue.get(1)[0]
                return self.__format_packet(
                        0x33, self.control_queue.get_or_default(4, FixedWidth(0, 7)), FixedWidth(0, 4), self.current_packet.get(3))
            
            if control_signals == 0 and ordered_sets >= 2:
                os1 = self.ordered_set_queue.get(1)[0]
                os2 = self.ordered_set_queue.get(1)[0]
                return self.__format_packet(
                        0x55, os1["data"], os1["type"], os2["type"], os2["data"])
           
            if ordered_sets >= 1 and not has_data:
                os = self.ordered_set_queue.get(1)[0]
                if self.random_bit() == 0:
                    return self.__format_packet(
                        0x2d, self.control_queue.get_or_default(4, FixedWidth(0, 7)), os["type"], os["data"])      
                else:
                    return self.__format_packet(
                        0x4b, os["data"], os["type"], self.control_queue.get_or_default(4, FixedWidth(0, 7)))      
            
            if control_signals == 0 and ordered_sets == 1 and has_data:
                self.current_packet = self.data_queue.get(1)[0]
                ordered_set = self.ordered_set_queue.get(1)[0]
                print(ordered_set)
                return self.__format_packet(
                        0x66, ordered_set["data"], ordered_set["type"], FixedWidth(0, 4), self.current_packet.get(3))      

            return self.__format_packet(
                        0x1e, self.control_queue.get_or_default(8, FixedWidth(0, 7)))
        
        if self.current_packet != None:
            
            bytes_remaining = self.current_packet.size()
            if bytes_remaining >= 8:
                return self.__format_packet_data(self.current_packet.get(8))
            
            packet = self.current_packet
            self.current_packet = None

            if bytes_remaining == 0:
                return self.__format_packet(
                        0x87, FixedWidth(0, 7), self.control_queue.get_or_default(7, FixedWidth(0, 7)))
            
            packet_type, num_controls = {
                1: (0x99, 6),
                2: (0xaa, 5),
                3: (0xb4, 4),
                4: (0xcc, 3),
                5: (0xd2, 2),
                6: (0xe1, 1),
                7: (0xff, 0)
            }[bytes_remaining]

            control_sigs = self.control_queue.get_or_default(num_controls, FixedWidth(0, 7))
            return self.__format_packet(
                    packet_type, packet.get(bytes_remaining), FixedWidth(0, num_controls), control_sigs)                        

    def __flatten(self, S):
        if S == []:
            return S
        if isinstance(S[0], list):
            return self.__flatten(S[0]) + self.__flatten(S[1:])
        return S[:1] + self.__flatten(S[1:])
    
    def __format_packet_data(self, *args):
        data = []
        for arg in self.__flatten(list(args)):
            data += [arg.convert()]
        errors = self.error_queue.get_or_default(1, FixedWidth(0, 66))[0].convert()
        hdr_errors = errors[0:2]
        data_errors = errors[2:]
        hdr_errors = int("".join(map(str, hdr_errors)), 2)
        data_errors = int("".join(map(str, data_errors)), 2)

        output_data = [str(p) for k in data for p in k]
        assert len(output_data) == 64, f"Output data from packet is not 64 in length. ({len(output_data)} != 64)"
        return 1 ^ hdr_errors, int("".join(output_data), 2) ^ data_errors

    def __format_packet(self, block_type_in, *args):
        block_type = FixedWidth(block_type_in, 8, reverse=True).convert() 
            
        data = [block_type]
        for arg in self.__flatten(list(args)):
            data += [arg.convert()]
        
        errors = self.error_queue.get_or_default(1, FixedWidth(0, 66))[0].convert()
        hdr_errors = errors[0:2]
        data_errors = errors[2:]
        hdr_errors = int("".join(map(str, hdr_errors)), 2)
        data_errors = int("".join(map(str, data_errors)), 2)
        
        output_data = [str(p) for k in data for p in k]
        assert len(output_data) == 64, f"Output data from packet is not 64 in length. ({len(output_data)} != 64)"
        return 2 ^ hdr_errors, int("".join(output_data), 2) ^ data_errors

    def queue_error(self, position):
        offset = position % 66
        block_num = position // 66
        for i in range(block_num):
            self.error_queue.put(FixedWidth(0x00, 66))
        self.error_queue.put(FixedWidth(1 << (66 - offset - 1),66))

    def queue_data(self, data, with_eth_header=False):
        packet = DataQueue()
        if with_eth_header:
            for _ in range(6):
                packet.put(FixedWidth(0xaa, 8))
            packet.put(FixedWidth(0xab, 8))
        for data_byte in data:
            packet.put(FixedWidth(data_byte, 8))
        self.data_queue.put(packet)

    def queue_control(self, *args):
        for signal in args:
            self.control_queue.put(FixedWidth(signal, 7, reverse=False))

    def queue_ordered_set(self, *args):
        for os in args:
            self.ordered_set_queue.put({"type": FixedWidth(os["type"], 4), "data": [FixedWidth(p, 8) for p in os["data"]]})

if __name__ == "__main__":
    run()
