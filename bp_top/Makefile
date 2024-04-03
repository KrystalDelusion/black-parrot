
ifeq ($(BP_TOP),)
$(error Missing location for black-parrot source, please assign 'BP_TOP')
endif

export BP_COMMON_DIR    := $(BP_TOP)/bp_common
export BP_FE_DIR        := $(BP_TOP)/bp_fe
export BP_BE_DIR        := $(BP_TOP)/bp_be
export BP_ME_DIR        := $(BP_TOP)/bp_me
export BP_TOP_DIR       := $(BP_TOP)/bp_top
export BP_EXTERNAL_DIR  := $(BP_TOP)/external
export BASEJUMP_STL_DIR := $(BP_EXTERNAL_DIR)/basejump_stl
export HARDFLOAT_DIR    := $(BP_EXTERNAL_DIR)/HardFloat

# Needs liberty format timing files for techmap, from e.g.
# https://github.com/efabless/skywater-pdk-libs-sky130_fd_sc_hd
# PDK_ROOT should be set to git directory, or TIMING_LIB can be set to lib file
# directly.
ifneq ($(PDK_ROOT),)
MODEL             ?= sky130_fd_sc_hd__ff_100C_1v65
export TIMING_LIB ?= $(PDK_ROOT)/timing/$(MODEL).lib
endif

ifeq ($(TIMING_LIB),)
$(error Missing timing lib, please assign 'PDK_ROOT' or 'TIMING_LIB')
endif

export FLIST           ?= flist.vcs
export WRAPPER_SYNTH   ?= synth.v

.PHONY: tabby
tabby:
	yosys -c bp_top.tcl -l bp_top.log
