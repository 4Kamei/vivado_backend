import serial
import time

ser = serial.Serial(
        "/dev/ttyUSB0", 
        baudrate=115200, 
        bytesize=serial.EIGHTBITS, 
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE)

for k in range(256):
    k_out = k
    ba = bytearray.fromhex(hex(256 + k_out)[3:])
    ser.write(ba)
    ser.flush()
    binary = bin(256 + int.from_bytes(ser.read()))
    output_binary = tuple(map(int, binary[3:]))
    input_binary = tuple(map(int, bin(256 + k_out)[3:]))

    assert output_binary == input_binary, "{k} Doesn't match?"
