TOPLEVEL = uart_packet_rx

TOPLEVEL_LANG = verilog
VERILOG_SOURCES = ${PROJ_ROOT}/design/sources/*.sv
MODULE = ${TOPLEVEL}
SIM = verilator
EXTRA_ARGS += "--trace"
EXTRA_ARGS += "--trace-structs"
WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim

