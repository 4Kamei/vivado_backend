TOPLEVEL = axis_sync_fifo

TOPLEVEL_LANG = verilog
VERILOG_SOURCES = ${PROJ_ROOT}/design/sources/*.sv
MODULE = ${TOPLEVEL}
SIM = verilator
EXTRA_ARGS += "--trace"
EXTRA_ARGS += "--trace-structs"
EXTRA_ARGS += --threads 16
EXTRA_ARGS += --coverage
WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim

