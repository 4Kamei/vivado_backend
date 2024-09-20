import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

from cocotbext.axi import AxiStreamBus, AxiStreamMonitor, AxiStreamSink

from cocotb_bus.bus import Bus
import random

CLOCK_FREQUENCY_LOCAL = 200_000_000#1000000
CLOCK_FREQUENCY_EXTERN = 353_321_432#1000000

@cocotb.test()
async def test_with_no_clock(dut):
    local_clock_period = 2 * int(1_000_000 * 1_000_000 / (2 * CLOCK_FREQUENCY_LOCAL));
    clock_local = Clock(dut.i_clk_local, local_clock_period, "ps")
    cocotb.start_soon(clock_local.start())
    
    dut.i_clk_extern.value = 0;

    local_clock_frequency = 1_000_000 * 1_000_000 / local_clock_period

    await RisingEdge(dut.i_clk_local)
    dut.i_rst_n.value = 0
    await RisingEdge(dut.i_clk_local)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk_local)

    await Timer(100, "us")

    await RisingEdge(dut.i_clk_local)
    dut.i_latch_counters.value = 1
    await RisingEdge(dut.i_clk_local)
    dut.i_latch_counters.value = 0
    await RisingEdge(dut.i_clk_local)
    
    await RisingEdge(dut.o_counter_valid)
    await Timer(10, "ns")

    computed_clock_frequency = (local_clock_frequency * (float(dut.o_clk_extern_counter.value) / float(dut.o_clk_local_counter.value)))

    dut._log.info(f"Local  counter value {float(dut.o_clk_local_counter.value)}")
    dut._log.info(f"Extern counter value {float(dut.o_clk_extern_counter.value)}")

    dut._log.info(f"Computed clock frequency {computed_clock_frequency}")
    
    await Timer(100, "us")

    await RisingEdge(dut.i_clk_local)
    dut.i_latch_counters.value = 1
    await RisingEdge(dut.i_clk_local)
    dut.i_latch_counters.value = 0
    await RisingEdge(dut.i_clk_local)
    
    await RisingEdge(dut.o_counter_valid)
    await Timer(10, "ns")

    computed_clock_frequency = (local_clock_frequency * (float(dut.o_clk_extern_counter.value) / float(dut.o_clk_local_counter.value)))

    dut._log.info(f"Local  counter value {float(dut.o_clk_local_counter.value)}")
    dut._log.info(f"Extern counter value {float(dut.o_clk_extern_counter.value)}")

    dut._log.info(f"Computed clock frequency {computed_clock_frequency}")

@cocotb.test()
async def test_with_working_clock(dut):
    local_clock_period = 2 * int(1_000_000 * 1_000_000 / (2 * CLOCK_FREQUENCY_LOCAL));
    clock_local = Clock(dut.i_clk_local, local_clock_period, "ps")
    cocotb.start_soon(clock_local.start())
    
    extern_clock_period = 2 * int(1_000_000 * 1_000_000 / (2 * CLOCK_FREQUENCY_EXTERN));
    clock_extern = Clock(dut.i_clk_extern, extern_clock_period, "ps")
    cocotb.start_soon(clock_extern.start())
    
    local_clock_frequency = 1_000_000 * 1_000_000 / local_clock_period
    extern_clock_frequency = 1_000_000 * 1_000_000 / extern_clock_period

    await RisingEdge(dut.i_clk_local)
    dut.i_rst_n.value = 0
    await RisingEdge(dut.i_clk_local)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk_local)

    await Timer(100, "us")

    await RisingEdge(dut.i_clk_local)
    dut.i_latch_counters.value = 1
    await RisingEdge(dut.i_clk_local)
    dut.i_latch_counters.value = 0
    await RisingEdge(dut.i_clk_local)
    
    await RisingEdge(dut.o_counter_valid)
    await Timer(10, "ns")

    computed_clock_frequency = (local_clock_frequency * (float(dut.o_clk_extern_counter.value) / float(dut.o_clk_local_counter.value)))

    dut._log.info(f"Local  counter value {float(dut.o_clk_local_counter.value)}")
    dut._log.info(f"Extern counter value {float(dut.o_clk_extern_counter.value)}")

    dut._log.info(f"Actual clock frequency {extern_clock_frequency}")
    dut._log.info(f"Computed clock frequency {computed_clock_frequency}")


