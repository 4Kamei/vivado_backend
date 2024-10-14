TOPLEVEL = eth_10g_pkt_receive

TOPLEVEL_LANG = verilog
VERILOG_SOURCES = ${PROJ_ROOT}/design/sources/*.sv
VERILOG_SOURCES += ${PROJ_ROOT}/design/sources/*/*.sv
VERILOG_SOURCES += ${PROJ_ROOT}/design/projects/${TOPLEVEL}/*.sv
VERILOG_SOURCES += ${PROJ_ROOT}/design/primitives/*.sv
MODULE = test_i2c_programming

SIM = verilator
EXTRA_ARGS += "--trace"
EXTRA_ARGS += "--trace-structs"
WAVES = 1

VERILOG_INCLUDE_DIRS = ${PROJ_ROOT}/design/sources/axis_debug
VERILOG_INCLUDE_DIRS += ${PROJ_ROOT}/design/projects/${TOPLEVEL}

include $(shell cocotb-config --makefiles)/Makefile.sim

