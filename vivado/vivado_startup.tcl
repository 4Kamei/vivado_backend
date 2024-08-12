#!/bin/env tcl

#Setup project constants

set PROJ_ROOT $env(PROJ_ROOT)
set PROJ_NAME "uart_fpga_loopback"
set CONSTRAINTS_DIR ${PROJ_ROOT}/design/projects/
set SOURCES_DIR ${PROJ_ROOT}/design/sources/
set TARGET_PART xc7k325tffg900-1


#Source the scripts
source ${PROJ_ROOT}/scripts/vivado.tcl

#FIXME make this pick up existing projects? or something? 
#Set if was 'gui' or not?
create_project -part $TARGET_PART -force -in_memory -verbose $PROJ_NAME .  

set_property target_language Verilog [current_project]

read_verilog [ rglob ${PROJ_ROOT}/design/sources *.sv] -sv -verbose
read_verilog [ rglob ${PROJ_ROOT}/design/projects/ *.sv] -sv -verbose
read_xdc [ rglob ${CONSTRAINTS_DIR} *.xdc ] -verbose


synth_design -top $PROJ_NAME -part $TARGET_PART

write_checkpoint -force /post_synth.dcp
report_timing_summary -file $outputDir/post_synth_timing_summary.rpt
report_utilization -file $outputDir/post_synth_util.rpt


opt_design
place_design
report_clock_utilization -file $outputDir/clock_util.rpt

return

#get timing violations and run optimizations if needed
if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
 puts "Found setup timing violations => running physical optimization"
 phys_opt_design
}
write_checkpoint -force $outputDir/post_place.dcp
report_utilization -file $outputDir/post_place_util.rpt
report_timing_summary -file $outputDir/post_place_timing_summary.rpt




route_design -directive Explore
write_checkpoint -force $outputDir/post_route.dcp
report_route_status -file $outputDir/post_route_status.rpt
report_timing_summary -file $outputDir/post_route_timing_summary.rpt
report_power -file $outputDir/post_route_power.rpt
report_drc -file $outputDir/post_imp_drc.rpt
write_verilog -force $outputDir/cpu_impl_netlist.v -mode timesim -sdf_anno true
write_bitstream -force $outputDir/nameOfBitstream.bit

return

   104 connect_hw_server -url localhost:3121
   105 current_hw_target
   106 open_hw_target
   107 get_hw_devices
   108 set_property PROGRAM.FILE output.bit [lindex [ get_hw_devices] 0]
   109 program_hw_devices [lindex [get_hw_devices ] 0]




