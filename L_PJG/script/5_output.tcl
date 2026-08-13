#/**************************************************/
#/* Compile Script for Synopsys                    */
#/*                                                */
#/* dc_shell-t -f compile_dc.tcl                   */
#/*                                                */
#/* OSU FreePDK 28nm                               */
#/**************************************************/

puts "----------------------------------- Output"

change_names -rule verilog -hier

write -f verilog -hier -output ${out_dir}/${my_toplevel}.gv
write -f ddc  -hier -output ${out_dir}/${my_toplevel}.ddc
write_sdc ${out_dir}/${my_toplevel}.sdc
saif_map -type ptpx -write_map "${out_dir}/${my_toplevel}.namemap"

#set filename [format "%s%s"  $my_toplevel ".db"]
#write -f db -hier -output $filename -xg_force_db

check_design > ${log_prefix}.post_chk_design
check_timing > ${log_prefix}.post_chk_timing
redirect ${rpt_prefix}.const {report_constraint -all_violators -verbose -significant_digits 3}
redirect ${rpt_prefix}.max_const {report_constraint -max_delay -significant_digits 3}
redirect ${rpt_prefix}.rpt_latch {all_register -level_sensitive}
redirect ${rpt_prefix}.timing_max { report_timing -transition -capacitance -attributes -delay max -max_paths 1000 -significant_digits 3}
redirect ${rpt_prefix}.timing_min { report_timing -transition -capacitance -attributes -delay min -max_paths 1000 -significant_digits 3}
redirect ${rpt_prefix}.timing_loop { report_timing -loop -max_paths 10}
redirect ${rpt_prefix}.cell { report_cell -nosplit}
redirect ${rpt_prefix}.modulearea {report_area -hierarchy}
redirect ${rpt_prefix}.logic_path {analyze_datapath}
redirect ${rpt_prefix}.area {report_area -designware}
redirect ${rpt_prefix}.high_fanout {report_net_fanout -threshold $max_fanout -verbose}
redirect ${rpt_prefix}.units {report_units }
redirect ${rpt_prefix}.power { report_power -hierarchy -levels 2}
redirect ${rpt_prefix}.cell_power { report_power -cell}
redirect ${rpt_prefix}.net_power { report_power -net}
redirect ${rpt_prefix}.saif_syn_annotate { report_saif -hier}
redirect ${rpt_prefix}.saif_syn_missing  { report_saif -hier -missing}
redirect ${rpt_prefix}.rpt_clk {report_clock -skew -attribute}
redirect ${rpt_prefix}.rpt_clk_gate {report_clock_gating_check}
redirect ${rpt_prefix}.ungated {report_clock_gating -verbose -ungated}
redirect ${rpt_prefix}.clk_gate_coverage {report_clock_gating}
report_dont_touch   > ${rpt_prefix}.rpt_dont_touch
report_size_only    > ${rpt_prefix}.rpt_size_only
redirect ${rpt_prefix}.qor {report_qor}

if [shell_is_in_topographical_mode] {report_congestion > ${rpt_prefix}.post_congestion}

report_port -verbose > ${rpt_prefix}.port
report_path_group   > ${rpt_prefix}.path_group

write_parasitics -output ${out_prefix}.spef
write_sdf -context "verilog" ${out_prefix}.sdf
write_saif -output ${out_prefix}.syn_saif

set_svf -off

quit
