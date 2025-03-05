import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import random


class TB:

    def __init__(self, dut):
        clock = Clock(dut.i_clk, 1000, "ps")
        cocotb.start_soon(clock.start())
        self.dut = dut
        
    async def reset(self):
        await RisingEdge(self.dut.i_clk)
        self.dut.i_rst_n.value = 1
        await RisingEdge(self.dut.i_clk)
        self.dut.i_rst_n.value = 0
        await RisingEdge(self.dut.i_clk)
        self.dut.i_rst_n.value = 1



@cocotb.test()
async def can_receive_blocks_specific(dut):
    
    tb = TB(dut)
    await tb.reset()
    
    bits = ([1] + [0] * 7) + ([0] * 8 * 4)
    
    dut.i_bit_en.value = 0
    for bit in bits:
        dut.i_bit_en.value = 1
        dut.i_bit.value = bit
        await RisingEdge(dut.i_clk)

    dut.i_bit_en.value = 0

    for _ in range(10):
        await RisingEdge(dut.i_clk)
