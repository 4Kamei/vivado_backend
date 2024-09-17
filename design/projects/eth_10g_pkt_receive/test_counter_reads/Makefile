TOPLEVEL = clock_counter_test

TOPLEVEL_LANG = verilog
VERILOG_SOURCES = ${PROJ_ROOT}/design/sources/*.sv
VERILOG_SOURCES += ${PROJ_ROOT}/design/projects/${TOPLEVEL}/*.sv
VERILOG_SOURCES += ${PROJ_ROOT}/design/primitives/*.sv
MODULE = ${TOPLEVEL}
SIM = verilator
EXTRA_ARGS += "--trace"
EXTRA_ARGS += "--trace-structs"
WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim

