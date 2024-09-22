#Set a multicycle path on this. When this transfer happens, the source register isn't used
#This path is in the clock counter, when we save the contents of the external clock counter into the register clocked by the 'internal' clock

#Each constraints script either sets constraints at the start of the flow, or is sourced again and
set CONS_MODE SET

if {$CONS_MODE == "SET"} {
    set from [get_pins clock_counter_ad_ref_u/clock_counter_u/clk_counter_extern_reg*/C]
    set to [get_pins clock_counter_ad_ref_u/clock_counter_u/clk_extern_counter_local_q_reg*/D]

 #   set_false_path -from $from -to $to -hold
 #   set_false_path -from $from -to $to -setup

    set from [get_pins clock_counter_ad_rx_u/clock_counter_u/clk_counter_extern_reg*/C]
    set to [get_pins clock_counter_ad_rx_u/clock_counter_u/clk_extern_counter_local_q_reg*/D]

#    set_false_path -from $from -to $to -hold
#    set_false_path -from $from -to $to -setup
}

if {$CONS_MODE == "TEST"} {
    #Need to make sure that the handshake is shorter than the delay on these paths     
}
