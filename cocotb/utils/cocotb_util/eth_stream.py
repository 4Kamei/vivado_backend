from cocotb.triggers import FallingEdge, RisingEdge
from cocotb_util import DataQueue, FixedWidth

class EthStreamSource:

    def __init__(self, clock, bus):
        assert "data"  in bus, "data, keep, valid, last and abort must be defined"
        assert "keep"  in bus, "data, keep, valid, last and abort must be defined"
        assert "valid" in bus, "data, keep, valid, last and abort must be defined"
        assert "abort" in bus, "data, keep, valid, last and abort must be defined"
        assert "last"  in bus, "data, keep, valid, last and abort must be defined"
        assert 2 ** bus["keep"].value.n_bits == bus["data"].value.n_bits / 8, "\'keep\' width must be log2 of \'data\' byte width. \'data\' width (in bytes) must be 2 ** n"
        self.bus = bus
        self.clock = clock
        self.data = DataQueue()
        self.abort_generator = lambda x: False
        self.valid_generator = lambda x: True
        self.currently_sending = None
        self.byte_width = (bus["data"].value.n_bits // 8)
        
        import cocotb
        cocotb.start_soon(self.run())

    async def run(self):
        while True:
            await RisingEdge(self.clock)
            #Treat the initialization here, so below we can assume that 
            #if currently_sending == None, we shouldn't be sending any data
            if self.currently_sending == None:
                if self.data.size() > 0:
                    self.currently_sending = self.data.get(1)[0]          

            if self.currently_sending == None:
                self.bus["valid"].value = 0
                self.bus["keep"].value = 0
                self.bus["last"].value = 0
            else:
                num_bytes = self.currently_sending.size()
                if num_bytes > self.byte_width:
                    self.bus["valid"].value = 1
                    #'keep' has values 0, ..., self.byte_width - 1
                    self.bus["keep"].value = (self.byte_width - 1)
                    send_data = self.currently_sending.get(self.byte_width)
                    self.bus["data"].value = int.from_bytes(bytearray(send_data), byteorder="big")
                    self.bus["abort"].value = 0
                    self.bus["last"].value = 0
                else:
                    self.bus["valid"].value = 1
                    #'keep' has values 0, ..., self.byte_width - 1
                    self.bus["keep"].value = (self.currently_sending.size() - 1)
                    send_data = self.currently_sending.get_or_default(self.byte_width, 0x00)
                    self.bus["data"].value = int.from_bytes(bytearray(send_data), byteorder="big")
                    self.bus["abort"].value = 0
                    self.bus["last"].value = 1
                    self.currently_sending = None

    def send_nowait(self, data):
        in_data = DataQueue()
        for p in list(data):
            assert p & (2 ** 8 - 1) == p, "Provided data is bigger than a byte"
            in_data.put(p)
        self.data.put(in_data)    

class EthStreamSink:
    def __init__(self, clock, bus):
        assert "data"  in bus, "data, keep, valid, last and abort must be defined"
        assert "keep"  in bus, "data, keep, valid, last and abort must be defined"
        assert "valid" in bus, "data, keep, valid, last and abort must be defined"
        assert "abort" in bus, "data, keep, valid, last and abort must be defined"
        assert "last"  in bus, "data, keep, valid, last and abort must be defined"
        assert 2 ** bus["keep"].value.n_bits == bus["data"].value.n_bits / 8, "\'keep\' width must be log2 of \'data\' byte width. \'data\' width (in bytes) must be 2 ** n"
        self.bus = bus
        self.clock = clock
        self.data = DataQueue()
        self.valid_generator = lambda x: True
        self.is_aborted = False
        self.currently_receiving = None
        self.byte_width = (bus["data"].value.n_bits // 8)
        import cocotb
        cocotb.start_soon(self.run())
        import logging
        self.logger = logging.getLogger("cocotb")

    async def run(self):
        while True:
            await RisingEdge(self.clock)
            if self.currently_receiving == None:
                if int(self.bus["valid"].value) == 1:
                    self.currently_receiving = DataQueue()
            if self.currently_receiving != None:
                keep = int(self.bus["keep"].value)+ 1
                last = int(self.bus["last"].value)
                input_data = int(self.bus["data"].value).to_bytes(4, byteorder="little", signed=False)
                for k in input_data[0:keep]:
                    self.currently_receiving.put(k)
                if keep != 4:
                    assert last == 1, "Sent less than bus_width of bytes, last wasn't asserted"
                if last == 1:
                    self.logger.info(f"Received packet with length {self.currently_receiving.size()}")
                    self.data.put(self.currently_receiving.get(self.currently_receiving.size()))
                    self.currently_receiving = None
                    
    async def recv(self, timeout=None):
        counter = 0
        while self.data.size() == 0:
            counter += 1
            await RisingEdge(self.clock)
            if timeout and counter == timeout:
                assert False, f"Could not receive block in {timeout} clocks"
        return self.data.get(1)[0]
