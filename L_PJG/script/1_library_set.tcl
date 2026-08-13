#/**************************************************/
#/* Compile Script for Synopsys                    */
#/*                                                */
#/* dc_shell-t -f compile_dc.tcl                   */
#/*                                                */
#/* OSU FreePDK 28nm                               */
#/**************************************************/

#set alib_library_analysis_path $OSU_FREEPDK
#/home/asic02/proj_hujinjie/OCD_SLAS/lib/tcbn28hpcplusbwp30p140tt0p9v25c_ccs.db

puts "----------------------------------- TSMC-28 c30 library setting"

set target_lib [list \
/home/asic03/TSMC28nm/TSMCHOME/digital/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140_110c/tcbn28hpcplusbwp30p140tt0p9v25c_ccs.db \
/home/asic03/TSMC28nm/TSMCHOME/digital/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140_110c/tcbn28hpcplusbwp30p140ssg0p72vm40c_ccs.db \
/home/asic03/TSMC28nm/TSMCHOME/digital/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140_110c/tcbn28hpcplusbwp30p140ffg1p05v125c_ccs.db 
]

set_app_var target_library $target_lib 
#set link_library "* $target_lib" 

set_app_var link_library "* \
$target_lib \
/home/asic03/graduate/proj_hujinjie/OCD_SLAS/lib/dw_foundation.sldb \
" 

# Adding -optimization {power} needs to add lvt lib
if {$is_check_lib_enable} {
    set_check_library_options -reset;
    #set_check_library_options -logic;
    set_check_library_options -scaling {timing noise power} -mcmm -upf;
    redirect ${log_prefix}.chk_logic_lib {check_library};
}

# Add physical lib
set_app_var mw_logic1_net VDD
set_app_var mw_logic0_net VSS
set_app_var mw_power_port VDD
set_app_var mw_ground_port VSS

set my_milkyway_lib ${out_prefix}_TSMC28_MILKYWAY
set milkyway_lib [list /home/asic03/graduate/proj_hujinjie/lib/tcbn28hpcplusbwp30p140_1P9M_4x2y2rut]
set tf_file /home/asic03/graduate/proj_hujinjie/lib/tsmcn28_9lm4X2Y2RUTRDL.tf
set starmap_file /home/asic03/graduate/proj_hujinjie/lib/star.map_9M
set tluplus_rcmax "/home/asic02/proj_swsong/MIMO_ICC/PR_MIMO/lib/TLUplus/1P9M_28nm/cln28hpc+_1p09m+ut-alrdl_4x2y2r_rcbest.tluplus"
set tluplus_rcmin "/home/asic02/proj_swsong/MIMO_ICC/PR_MIMO/lib/TLUplus/1P9M_28nm/cln28hpc+_1p09m+ut-alrdl_4x2y2r_rcworst.tluplus"
set tluplus_cmax  "/home/asic02/proj_swsong/MIMO_ICC/PR_MIMO/lib/TLUplus/1P9M_28nm/cln28hpc+_1p09m+ut-alrdl_4x2y2r_cbest.tluplus"
set tluplus_cmin  "/home/asic02/proj_swsong/MIMO_ICC/PR_MIMO/lib/TLUplus/1P9M_28nm/cln28hpc+_1p09m+ut-alrdl_4x2y2r_cworst.tluplus"
set tluplus_typc  "/home/asic02/proj_swsong/MIMO_ICC/PR_MIMO/lib/TLUplus/1P9M_28nm/cln28hpc+_1p09m+ut-alrdl_4x2y2r_typical.tluplus"

if [shell_is_in_topographical_mode] {
    redirect ${log_prefix}.create_mw_lib {create_mw_lib -open -technology $tf_file -mw_reference_library $milkyway_lib $my_milkyway_lib};
}

if {[shell_is_in_topographical_mode] && $is_check_lib_enable} {
    set_check_library_options -reset;
    set_check_library_options -physical;
    redirect ${log_prefix}.chk_physical_lib {check_library};    
}

if {[shell_is_in_topographical_mode] && $is_check_lib_enable} {
    set_check_library_options -reset;
    set_check_library_options -logic_vs_physical;
    redirect ${log_prefix}.chk_logic_vs_physical_lib {check_library};    
}

# set lowpower attribute
set_attribute [get_lib *bwp30p140*] default_threshold_voltage_group c30
#set_attribute [get_lib *bwp40p140*] default_threshold_voltage_group c40
