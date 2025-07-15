# project.tcl - Create PYNQ Display project for Ultra96V2

# --- Project settings ----------------------------------
set project_dir "./project"
set project_name "pynq_display"
set part "xczu3eg-sbva484-1-i"

set scripts_dir   [file dirname [info script]]

create_project $project_name $project_dir -part $part -force

# --- IP Registry ---------------------------------------
set repo_list [list \
    [file normalize "../COMMON_IP"] \
    [file normalize "target/display_ip"] \
]
set cur_repo [get_property IP_REPO_PATHS [current_project]]

foreach path $repo_list {
    if {![file isdirectory $path]} {
        puts "WARNING: IP repo not found: $path"
        continue
    }
    if {[lsearch -exact $cur_repo $path] < 0} {
        lappend cur_repo $path
        puts "INFO: Added IP repo: $path"
    } else {
        puts "INFO: IP repo already registered: $path"
    }
}

set_property IP_REPO_PATHS $cur_repo [current_project]
update_ip_catalog

# --- Run Block Design script ---------------------------
set design_tcl [file join $scripts_dir "pynq_display.tcl"]

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
update_compile_order -fileset sources_1

# --- Add constraints file ------------------------------
add_files -fileset constrs_1 [ glob src/constr/*.xdc ]

exit
