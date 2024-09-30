from ether_block_writer import EtherBlockWriter

class GtxInterface:
    def __init__(self, clock, gtx_scheduler: EtherBlockWriter, ports: dict, output_width = 32, pause_at = [64, 65]):
        self.gtx_scheduler = gtx_scheduler
        self.output_width = output_width
        self.clock = clock
        assert (64 % self.output_width) == 0, "output_width should divide 64 evenly"
        assert "data"        in ports, "Ports should have data, datavalid, header, headervalid"
        assert "datavalid"   in ports, "Ports should have data, datavalid, header, headervalid"
        assert "header"      in ports, "Ports should have data, datavalid, header, headervalid"
        assert "headervalid" in ports, "Ports should have data, datavalid, header, headervalid"
        self.ports = ports
        self.header = None
        self.data = None
        self.index = 0
        self.count = 0
        self.pause_at = pause_at
        
        import cocotb
        cocotb.start_soon(self.run())

    async def run(self):
        self.ports["datavalid"].value = 0
        self.ports["headervalid"].value = 0

        from cocotb.triggers import FallingEdge
        
        while True:
            await FallingEdge(self.clock)
            if self.count % 66 in self.pause_at:
                self.ports["datavalid"].value = 0
                self.ports["headervalid"].value = 0
            else:
                if self.header == None:
                    self.header, self.data = self.gtx_scheduler.next_block()
                    #Reverse data
                    #self.data = int(bin(2 ** 64 + self.data)[3:][::-1],2)
                    self.index = 0
                    self.ports["datavalid"].value = 1
                    self.ports["headervalid"].value = 1
                    self.ports["header"].value = self.header
                else:
                    self.ports["datavalid"].value = 1
                    self.ports["headervalid"].value = 0
                    self.ports["header"].value = 0

                self.ports["data"].value = (self.data >> (64 - self.index - self.output_width)) & (2 ** self.output_width - 1)
                self.index += self.output_width
                if self.index == 64:
                    self.header = None

            self.count += 1
            #Guaranteed to have more that enough bits to send
