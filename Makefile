# =============================================================================
# Makefile -- tiny simulation harness (Icarus Verilog + GTKWave)
# =============================================================================
# Compile all RTL plus one testbench, then run it.
#
#   make sim   TB=register_file    # compile + run the register_file testbench
#   make wave  TB=register_file    # open that testbench's waveform in GTKWave
#   make sim   TB=cpu_top          # the full-RV32I regression
#   make clean
#
# TB defaults to register_file if you don't pass one.
# =============================================================================

IVERILOG := iverilog
VVP      := vvp
GTKWAVE  := gtkwave
IFLAGS   := -g2012 -Wall

RTL_DIR  := rtl
TB_DIR   := tb
BUILD    := build

TB ?= register_file

# nexys4_top.sv is the original board demo, superseded by board_top.sv; it
# instantiates a debounce module that was never written, so it's excluded here
# (the same way tests/run.sh and tests/build.sh already exclude it).
RTL_SRCS := $(filter-out $(RTL_DIR)/nexys4_top.sv, $(wildcard $(RTL_DIR)/*.sv))

.PHONY: sim wave clean
sim: | $(BUILD)
	$(IVERILOG) $(IFLAGS) -o $(BUILD)/$(TB).vvp $(RTL_SRCS) $(TB_DIR)/$(TB)_tb.sv
	@echo "----------------------------------------"
	$(VVP) $(BUILD)/$(TB).vvp

wave:
	$(GTKWAVE) $(TB)_tb.vcd &

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD) *.vcd
