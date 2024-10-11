from queue import Queue

def bus_by_regex(dut, regex, as_cocotb_bus=False):
    sigs = dir(dut)
    import re
    bus = {}
    for item in sigs:
        m = re.match(regex, item)
        if m != None:
            s = m.groups()[0]
            if s in bus:
                raise Exception(f"match {s}, ({item}) already in bus: {s}")
            if as_cocotb_bus:
                bus[s] = str(item)
            else:
                bus[s] = getattr(dut, item)
    if len(bus) == 0:
        raise Exception(f"Regex {regex} did not match any signals in dut {dut}")
    if as_cocotb_bus:
        from cocotb_bus.bus import Bus
        bus = Bus(dut, "", bus, bus_separator="")
        bus._optional_signals = [] #For Alex Forenchich's cocotbext.axt
        return bus
    else:
        return bus

class DataQueue():
    def __init__(self):
        self._size = 0
        self.queue = Queue()

    def size(self):
        return self._size

    def get(self, n):
        assert n <= self._size, "Tried to get more elements from queue than allowed"
        self._size -= n
        out = [self.queue.get() for _ in range(n)]
        assert len(out) == n, f"Length of returned array is not n. ({len(out)} != {n})"
        return out

    def get_or_default(self, n, default):
        if n > self._size:
            rem = n - self._size
            out = self.get(self._size)
            out += [default] * rem
        else:
            out = self.get(n)
        assert len(out) == n, f"Length of returned array is not n. ({len(out)} != {n})"
        return out

    def put(self, data):
        self._size += 1
        self.queue.put(data)

class FixedWidth():
    def __init__(self, val, width, reverse=False):
        self.val = val
        self.width = width
        self.reverse = reverse
        assert self.val & (2 ** self.width - 1) == self.val, f"Value provided {val} has width greater than {width}"

    def convert(self):
        representation = list(map(int, bin(2 ** self.width + self.val)[3:]))

        if not self.reverse:
            return representation
        else:
            return representation[::-1]

from cocotb_util import ether_block_writer
from cocotb_util import gtx_interface 
from cocotb_util import eth_stream
