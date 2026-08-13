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
puts "----------------------------------- Init definition"

set my_toplevel reciprocal_lut
set flist /home/asic03/graduate/proj_hujinjie/L_PJG/syn/script/reci/filelist
set saif_file /home/asic03/graduate/proj_hujinjie/L_PJG/sim/vcs_top_iter_5_pre_sdf/vcs_top_iter_5_pre_sdf.saif
set path_tb_inst tb_detector/u_detector/u_reci_lut

set_app_var search_path [concat  $search_path "/home/asic03/graduate/proj_hujinjie/L_PJG/syn/script"]
#set OSU_FREEPDK [format "%s%s"  [getenv "PDK_DIR"] "/osu_soc/lib/files"]

set date_dir [clock format [clock seconds] -format %Y%m%d_%H%M%S]
set output_dir $my_toplevel/$date_dir
set rpt_dir $output_dir/rpt
set log_dir $output_dir/log
set out_dir $output_dir/out
exec mkdir -p $rpt_dir
exec mkdir -p $log_dir
exec mkdir -p $out_dir
exec mkdir -p $output_dir/WORK
set rpt_prefix ${rpt_dir}/${my_toplevel}
set log_prefix ${log_dir}/${my_toplevel}
set out_prefix ${out_dir}/${my_toplevel}

define_design_lib WORK -path $output_dir/WORK
# library check setting
set is_check_lib_enable false

# DC setting
set_app_var sh_continue_on_error false
set_app_var sh_script_stop_severity E
set_host_options -max_cores 16
