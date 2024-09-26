import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

@cocotb.test()
async def test_i2c_read_write(dut):
    
    clock = Clock(dut.i_usrclk2, 1000, "ps")
    cocotb.start_soon(clock.start())

    #log = logging.getLogger("cocotb.tb")
    #log.setLevel(logging.DEBUG)
    
    await RisingEdge(dut.i_usrclk2)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_usrclk2)
    dut.i_rst_n.value = 0
    await RisingEdge(dut.i_usrclk2)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_usrclk2)

    dut.i_startseq.value = 1
    for i in range(100):
        await RisingEdge(dut.i_usrclk2)

