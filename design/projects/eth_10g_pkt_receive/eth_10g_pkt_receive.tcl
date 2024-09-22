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

##CLK 0
#create_clock -period 3.000 [get_ports i_ddr_clk_p]
#set_property PACKAGE_PIN F20 [get_ports i_ddr_clk_p]

#CLK 1
create_clock -period 3.000 [get_ports i_gtx_qsfp_clk_p]
set_property PACKAGE_PIN C8 [get_ports i_gtx_qsfp_clk_p]

#CLK 2
create_clock -period 3.000 [get_ports i_gtx_clk_p]
set_property PACKAGE_PIN G8 [get_ports i_gtx_clk_p]

#CLK 3
create_clock -period 3.000 [get_ports i_pcie_clk_p]
set_property PACKAGE_PIN L8 [get_ports i_pcie_clk_p]

#The two clocks above come from different sources, these are the only clocks we have so
#set both as async to anything else
set_clock_groups -group [get_clocks i_sys_clk_p] -asynchronous
set_clock_groups -group [get_clocks i_pcie_clk_p] -asynchronous
set_clock_groups -group [get_clocks i_gtx_qsfp_clk_p] -asynchronous
set_clock_groups -group [get_clocks i_gtx_clk_p] -asynchronous

#Reset
set_property PACKAGE_PIN AG27 [get_ports i_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports i_rst_n]

#Debug Header
set debug_header_pins {L27 J28 H29 K29}
#------------------------
#
#   L27  J28  H29     K29
#--------        --------


for {set i 0} {$i < [llength $debug_header_pins]} {incr i} {
    set dbg_pin [lindex $debug_header_pins $i] 
    set_property PACKAGE_PIN $dbg_pin [get_ports o_debug[$i]]
    set_property IOSTANDARD  LVCMOS33 [get_ports o_debug[$i]]
}

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

set_property PACKAGE_PIN K2 [get_ports o_gtx_sfp1_tx_p]
set_property PACKAGE_PIN K1 [get_ports o_gtx_sfp1_tx_n]

set_property PACKAGE_PIN T28 [get_ports o_gtx_sfp1_tx_disable]
set_property IOSTANDARD LVCMOS33 [get_ports o_gtx_sfp1_tx_disable]

set_property PACKAGE_PIN R28 [get_ports i_gtx_sfp1_loss]
set_property IOSTANDARD LVCMOS33 [get_ports i_gtx_sfp1_loss]

#SI5338 configuration
set_property PACKAGE_PIN P23 [get_ports b_scl]
set_property IOSTANDARD LVCMOS33 [get_ports b_scl]

set_property PACKAGE_PIN N25 [get_ports b_sda]
set_property IOSTANDARD LVCMOS33 [get_ports b_sda]

#Extra Configuration
if {0} {
    CLK0_P F20      ;# BANK 11 
    CLK0_N E20      ;#   DDR3
    CLK1_P C8       ;# BANK 118
    CLK1_N C7       ;#  40G GTX
    CLK2_P G8       ;# BANK 117
    CLK2_N G7       ;#  10G GTX
    CLK3_P L8       ;# BANK 17
    CLK3_N L7       ;#   PCIe
}


