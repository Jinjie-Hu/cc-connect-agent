
puts "----------------------------------- scenarios setting"

if [shell_is_in_topographical_mode] {
    set_ignored_layers -min_routing_layer M2 -max_routing_layer M7; 
}
set_dynamic_optimization true

# set PVT
create_scenario SSG 
set_operating_conditions ssg0p72vm40c -library [get_lib *ssg0p72vm40c*]
if [shell_is_in_topographical_mode] {
    set_tlu_plus_files -max_tluplus $tluplus_rcmax -min_tluplus $tluplus_rcmin -tech2itf_map $starmap_file;
    redirect ${log_prefix}.chk_ssg_tluplus {check_tlu_plus_files}; 
    source a_timing.con;
}

create_scenario FFG
set_operating_conditions ffg1p05v125c -library [get_lib *ffg1p05v125c*]
if [shell_is_in_topographical_mode] { 
    set_tlu_plus_files -max_tluplus $tluplus_rcmax -min_tluplus $tluplus_rcmin -tech2itf_map $starmap_file; 
    redirect ${log_prefix}.chk_ffg_tluplus {check_tlu_plus_files}; 
    source a_timing.con;
}

create_scenario TT
set_operating_conditions tt0p9v25c -library [get_lib *tt0p9v25c*]
if [shell_is_in_topographical_mode] { 
    set_tlu_plus_files -max_tluplus $tluplus_typc -min_tluplus $tluplus_typc -tech2itf_map $starmap_file; 
    redirect ${log_prefix}.chk_tt_tluplus {check_tlu_plus_files}; 
    source a_timing.con;
}

redirect ${log_prefix}.chk_tluplus {check_tlu_plus_files}

set_active_scenarios {TT}
if [shell_is_in_topographical_mode] { 
    set_utilization $utilization; 
    set_aspect_ratio $aspect_ratio; 
}
all_active_scenarios > ${log_prefix}.active_scenarios
if [shell_is_in_topographical_mode] { \
    report_tlu_plus_files > ${log_prefix}.rpt_tluplus \
}

