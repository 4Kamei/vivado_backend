TOPLEVEL = clock_counter_ad

TOPLEVEL_LANG = verilog
VERILOG_SOURCES = ${PROJ_ROOT}/design/sources/*.sv
VERILOG_SOURCES += ${PROJ_ROOT}/design/sources/**/*.sv
MODULE = ${TOPLEVEL}
SIM = verilator
EXTRA_ARGS += "--trace"
EXTRA_ARGS += "--trace-structs"
EXTRA_ARGS += --threads 16
EXTRA_ARGS += --coverage
WAVES = 1


VERILOG_INCLUDE_DIRS = ${PROJ_ROOT}/design/sources/axis_debug
include $(shell cocotb-config --makefiles)/Makefile.sim

