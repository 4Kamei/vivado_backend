import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
from queue import SimpleQueue

CLOCK_FREQUENCY = 12_000_000
BAUD_RATE = 10000

"""
//Transmit side connections
input logic i_clk,
input logic i_rst_n,
input logic i_tx_en,
input logic [7:0] i_tx_data,
output logic o_uart_busy,

//Receive side connections
output logic [7:0] o_rx_data,
output logic o_rx_en
"""

#Fork a scoreboard. If we successfully send -> Namely, 'busy' goes low, then append to
#Make writes from a different coroutine and everyone is happy



@cocotb.test()
async def test_uart_internals(dut):
    clock = Clock(dut.i_clk, 10, "ns")
    cocotb.start_soon(clock.start())

    

    scoreboard = Scoreboard(dut._log)
    #Create a receiver and run its loop
    wrapped_dut = DUT(dut)
    await wrapped_dut.reset()
    
    receiver = Receiver(wrapped_dut, scoreboard) 
    receiver_task = cocotb.start_soon(receiver.start())
    
    #all cold, 1-hot, alternating + variations + inverses of all
    values = [
            0b00000000,
            0b00000001,
            0b00000010,
            0b00000100,
            0b00001000,
            0b00010000,
            0b00100000,
            0b01000000,
            0b10000000,
            0b01010101,
            0b00100100,
            0b01001001,
            0b10010010,
            0b10001000,
            0b01000100,
            0b00100010,
            0b00010001
    ] 
    values += [~k & (0xFF) for k in values]
    
    for value in values:
        await wrapped_dut.send_and_wait(value)
        scoreboard.transmit(value)

    #Wait for the receiver to finish getting all the sent bytes
    receiver_task.join()

class DUT():
    def __init__(self, dut):
        self.dut = dut

    async def reset(self):
        await RisingEdge(self.dut.i_clk)
        self.dut.i_rst_n.value = 0
        await RisingEdge(self.dut.i_clk)
        self.dut.i_rst_n.value = 1
        await RisingEdge(self.dut.i_clk)
        await RisingEdge(self.dut.i_clk)

    async def send_and_wait(self, byte):
        #Sets the data and transmit enable, then waits until we're ready to transmit again
        await RisingEdge(self.dut.i_clk)
        self.dut.i_tx_data.value = byte
        self.dut.i_tx_en.value = 1
        await RisingEdge(self.dut.i_clk)
        self.dut.i_tx_en.value = 0
        #TODO what to do if this can time out? Need to check that we don't take too long to send the packet otherwise
        #the test may hang -> run a 'timer', and a 'select!'?
        await FallingEdge(self.dut.o_uart_busy)
            
    async def receive(self):
        #TODO how long to await for?
        await RisingEdge(self.dut.o_rx_en)
        return int(self.dut.o_rx_data.value)

class Receiver():
    def __init__(self, dut, scoreboard):
        self.dut = dut
        self.scoreboard = scoreboard
     
    async def start(self):
        while True:
            value = await self.dut.receive()        
            self.scoreboard.receive(value)
            if self.scoreboard.should_exit():
                return

#Write to scoreboard from two threads -> 
class Scoreboard():
    def __init__(self, log):
        self.log = log
        self.transmitted = SimpleQueue()
        self.received = SimpleQueue()

    def transmit(self, byte):
        self.transmitted.put(byte)
        self.__check_bytes()

    def receive(self, byte):
        self.received.put(byte)
        self.__check_bytes()

    def __check_bytes(self):
        while not self.transmitted.empty() and not self.received.empty():
            tx_byte = self.transmitted.get()
            rx_byte = self.received.get()
            assert tx_byte == rx_byte, "Sent byte is not received byte"
            self.log.info(f"Scoreboard: {hex(tx_byte)} == {hex(rx_byte)}")

    def should_exit(self):
        return self.received.empty()
