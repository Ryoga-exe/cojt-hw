# ----------------------------------------------------------------------------
# Clock Constraints
# ----------------------------------------------------------------------------
# Prevent the critical warning "Multiple clock definitions for FCLK_CLK0"
# that occurs during synthesis by adding the -add option
create_clock -period 8.000 -name ACLK -add [get_nets design_1_i/zynq_ultra_ps_e_0_pl_clk0]

# Restrict timing constraints between clocks other than ACLK
set_clock_groups -asynchronous -group [get_clocks ACLK]
