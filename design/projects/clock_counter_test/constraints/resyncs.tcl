set resyncs [get_cells -hierarchical *resync*]
foreach resync $resyncs {
    set signal_pin [get_pins ${resync}/i_signal]
    set clk_pin [get_pins ${resync}/i_clk]
    
    #Now trace the signal pin to it's driver, and set a false path on that
    set timing_path [get_timing_path -through $signal_pin]
    set endpoint [get_property ENDPOINT_PIN $timing_path]
    set startpoint [get_property STARTPOINT_PIN $timing_path]
    
    set_false_path -from $startpoint -to $endpoint -setup -hold -rise -fall -reset_path
    set_property DONT_TOUCH true $resync

}

