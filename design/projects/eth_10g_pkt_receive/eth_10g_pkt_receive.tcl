#What do these do?
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

#set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
#set_property CONFIG_MODE SPIx4 [current_design]
#set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
#set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
#set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]

##200Mhz input clock
create_clock -period 5.000 [get_ports i_sys_clk_p]
set_property PACKAGE_PIN AE10 [get_ports i_sys_clk_p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports i_sys_clk_p]

#Reset
set_property PACKAGE_PIN AG27 [get_ports i_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports i_rst_n]

#Debug Header
set_property PACKAGE_PIN J28  [get_ports o_debug_left]
set_property IOSTANDARD  LVCMOS33 [get_ports o_debug_left]
set_property PACKAGE_PIN H29  [get_ports o_debug_right]
set_property IOSTANDARD  LVCMOS33 [get_ports o_debug_right]

#Leds
set led_pins {A22 C19 B19 E18}
for {set i 0} {$i < 4} {incr i} {
    set led_port [get_ports "o_eth_led[$i]"]
    set led_pin [lindex $led_pins $i]

    set_property PACKAGE_PIN $led_pin $led_port
    set_property IOSTANDARD LVCMOS33 $led_port
}

#Uart
set_property PACKAGE_PIN AJ26 [get_ports i_uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports i_uart_rx]

set_property PACKAGE_PIN AK26 [get_ports o_uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports o_uart_tx]

#SFP lane 1
set_property PACKAGE_PIN K6 [get_ports i_gtx_sfp1_rx_p]
set_property PACKAGE_PIN K5 [get_ports i_gtx_sfp1_rx_n]

set_property PACKAGE_PIN T28 [get_ports o_gtx_sfp1_tx_disable]
set_property IOSTANDARD LVCMOS33 [get_ports o_gtx_sfp1_tx_disable]

#Placement constraints


#Extra Configuration
if {0} {
    #Si5883P configuration. 4 Clocks provided. Driven by 50Mhz Reference
    #Slave Address: 1110000  7'h70. Transmitted MSB First 
    #I2C Wants LVCMOS25 as well, but only for pull down -> Can disable pull up behaviour in there somehow, maybe?
    #I2C Has tristate on both SCL and SDA
    #Clocking:
    #   0 => 0 on tristate buffer
    #   1 => Z on tristate buffer
    #Writing:
    #   0 => 0 on tristate
    #   1 => Z on tristate
    #Reading:
    #   1 on tristate => 1
    #   0 on tristate => 0
    PLL_SCL P23
    PLL_SDA N25 

    #Also connected

    CLK0_P F20      ;# BANK 11 
    CLK0_N E20      ;#   DDR3
    CLK1_P C8       ;# BANK 118
    CLK1_N C7       ;#  40G GTX
    CLK2_P G8       ;# BANK 117
    CLK2_N G7       ;#  10G GTX
    CLK3_P L8       ;# BANK 17
    CLK3_N L7       ;#   PCIe







}


