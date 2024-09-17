import serial
import time
import random
from queue import Queue

ser = serial.Serial(
        "/dev/ttyUSB0", 
        baudrate=115200, 
        bytesize=serial.EIGHTBITS, 
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE)

random.seed(234)

all_packets = Queue()
written_bytes = 0

for _ in range(20):
    data = [0x00] + [random.randint(0, 255) for _ in range(random.randint(1, 10))]
    print(f"Writing {data}")

    for k in [len(data)] + data:
        k_out = k
        ba = bytearray.fromhex(hex(256 + k_out)[3:])
        ser.write(ba)
        ser.flush()
    written_bytes += len(data)
    print(f"Written bytes: {written_bytes}")
    
read_bytes = 0
while written_bytes != read_bytes:
    pkt_len = int.from_bytes(ser.read())
    print(f"Read length as {pkt_len}")
    pkt = []
    for _ in range(pkt_len):
        data = int.from_bytes(ser.read())
        pkt.append(data)
    print(pkt)
    read_bytes += len(pkt)
