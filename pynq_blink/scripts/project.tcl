# project.tcl - Create PYNQ Blink project for Ultra96V2

# Project settings
set project_dir "./project"
set project_name "pynq_blink"
set part "xczu3eg-sbva484-1-i"

set scripts_dir   [file dirname [info script]]

create_project $project_name $project_dir -part $part -force

# Run Tcl script
set design_tcl [file join $scripts_dir "pynq_blink.tcl"]

if {![file exists $design_tcl]} {
    puts "ERROR: can't find $design_tcl"
    exit 1
}

puts "INFO: source $design_tcl"
source $design_tcl

# Create HDL wrapper
validate_bd_design
generate_target {synthesis implementation} [get_files design_1.bd]

set wrapper_files [make_wrapper -files [get_files design_1.bd] -top -force]

add_files -norecurse $wrapper_files
update_compile_order -fileset sources_1

# Add constraints file
add_files -fileset constrs_1 [ glob src/constr/*.xdc ]

exit
