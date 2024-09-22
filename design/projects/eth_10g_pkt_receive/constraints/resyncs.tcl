
set dual_ff_resyncs [get_cells -hierarchical -filter ORIG_REF_NAME==dual_ff_resync]
foreach dual_ff_resync $dual_ff_resyncs {
    set signal_pin [get_pins ${dual_ff_resync}/i_signal]
    
    #Now trace the signal pin to it's driver, and set a false path on that
    set timing_path [get_timing_path -through $signal_pin]
    set endpoint [get_property ENDPOINT_PIN $timing_path]
    set startpoint [get_property STARTPOINT_PIN $timing_path]

    #The maximum time from 'start' to 'end' should be 1 ns -> Which means the registers will be close together
    set_max_delay 2 -from $startpoint -to $endpoint 

    #Likewise, the delay between the two registers of the resync should be low
    #FIXME
}

set handshake_data_resyncs [get_cells -hierarchical -filter ORIG_REF_NAME==handshake_data_resync]
foreach handshake_data_resync $handshake_data_resyncs {
    set i_data [get_pins ${handshake_data_resync}/i_data]
    
    #Now trace the signal pin to it's driver, and set a false path on that
    set timing_paths [get_timing_path -through $i_data -max_paths 10000]
    foreach timing_path $timing_paths {
        set endpoint [get_property ENDPOINT_PIN $timing_path]
        set startpoint [get_property STARTPOINT_PIN $timing_path]
        
        set_multicycle_path 2 -setup -from $startpoint -to $endpoint
        set_multicycle_path 2 -hold  -from $startpoint -to $endpoint
    }
}


