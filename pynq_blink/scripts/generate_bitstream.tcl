# generate_bitstream.tcl

set argc_expected 0
set proj_xpr  "./project/pynq_blink.xpr"
set njobs     4
if {$argc >= 1} { set proj_xpr  [lindex $argv 0] }
if {$argc >= 2} { set njobs     [lindex $argv 1] }

puts "INFO: project     = $proj_xpr"
puts "INFO: parallelism = $njobs job(s)"

# Open project
if {![file exists $proj_xpr]} {
    puts "ERROR: Project file not found: $proj_xpr"
    exit 1
}
open_project $proj_xpr

# Run synthesis
if {[catch {get_runs synth_1}]} {
    puts "ERROR: synth_1 run not found"
    close_project
    exit 1
}
reset_run synth_1
launch_runs synth_1 -jobs $njobs
wait_on_run synth_1

# Run implementation up to bitstream generation
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $njobs
wait_on_run impl_1

set bit_file [glob -nocomplain \
    "*/*.runs/impl_1/*.bit"]
if {$bit_file != ""} {
    puts "INFO: Generated bitstream: $bit_file"
} else {
    puts "WARNING: Bitstream file not found (check run logs)"
}

close_project
exit
