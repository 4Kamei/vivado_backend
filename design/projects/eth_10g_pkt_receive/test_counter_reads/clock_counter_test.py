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
        
        
        #Write identify
        data = [0x01, 0x00]
        await uart_source.write(bytearray([len(data)] + data))

        in_data = []
        in_data_len = int.from_bytes(await uart_sink.read(1))
        for _ in range(in_data_len):
            in_data.append(int.from_bytes(await uart_sink.read(1)))

        dut._log.info(in_data)
        
        
        in_data = []
        in_data_len = int.from_bytes(await uart_sink.read(1))
        for _ in range(in_data_len):
            in_data.append(int.from_bytes(await uart_sink.read(1)))

        dut._log.info(in_data)

        dev_type = in_data[2]    
        dev_id   = in_data[3]    

        #Write to 0x00 to latch the counter        
        data = [0x01, 0x04, dev_type, dev_id, 0x00] + [0x00] * 7 + [0x01]
        await uart_source.write(bytearray([len(data)] + data))
        
        in_data = []
        in_data_len = int.from_bytes(await uart_sink.read(1))
        for _ in range(in_data_len):
            in_data.append(int.from_bytes(await uart_sink.read(1)))

        dut._log.info(in_data)
         
        #Read from to 0x01 to read the local counter        
        data = [0x01, 0x02, dev_type, dev_id, 0x01]
        await uart_source.write(bytearray([len(data)] + data))
        
        in_data = []
        in_data_len = int.from_bytes(await uart_sink.read(1))
        for _ in range(in_data_len):
            in_data.append(int.from_bytes(await uart_sink.read(1)))

        dut._log.info(in_data)
        
        in_data = []
        in_data_len = int.from_bytes(await uart_sink.read(1))
        for _ in range(in_data_len):
            in_data.append(int.from_bytes(await uart_sink.read(1)))

        dut._log.info(in_data)
         
        #Read from to 0x01 to read the extern counter        
        data = [0x01, 0x02, dev_type, dev_id, 0x02]
        await uart_source.write(bytearray([len(data)] + data))
        
        in_data = []
        in_data_len = int.from_bytes(await uart_sink.read(1))
        for _ in range(in_data_len):
            in_data.append(int.from_bytes(await uart_sink.read(1)))

        dut._log.info(in_data)
        
        in_data = []
        in_data_len = int.from_bytes(await uart_sink.read(1))
        for _ in range(in_data_len):
            in_data.append(int.from_bytes(await uart_sink.read(1)))

        dut._log.info(in_data)
