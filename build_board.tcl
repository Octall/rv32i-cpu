# =============================================================================
# build_board.tcl -- Vivado project for board_top (hardware bring-up) on Nexys 4
# =============================================================================
# Headless:  vivado -mode batch -source build_board.tcl
# GUI:       open Vivado Tcl console -> cd <riscv-core> ; source build_board.tcl
#
# Builds programs/prog.hex into the bitstream. Build that hex FIRST, e.g.:
#   bench/cc.sh -o prog bench/hello/hello.c          # known-good first light
#   bench/cc.sh -o prog bench/myprog/myprog.c        # your custom program
# =============================================================================

set root      [file dirname [file normalize [info script]]]
set proj_name board_nexys4
set proj_dir  $root/vivado
set part      xc7a100tcsg324-1     ;# Artix-7 XC7A100T on the Nexys 4

create_project $proj_name $proj_dir/$proj_name -part $part -force

# RTL (rtl/ has no testbenches). Exclude the old broken nexys4_top.
set rtl [glob $root/rtl/*.sv]
set rtl [lsearch -inline -all -not $rtl "*/nexys4_top.sv"]
add_files -fileset sources_1 $rtl
set_property file_type SystemVerilog [get_files *.sv]

# program image for the memories' $readmemh, baked into BRAM via the PROG_HEX define
add_files -fileset sources_1 $root/programs/prog.hex
set_property verilog_define "PROG_HEX=\"$root/programs/prog.hex\"" [current_fileset]

# pin constraints
add_files -fileset constrs_1 $root/constraints/board.xdc

set_property top board_top [current_fileset]
update_compile_order -fileset sources_1

puts "================================================================"
puts " Project ready:  part=$part  top=board_top"
puts " Build:  launch_runs impl_1 -to_step write_bitstream -jobs 4"
puts "         wait_on_run impl_1"
puts " Then:   Hardware Manager -> program the .bit, and on the host:"
puts "         picocom -b 115200 /dev/ttyUSB1   (or screen /dev/ttyUSB1 115200)"
puts "================================================================"

# Uncomment to build to a bitstream headlessly:
# launch_runs impl_1 -to_step write_bitstream -jobs 4
# wait_on_run impl_1
