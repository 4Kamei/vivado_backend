import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
import random

def get_header(alignment):
    data = [0, 1] + [random.randint(0, 1) for _ in range(64)]
    data = data + data
    #This is abhorrent
    return int("".join(map(str, data[alignment:alignment+1])), 2)

@cocotb.test()
async def test_finds_block_lock(dut):
    
    clock = Clock(dut.i_clk, 1000, "ps")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 0
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)

    #max_clocks to find block
    max_clocks = 64 * 64 * 10
    alignment = 2
    found_block_lock = False

    current_clock = 0
    while current_clock < max_clocks:
        current_clock += 1
        await RisingEdge(dut.i_clk)
        if random.randint(0, 1) == 0:
            dut.i_header_valid.value = 0
            dut.i_header = 0
        else:
            dut.i_header_valid.value = 1
            dut.i_header = get_header(alignment)
            if dut.o_rxslip.value == 1:
                dut._log.info(f"Found slip at alignment {alignment}")
                alignment += 1
                alignment = (alignment % 66)
            if dut.o_block_lock.value == 1:
                found_block_lock = True
                break

    if found_block_lock:
        dut._log.info(f"Found block lock with alignment {alignment}")
        dut._log.info(f"Header: {hex(dut.i_header.value)}")
    else:
        assert False, f"Could not find block lock in {max_clocks} cycles"
