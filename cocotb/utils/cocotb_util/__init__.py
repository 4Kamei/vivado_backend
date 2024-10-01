from queue import Queue

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
