# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl
GUI = 1
SCRIPT_FILE =

ifeq ($(SIM),ghdl)
	COMPILE_ARGS = --std=08
endif

SIM_ARGS = --wave=nco.ghw

SRC = ../src

VHDL_SOURCES += $(SRC)/nco.vhd \
				$(SRC)/sin_cos_lut.vhd

# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = nco

# MODULE is the basename of the Python test file
MODULE = nco_test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
