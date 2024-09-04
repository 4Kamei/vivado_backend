import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
import random

from cocotbext.uart import UartSource, UartSink

CLOCK_FREQUENCY = 200_000_000#1000000
BAUD_RATE = 115200#_12000

@cocotb.test()
async def test_uart_receive_comprehensive(dut):
        random.seed(432)

        clock_period = int(1000_000 * 1_000_000/CLOCK_FREQUENCY)
        clock = Clock(dut.i_sys_clk_p, clock_period, "ps")
        cocotb.fork(clock.start())
        
        await RisingEdge(dut.i_sys_clk_p)
        dut.i_rst_n.value = 0
        
        await RisingEdge(dut.i_sys_clk_p)
            

        uart_source = UartSource(dut.i_uart_rx, baud=BAUD_RATE, bits=8)
        uart_sink   = UartSink(dut.o_uart_tx, baud=BAUD_RATE, bits=8)

        dut.i_rst_n.value = 1
        for _ in range(20):
            await RisingEdge(dut.i_sys_clk_p)
        
        data = [random.randint(0, 255) for _ in range(15)]
        
        dut._log.info(len(data))
            
        await uart_source.write(bytearray([len(data)] + data))
        in_data = []
        in_data_len = int.from_bytes(await uart_sink.read(1))
        for _ in range(in_data_len):
            in_data.append(int.from_bytes(await uart_sink.read(1)))

        assert in_data == data
