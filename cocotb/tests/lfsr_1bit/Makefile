TOPLEVEL = lfsr_1bit

TOPLEVEL_LANG = verilog
VERILOG_SOURCES = lfsr_1bit.sv
MODULE = ${TOPLEVEL}
SIM = verilator
EXTRA_ARGS += "--trace"
EXTRA_ARGS += "--trace-structs"
WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim

