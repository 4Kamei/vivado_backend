import serial
import time
import random
from queue import Queue

from scapy.layers.l2 import Ether
from scapy.packet import ls

from axis_debug.axis_debug_device import DebugBusManager, AxisDebugStreamMonitor

class UartSink():

    def __init__(self, ser):
        self.ser = ser


    def _recv(self, timeout):
        #Receive the packet length
        self.ser.timeout = timeout / 1000 #Timeout is in ms
        pkt_len = list(self.ser.read(1))
        if len(pkt_len) == 0:
            return False, None
        pkt_len = pkt_len[0]
        self.ser.timeout = None
        packet = self.ser.read(pkt_len)
        return True, packet
        
    #A bit hacky, as ser.read() is blokcings
    async def recv(self, timeout=None):
        import asyncio
        loop = asyncio.get_running_loop()
    
        return await loop.run_in_executor(None, self._recv, timeout)

class UartSource():
    def __init__(self, ser):
        self.ser = ser
    
    async def write(self, data):
        self.ser.write(bytearray([len(data)] + data))
        self.ser.flush()

async def run():

    ser = serial.Serial(
            "/dev/ttyUSB0", 
            baudrate=115200, 
            bytesize=serial.EIGHTBITS, 
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE)

    uart_sink = UartSink(ser)
    uart_source = UartSource(ser)

    bus_mgr = DebugBusManager(None, uart_sink, uart_source)
    out = await bus_mgr.wait_initialize(timeout=20) #Timeout in ms

    axis_stream_monitor = None
    for device in out:
        if isinstance(device, AxisDebugStreamMonitor):
            axis_stream_monitor = device
            break
    assert axis_stream_monitor != None, f"Couldn't find axis stream monitor"

    await axis_stream_monitor.activate_trigger()

    print("Waiting until we get a packet : ", end="", flush=True)
    while not await axis_stream_monitor.is_triggered():
        #print(await axis_stream_monitor.read_pkt_counter())
        time.sleep(1)
        print(".", end= "", flush=True)
    
    packet = await axis_stream_monitor.readout_packet(trim_invalid=False)
    
    print("")
    print(packet)
    print("")   
    


if __name__ == "__main__":
    import asyncio
    asyncio.run(run())
