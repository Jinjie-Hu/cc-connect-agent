#/**************************************************/
#/* Compile Script for Synopsys                    */
#/*                                                */
#/* dc_shell-t -f compile_dc.tcl                   */
#/*                                                */
#/* OSU FreePDK 28nm                               */
#/**************************************************/

source script/PE/0_define_MF_PE.tcl
source script/1_library_set.tcl
source script/2_rtl_input.tcl
source script/3_scenario.tcl
source script/4_compile.tcl
source script/5_output.tcl

quit
