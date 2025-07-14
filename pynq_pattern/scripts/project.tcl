# project.tcl - Create PYNQ Pattern project for Ultra96V2

# Project settings
set project_dir "./project"
set project_name "pynq_pattern"
set part "xczu3eg-sbva484-1-i"

set scripts_dir   [file dirname [info script]]

create_project $project_name $project_dir -part $part -force

# Add Sources
add_files -fileset sources_1 [glob target/*.sv]
add_files -fileset sources_1 src/hdl/patgen_wrap.v
update_compile_order -fileset sources_1

# IP Registry
set repo_dir "../COMMON_IP"
set cur_repo   [get_property IP_REPO_PATHS [current_project]]
if {[lsearch -exact $cur_repo $repo_dir] < 0} {
    set_property IP_REPO_PATHS [concat $cur_repo $repo_dir] [current_project]
    puts "INFO: Added IP repo: $repo_dir"
} else {
    puts "INFO: IP repo already registered: $repo_dir"
}
update_ip_catalog

# Run Block Design script
set design_tcl [file join $scripts_dir "pynq_pattern.tcl"]

if {![file exists $design_tcl]} {
    puts "ERROR: can't find $design_tcl"
    exit 1
}

puts "INFO: source $design_tcl"
source $design_tcl

# Create HDL wrapper
validate_bd_design
generate_target {synthesis implementation} [get_files design_1.bd]

set wrapper_files [make_wrapper -files [get_files design_1.bd] -force]
add_files -norecurse $wrapper_files

# Set design_1_wrapper as Top
set_property top design_1_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

# Add constraints file
add_files -fileset constrs_1 [ glob src/constr/*.xdc ]

exit
