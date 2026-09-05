# g_pe_full_lib - G_PE before/after area comparison (logic mode, single TT corner)
# run: dc_shell -f $TPL/syn/script/run_syn.tcl -x "set cfg <this>"
# Same methodology as arithmetic_area_test: no retime/-spg so per-instance
# area tracks the RTL structure; identical constraints across all variants.

set my_toplevel G_PE
set flist       /home/asic03/graduate/proj_hujinjie/g_pe_area_test/syn/script/g_pe_full_lib/G_PE.filelist

set flow_report_level lite
set flow_clock_gating simple
set flow_retime       false

set pdk_corners       [list tt]
set pdk_active_corner tt

set my_clk_freq_MHz 800
set clk_uncertainty_setup_ratio 0.2
set derate_late     0
set max_fanout      128
