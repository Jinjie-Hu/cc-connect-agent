#/**************************************************/
#/* Compile Script for Synopsys                    */
#/*                                                */
#/* dc_shell-t -f compile_dc.tcl                   */
#/*                                                */
#/* OSU FreePDK 28nm                               */
#/**************************************************/

# -------------- DC setting --------------
puts "----------------------------------- Init DC setting"

# constant logic propagation
set_app_var case_analysis_with_logic_constants true
# verilogout setting
set_app_var verilogout_show_unconnected_pins "true"
set_app_var verilogout_higher_designs_first true
set_app_var verilogout_no_tri true
set_app_var hdlin_enable_upf_compatible_naming true
# mux setting
#set_app_var compile_prefer_mux true
# low power setting 
set_app_var power_low_power_placement true
#set_leakage_power_model -type channel_width -mvth_weights {c30 = 1 c40 = 3}
# drc check setting
set_app_var compile_final_drc_fix all
# pin-density management to avoid high congestion
#set_app_var compile_high_pin_density_cell_optimization true
#set_app_var compile_high_pin_density_cell_optimization_utilization_threshold 0.4
#set_app_var compile_high_pin_density_cell_spreading true
#set_app_var compile_high_pin_density_cell_spreading_threshold 0.5
# placer setting
set_app_var placer_max_cell_density_threshold 0.58
#set_app_var placer_tns_driven true
#set_app_var placer_tns_driven_in_incremental_compile true
# congestion setting
#set_app_var spg_congestion_placement_in_incremental_compile true
set_congestion_options -max_util 0.9
# unexpected latch check
set_app_var hdlin_check_no_latch true
# clock gate setting
set_app_var power_cg_reconfig_stages true
set_clock_gating_style \
    -sequential_cell latch \
    -max_fanout $max_fanout \
    -minimum_bitwidth 6 \
    -num_stages 2
#   -positive_edge_logic integrated \
#   -negative_edge_logic integrated \
set_app_var power_cg_iscgs_enable true
set_app_var power_cg_physically_aware_cg true
set_app_var compile_clock_gating_through_hierarchy true

# ------------- DRC ----------------
set_max_fanout          $max_fanout  [current_design]
set_max_transition      0.30 [current_design]
set_max_transition      0.07 [all_outputs]
if {$my_clock_pin != "vclk"} {
    set_clock_transition    0.18 [all_clocks];
}
set_load                0.05 [all_outputs]

# ------------ Compile -----------------
puts "----------------------------------- Compile_ultra round 1"
compile_ultra -no_autoungroup -gate_clock -spg -retime
report_compile_options  > ${log_prefix}.cmp_1_options

if [shell_is_in_topographical_mode] {report_congestion > ${rpt_prefix}.pre_congestion}

change_names -rules verilog -hierarchy
report_constraint -all_violators -verbose -significant_digits 3 > ${rpt_dir}/${my_toplevel}.const_tmp
write_file -hier -o ${out_dir}/${my_toplevel}_tmp.ddc

puts "----------------------------------- Compile_ultra round 2"
compile_ultra -incr -no_autoungroup -spg -retime
report_compile_options  > ${log_prefix}.cmp_2_options

# uniquify module name
set_app_var uniquify_naming_style "${my_toplevel}_%s_%d"
uniquify -force
