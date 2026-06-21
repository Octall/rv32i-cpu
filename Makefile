# =============================================================================
# Makefile -- tiny simulation harness (Icarus Verilog + GTKWave)
# =============================================================================
# Compile all RTL plus one testbench, then run it.
#
#   make sim   TB=register_file    # compile + run the register_file testbench
#   make wave  TB=register_file    # open that testbench's waveform in GTKWave
#   make sim   TB=program_counter  # your first task
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

.PHONY: sim wave clean
sim: | $(BUILD)
	$(IVERILOG) $(IFLAGS) -o $(BUILD)/$(TB).vvp $(RTL_DIR)/*.sv $(TB_DIR)/$(TB)_tb.sv
	@echo "----------------------------------------"
	$(VVP) $(BUILD)/$(TB).vvp

wave:
	$(GTKWAVE) $(TB)_tb.vcd &

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD) *.vcd
