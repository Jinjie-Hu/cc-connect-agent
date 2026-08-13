#/**************************************************/
#/* Compile Script for Synopsys                    */
#/*                                                */
#/* dc_shell-t -f compile_dc.tcl                   */
#/*                                                */
#/* OSU FreePDK 28nm                               */
#/**************************************************/

#/* All verilog files, separated by spaces         */
#set my_verilog_files [exec find ../rtl -name "*.*v"]
#set my_verilog_files [exec find ../rtl -name "*.*v" | grep -v -E "(MF|G)_PE(_diag)?.sv"]
#set ddc_files {./G_PE_flatten.ddc ./G_PE_diag_flatten.ddc ./MF_PE_flatten.ddc}

#/* Top-level Module                               */
puts "----------------------------------- Init design"

#set search_path [concat  $search_path "../rtl/vinc"]
#dont use setting
#set cell_list [get_lib_cells typical/CLK*]
#set_dont_use $cell_list

saif_map -start
set_svf ${out_dir}/${my_toplevel}_tmp.svf
set_app_var hdlin_enable_hier_naming true

#analyze -vcs "-sverilog -f $flist +define+SYNTHESIS" -work WORK > $log_dir/${my_toplevel}.analyze; if ![catch {redirect -var error {exec cat $log_dir/${my_toplevel}__analyze.log | grep Error:}}] {error $error}
if {[llength $flist] != 0} {
    analyze -vcs "-sverilog -f $flist +define+SYNTHESIS" -work WORK > $log_dir/${my_toplevel}.analyze;
}

if {[llength $ddc_list] != 0} {
    read_ddc $ddc_list;
}

#read_ddc $ddc_files -work WORK > $log_dir/${my_toplevel}__read_ddc.log

#elaborate $my_toplevel -work WORK > $log_dir/${my_toplevel}.elaborate;  if ![catch {redirect -var error {exec cat $log_dir/${my_toplevel}__elaborate.log | grep Error:}}] {error $error}
elaborate $my_toplevel -work WORK > $log_dir/${my_toplevel}.elaborate

current_design $my_toplevel

if ![link] {error "Link Fatal"}



#set_dont_touch [get_designs G_PE]
#set_dont_touch [get_designs G_PE_diag]
#set_dont_touch [get_designs MF_PE]

uniquify -force

check_design -multiple_designs > $log_dir/${my_toplevel}.pre_chk_design

redirect ${log_prefix}.logic_compressed {analyze_datapath_extraction}
if ![catch {redirect -var errormsg {exec cat ${log_prefix}.logic_compressed | grep -E "HDL-(120|132)"} }] {error $errormsg}

# must before change_names
read_saif -instance_name $path_tb_inst -input $saif_file -auto_map_names
redirect ${rpt_prefix}.saif_rtl_annotate {report_saif -hier -rtl_saif}
redirect ${rpt_prefix}.saif_rtl_missing  {report_saif -hier -rtl_saif -missing}
