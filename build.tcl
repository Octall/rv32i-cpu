# =============================================================================
# build.tcl -- create the Vivado project for the RISC-V core on the Nexys 4
# =============================================================================
# Run from Vivado:
#   GUI Tcl console:   cd <path>/riscv-core ; source build.tcl
#   Headless:          vivado -mode batch -source build.tcl
#
# Creates project under ./vivado/riscv_nexys4 targeting the Artix-7 on the
# Nexys 4. Adds the RTL (not the testbenches), the program image, and the
# pin constraints, and sets nexys4_top as the synthesis top.
# =============================================================================

set root      [file dirname [file normalize [info script]]]
set proj_name riscv_nexys4
set proj_dir  $root/vivado
set part      xc7a100tcsg324-1     ;# Artix-7 XC7A100T on the Nexys 4

create_project $proj_name $proj_dir/$proj_name -part $part -force

# --- design sources: all RTL modules (rtl/ holds no testbenches) ---
add_files -fileset sources_1 [glob $root/rtl/*.sv]
set_property file_type SystemVerilog [get_files *.sv]

# --- program image for instr_memory's $readmemh ---
add_files -fileset sources_1 $root/programs/cpu_prog.hex

# --- pin constraints (just ours -- NOT the all-commented master) ---
add_files -fileset constrs_1 $root/constraints/nexys4.xdc

# --- synthesis top ---
set_property top nexys4_top [current_fileset]
update_compile_order -fileset sources_1

puts "================================================================"
puts " Project ready:  part=$part  top=nexys4_top"
puts " Build it with:  launch_runs impl_1 -to_step write_bitstream"
puts "                 wait_on_run impl_1"
puts " Then: Open Hardware Manager -> program the .bit"
puts "================================================================"

# Uncomment to build all the way to a bitstream from this script:
# launch_runs impl_1 -to_step write_bitstream -jobs 4
# wait_on_run impl_1
