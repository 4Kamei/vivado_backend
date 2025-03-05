from ether_util import l2_checksum
pkt  = bytearray([128, 0, 0, 0, 0])

def naive_remainder(packet):
    coeff = {32, 26, 23, 22, 16, 12, 11, 10, 8, 7, 5, 4, 2, 1, 0}
    polynomial = 0
    for c in coeff:
        polynomial += 1 << c

    packet_i = int.from_bytes(packet)

    packet_i = packet_i << 32
    left_shift_up = len(packet) * 8 - 1
    polynomial = polynomial << left_shift_up

    shift_num = left_shift_up + 32

    while packet_i & 1 == 0:
        if packet_i >> shift_num == 1:
            packet_i = polynomial ^ packet_i
        shift_num -= 1
        polynomial = polynomial >> 1
        #print("STATE ", bin(2 ** (left_shift_up + 35) + packet_i)[3:].replace("0", " "), "\t\t", hex(packet_i))
        #print("POLY  ", bin(2 ** (left_shift_up + 35) + polynomial)[3:].replace("0", " "), "\t\t", hex(polynomial))
        #print(hex(packet_i + (1 << (left_shift_up + 33)))[3:])
        #print(hex(polynomial + (1 << (left_shift_up + 33)))[3:])
    
    return hex(packet_i)

def consume_bit(state, bit, polynomial):
    i_state = (state << 1 | bit)
    
    if i_state >> 32 == 1:
        i_state = i_state ^ polynomial
    i_state = i_state & (2 ** 32 - 1)
    #print("STATE ", bin(2 ** 33 + i_state)[3:].replace("0", " "), "\t\t", hex(2 ** 33 + i_state)[3:])
    #print("POLY   ", bin(2 ** 32 + polynomial)[3:].replace("0", " "), "\t\t", hex(2 ** 32 + polynomial)[3:])
    return i_state

def lfsr_remainder(packet):

    poly_taps = [32, 26, 23, 22, 16, 12, 11, 10, 8, 7, 5, 4, 2, 1, 0]

    reverse = False

    tap_list = sorted(poly_taps, reverse=True)[1:]
    
    if reverse:
        tap_list = [31 - t for t in tap_list]

    polynomial = 0
    for tap in tap_list:
        polynomial |= 1 << tap

    packet = packet #+ bytearray([112, 149, 214, 101])

    packet_i = int.from_bytes(packet)
    state = 0
    packet_i_br = int(bin(packet_i)[2:][::-1], 2)

    for i in range((len(packet)) * 8 + 40):
        #print(i, packet_i_br >> i & 1)
        state = consume_bit(state, packet_i_br >> i & 1, polynomial)
    
    state_br = int(bin(state)[2:][::-1], 2)

    #print(list(state.to_bytes(4)))

    return hex(state)

print(naive_remainder(pkt))
print(lfsr_remainder(pkt))

