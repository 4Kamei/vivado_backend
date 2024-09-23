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

def write_packet(data):
    ser.write(bytearray([len(data)] + data))
    ser.flush()
    #Loopback packet
    read = ser.read()
    pkt_len = int.from_bytes(read)
    #print(f"Read length as {pkt_len} ({read})")
    pkt = []
    for _ in range(pkt_len):
        data = int.from_bytes(ser.read())
        pkt.append(data)
    #print(pkt)
    #response packet
    pkts = []
    while True:
        ser.timeout = 0.005
        read = ser.read()
        pkt_len = int.from_bytes(read)
        #print(f"Inner loop for packet receiving: length as {pkt_len} ({read})")
        if read == b'':
            return pkts
        pkt = []
        for _ in range(pkt_len):
            ser.timeout = 0.00
            read = ser.read()
            if not read:
                return pkts
            data = int.from_bytes(read)
            pkt.append(data)
        #print(pkt)
        pkts.append(pkt)

def translate_device(type):
    return {
        1: "Counter   ",
        2: "I2C Master",
    }[type]

#Identify packet
input_packets = write_packet([0x01, 0x00])

counters = []

for input_packet in input_packets:
    type = input_packet[2]
    id = input_packet[3]
    type_name = translate_device(type)
    print(f"Found device: ({type}) {type_name} with ID:{id}")
    if type != 0x01:
        continue
    counters.append((type, id))
    

for type, id in counters:

    #Write 1 to address 0
    write_packet([0x01, 0x04, type, id] + [0x00] + [0x00] * 7 + [0x01])

    #Write 1 to address 0
    local_counter_response = write_packet([0x01, 0x02, type, id] + [0x01])[0]
    #Write 1 to address 0
    extern_counter_response = write_packet([0x01, 0x02, type, id] + [0x02])[0]

    local_counter_value = local_counter_response[-7:]
    extern_counter_value = extern_counter_response[-7:]
    print(id, " Local counter value :", int.from_bytes(local_counter_value, byteorder="big"))
    print(id, " Extern counter value:", int.from_bytes(extern_counter_value, byteorder="big"))
    print(id, " Computed value: ", 200 * float(int.from_bytes(extern_counter_value, byteorder="big")) / float(int.from_bytes(local_counter_value, byteorder="big")))
