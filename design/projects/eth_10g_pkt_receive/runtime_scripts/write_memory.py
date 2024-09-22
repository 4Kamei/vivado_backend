import serial
import time
import random
import sys
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

mif = sys.argv[1]

program_sequence = []

with open(mif, "r") as f:
    for line in f:
        line = line.replace("\n", "")
        addr = line[0:8]
        data = line[8:16]
        mask = line[16:24]

        if (mask == "00000000"):
            continue
        addr = int(addr, 2)
        data = int(data, 2)
        
        program_sequence.append((addr, data))

for addr, data in program_sequence:
    
    type = i2c_devices[0][0]
    id   = i2c_devices[0][1]
    
    write_packet([0x01, 0x04, type, id] + [0x71, addr] + [data], expect_response=0)
    
    print(f"Writing {addr}:{data}")

    #Writing 10 + 10 + 10 at 400kbps => ~can send instructions at 10k/s => delay of 0.1ms => sleep for 0.1 just to be safe
    time.sleep(0.001)

