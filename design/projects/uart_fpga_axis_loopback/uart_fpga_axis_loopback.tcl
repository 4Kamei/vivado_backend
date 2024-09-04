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
set_property IOSTANDARD LVCMOS25 [get_ports i_rst_n]

#Debug Header
set_property PACKAGE_PIN J28  [get_ports o_debug_left]
set_property IOSTANDARD  LVCMOS25 [get_ports o_debug_left]
set_property PACKAGE_PIN H29  [get_ports o_debug_right]
set_property IOSTANDARD  LVCMOS25 [get_ports o_debug_right]

#Leds
#set led_pins {A22 C19 B19 E18}
#for {set i 0} {$i < 4} {incr i} {
#    set led_port [get_ports "o_eth_led[$i]"]
#    set led_pin [lindex $led_pins $i]
#
#    set_property PACKAGE_PIN $led_pin $led_port
#    set_property IOSTANDARD LVCMOS15 $led_port
#}

#Uart
set_property PACKAGE_PIN AJ26 [get_ports i_uart_rx]
set_property IOSTANDARD LVCMOS25 [get_ports i_uart_rx]

set_property PACKAGE_PIN AK26 [get_ports o_uart_tx]
set_property IOSTANDARD LVCMOS25 [get_ports o_uart_tx]

