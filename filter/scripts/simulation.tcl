# simulation.tcl - Create PYNQ Filter simulation project

# --- Project settings ----------------------------------
set project_dir "./simulation"
set project_name "sim_filter"
set part "xczu3eg-sbva484-1-i"

set scripts_dir   [file dirname [info script]]

create_project $project_name $project_dir -part $part -force

# --- Add RTL Sources -----------------------------------
add_files -fileset sources_1 [glob target/filt_ip/hdl/*.sv]
add_files -fileset sources_1 target/filt_ip/hdl/filter.v
update_compile_order -fileset sources_1

# --- Add FIFO ------------------------------------------
import_ip target/filt_ip/src/fifo_32in32out_2048depth/fifo_32in32out_2048depth.xci
update_ip_catalog

# --- Run Block Design script ---------------------------
set design_tcl [file join $scripts_dir "sim_filter.tcl"]

if {![file exists $design_tcl]} {
    puts "ERROR: can't find $design_tcl"
    exit 1
}

puts "INFO: source $design_tcl"
source $design_tcl

# --- Create HDL wrapper (TOP) --------------------------
validate_bd_design
generate_target {synthesis implementation} [get_files design_1.bd]

set wrapper_files [make_wrapper -files [get_files design_1.bd] -top -force]
add_files -norecurse $wrapper_files

# Set design_1_wrapper as Top
set_property top design_1_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

# --- Add Simulation Sources -----------------------------------
add_files -fileset sim_1 [glob src/sim/tb/*.sv]
add_files -fileset sim_1 [glob src/sim/*raw]

update_compile_order -fileset sim_1

exit
