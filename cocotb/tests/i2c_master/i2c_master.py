import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

from cocotbext.i2c import I2cMaster, I2cMemory

CLOCK_FREQUENCY = 20_000_000
BAUD_RATE = 10000

@cocotb.test()
async def test_i2c_read_write(dut):
    
    clock_period = int(1_000_000 * 1_000_000/CLOCK_FREQUENCY)
    clock = Clock(dut.i_clk, clock_period, "ps")
    cocotb.start_soon(clock.start())

    #log = logging.getLogger("cocotb.tb")
    #log.setLevel(logging.DEBUG)

    
    i2c_master = I2cMaster(sda=dut.o_sda1, sda_o=dut.i_sda1,
        scl=dut.o_scl1, scl_o=dut.i_scl1, speed=400e3)

    i2c_memory = I2cMemory(sda=dut.o_sda2, sda_o=dut.i_sda2,
        scl=dut.o_scl2, scl_o=dut.i_scl2, addr=0x71, size=256)
    
    await i2c_master.write(0x71, b'\x00' + b'\xaa\xbb')

