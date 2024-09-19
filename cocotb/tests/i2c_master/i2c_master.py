import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

from cocotbext.i2c import I2cMaster, I2cMemory

CLOCK_FREQUENCY = 20_000_000
BAUD_RATE = 100_000

@cocotb.test()
async def test_i2c_read(dut):
    
    clock_period = int(1_000_000 * 1_000_000/CLOCK_FREQUENCY)
    clock = Clock(dut.i_clk, clock_period, "ps")
    cocotb.start_soon(clock.start())

    #log = logging.getLogger("cocotb.tb")
    #log.setLevel(logging.DEBUG)
    
    i2c_memory = I2cMemory(sda=dut.o_sda, sda_o=dut.i_sda,
        scl=dut.o_scl, scl_o=dut.i_scl, addr=0x71, size=256)
    
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 0
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)

    dut.i_rw_address.value      = 0xaa;
    dut.i_slave_address.value   = 0x71;
    dut.i_read_enable.value     = 1;
    await RisingEdge(dut.i_clk)
    dut.i_rw_address.value      = 0;
    dut.i_slave_address.value   = 0; 
    dut.i_read_enable.value     = 0;

    await RisingEdge(dut.o_ready)

@cocotb.test()
async def test_i2c_read_write(dut):
    
    clock_period = int(1_000_000 * 1_000_000/CLOCK_FREQUENCY)
    clock = Clock(dut.i_clk, clock_period, "ps")
    cocotb.start_soon(clock.start())

    #log = logging.getLogger("cocotb.tb")
    #log.setLevel(logging.DEBUG)
    
    i2c_memory = I2cMemory(sda=dut.o_sda, sda_o=dut.i_sda,
        scl=dut.o_scl, scl_o=dut.i_scl, addr=0x71, size=256)
    
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 0
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)

    dut.i_rw_address.value      = 0xaa;
    dut.i_slave_address.value   = 0x71;
    dut.i_write_enable.value    = 1;
    dut.i_write_data.value      = 0xc3;
    await RisingEdge(dut.i_clk)
    dut.i_rw_address.value      = 0;
    dut.i_slave_address.value   = 0; 
    dut.i_write_enable.value    = 0;
    dut.i_write_data.value      = 0;

    await Timer(10, "us")
    await RisingEdge(dut.o_ready)
    dut.i_rw_address.value      = 0xaa;
    dut.i_slave_address.value   = 0x71;
    dut.i_read_enable.value     = 1;
    await RisingEdge(dut.i_clk)
    dut.i_rw_address.value      = 0;
    dut.i_slave_address.value   = 0; 
    dut.i_read_enable.value     = 0;

    await RisingEdge(dut.o_ready)


@cocotb.test()
async def test_i2c_write(dut):
    
    clock_period = int(1_000_000 * 1_000_000/CLOCK_FREQUENCY)
    clock = Clock(dut.i_clk, clock_period, "ps")
    cocotb.start_soon(clock.start())

    #log = logging.getLogger("cocotb.tb")
    #log.setLevel(logging.DEBUG)
    
    i2c_memory = I2cMemory(sda=dut.o_sda, sda_o=dut.i_sda,
        scl=dut.o_scl, scl_o=dut.i_scl, addr=0x71, size=256)
    
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 0
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)

    dut.i_rw_address.value      = 0xaa;
    dut.i_slave_address.value   = 0x71;
    dut.i_write_enable.value    = 1;
    dut.i_write_data.value      = 0xc3;
    await RisingEdge(dut.i_clk)
    dut.i_rw_address.value      = 0;
    dut.i_slave_address.value   = 0; 
    dut.i_write_enable.value    = 0;
    dut.i_write_data.value      = 0;

    await Timer(10, "us")
    await RisingEdge(dut.o_ready)
    dut.i_rw_address.value      = 0xab;
    dut.i_slave_address.value   = 0x71;
    dut.i_write_enable.value    = 1;
    dut.i_write_data.value      = 0xff;
    await RisingEdge(dut.i_clk)
    dut.i_rw_address.value      = 0;
    dut.i_slave_address.value   = 0; 
    dut.i_write_enable.value    = 0;
    dut.i_write_data.value      = 0;
        
    await RisingEdge(dut.o_ready)

    i2c_memory.mem.seek(0xaa)
    addr_aa_data = i2c_memory.mem.read(1)
    assert addr_aa_data == b'\xc3'

    i2c_memory.mem.seek(0xab)
    addr_ab_data = i2c_memory.mem.read(1)
    assert addr_ab_data == b'\xff'




    dut._log.info(i2c_memory.mem)
