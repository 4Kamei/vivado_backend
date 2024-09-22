#Clock constraints
set clk_out_pins [get_pins gtx_lane*/*/*OUTCLK]


set DATAPATH_WIDTH 64
set frequency_mhz [expr 10000.0 * 66 / 64 / $DATAPATH_WIDTH]
set period [expr 1000 / $frequency_mhz]
set period_floor [expr int(1000 * $period)/1000.0]

foreach clk_pin $clk_out_pins {
    create_clock -period $period_floor $clk_pin
    set_clock_groups -asynchronous -group [list $clk_pin]
}

