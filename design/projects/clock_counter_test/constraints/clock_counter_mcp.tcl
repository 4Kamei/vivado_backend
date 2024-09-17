#Set a multicycle path on this. When this transfer happens, the source register isn't used
#This path is in the clock counter, when we save the contents of the external clock counter into the register clocked by the 'internal' clock

set from [get_pins clock_counter_ad_u/clock_counter_u/clk_counter_extern_reg*/C]
set to [get_pins clock_counter_ad_u/clock_counter_u/clk_extern_counter_local_q_reg*/D]

set_multicycle_path 3 -from $from -to $to -hold
set_multicycle_path 3 -from $from -to $to -setup

