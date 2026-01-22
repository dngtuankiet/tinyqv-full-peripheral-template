# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src

# MODULE is the basename of the Python test file
MODULE = test
ifeq ($(MODULE),test)
PROJECT_SOURCES = peripheral.v
else ifeq ($(MODULE),test_upt)
PROJECT_SOURCES = peripheral_upt.v
endif

# PROJECT_SOURCES = peripheral.v
ADDITIONAL_SOURCES = tt_wrapper.v test_harness/*.sv

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl

# Add TRNG sources
TRNG_SOURCES = user_peripherals/trng/dual_trng.v \
			   user_peripherals/trng/entropy_cell.v \
			   user_peripherals/trng/rg_base_long.v \
			   user_peripherals/trng/rg_base_short.v

UPT_SOURCES = user_peripherals/upt/upt.v \
			  user_peripherals/upt/rg_base_extra_long.v 

VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(ADDITIONAL_SOURCES))
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(TRNG_SOURCES))
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(UPT_SOURCES))

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb



# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
