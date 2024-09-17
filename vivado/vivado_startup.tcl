#!/bin/env tcl

#Setup project constants

set PROJ_ROOT $env(PROJ_ROOT)
set PROJ_NAME "eth_10g_pkt_receive"
set SOURCES_DIR ${PROJ_ROOT}/design/sources/
set PROJ_SOURCES_DIR ${PROJ_ROOT}/design/projects/${PROJ_NAME}
set CONSTRAINTS_DIR ${PROJ_ROOT}/design/projects/${PROJ_NAME}/constraints
set TARGET_PART xc7k325tiffg900-2L						;# Speed Grade: 2, Temperature Class: Industrial
set REPORT_DIR "reports"

#Source the scripts
source ${PROJ_ROOT}/scripts/vivado.tcl

#FIXME make this pick up existing projects? or something? 
#Set if was 'gui' or not?
create_project -part $TARGET_PART -force -in_memory -verbose $PROJ_NAME .  

set_property target_language Verilog [current_project]

read_verilog [ rglob ${SOURCES_DIR} *.sv] -sv -verbose
read_verilog [ rglob ${PROJ_SOURCES_DIR} *.sv] -sv -verbose

#Constraints with '.tcl' are unmanaged and what we want, '.xdc' are managed by the tool
#allowing only a subset of tcl syntax. Hence use -unmanaged. This loads the main XDC
read_xdc $PROJ_SOURCES_DIR/${PROJ_NAME}.tcl -unmanaged -verbose

#We don't want to flatten the hierarchy at this point, so that we can set attributes with tcl scripts
synth_design -top $PROJ_NAME -part $TARGET_PART -flatten_hierarchy none

#These are specific timing constraints that we want to set on the synth'd but not yet flattened design. E.g. resyncs
foreach constraint_file [ rglob ${CONSTRAINTS_DIR} *.tcl ] {
    source $constraint_file
}

write_checkpoint -force ${REPORT_DIR}/post_synth.dcp
report_timing_summary -file ${REPORT_DIR}/post_synth_timing_summary.rpt
report_utilization -file ${REPORT_DIR}/post_synth_util.rpt

opt_design
place_design
report_clock_utilization -file ${REPORT_DIR}/clock_util.rpt

#get timing violations and run optimizations if needed
if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
 puts "Found setup timing violations => running physical optimization"
 phys_opt_design
}
write_checkpoint -force ${REPORT_DIR}/post_place.dcp
report_utilization -file ${REPORT_DIR}/post_place_util.rpt
report_timing_summary -file ${REPORT_DIR}/post_place_timing_summary.rpt



route_design -directive Explore
write_checkpoint -force ${REPORT_DIR}/post_route.dcp
report_route_status -file ${REPORT_DIR}/post_route_status.rpt
report_timing_summary -file ${REPORT_DIR}/post_route_timing_summary.rpt
report_power -file ${REPORT_DIR}/post_route_power.rpt
report_drc -file ${REPORT_DIR}/post_imp_drc.rpt
write_verilog -force ${REPORT_DIR}/cpu_impl_netlist.v -mode timesim -sdf_anno true
write_bitstream -force output.bit

puts "Finished"
