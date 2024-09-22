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

def write_packet(data, expect_response=0):
    ser.write(bytearray([len(data)] + data))
    ser.flush()
    #Loopback packet
    pkt_len = int.from_bytes(ser.read())
    pkt = []
    for _ in range(pkt_len):
        data = int.from_bytes(ser.read())
        pkt.append(data)
    #response packet
    pkts = []
    while expect_response > 0:
        pkt_len = int.from_bytes(ser.read())
        pkt = []
        for _ in range(pkt_len):
            data = int.from_bytes(ser.read())
            pkt.append(data)
        pkts.append(pkt)
        expect_response -= 1
    else:
        return pkts

#Identify packet
input_packets = write_packet([0x01, 0x00], expect_response=3)

i2c_devices = []

for input_packet in input_packets:
    type = input_packet[2]
    id = input_packet[3]
    if type != 0x02:
        continue
    i2c_devices.append((type, id))

print(f"Found devices: {i2c_devices}")

#0x71
#0x48
type, id = i2c_devices[0]
while True:
    for i in range(255):
    #Write 1 to address 0
        print(i)
        outputs = write_packet([0x01, 0x04, type, id] + [0b01001000, i], expect_response=0)
        time.sleep(0.1)
