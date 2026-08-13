# spyglass_run.tcl - Complete SystemVerilog2009 Lint + CDC Script

set TOPNAME detector
set INCDIR ../rtl/vinc

#######################################
# 1. Project Initialization
#######################################
set prj_dir ./$TOPNAME

new_project -projectwdir $prj_dir $TOPNAME.prj -force

#######################################
# 2. Auto-find RTL files using Linux find
#######################################
# Define search directories (modify as needed)
set RTL_DIRS ../rtl

# Execute native Linux find command
exec echo +incdir+$INCDIR > filelist.f
set temp_filelist [exec find $RTL_DIRS -name "*.*v" >> filelist.f]

## 设置顶层模块
set top $TOPNAME
## 读取RTL文件和工艺库
read_file -type sourcelist filelist.f
#read_file -type gateslib /home/tsmc_lib/XXX.lib
## 读取约束文件
#read_file -type sgdc ${top}.sgdc
## 配置SpyGlass选项
set_option language_mode mixed
set_option enableSV yes
## 执行Lint检查
current_goal lint/lint_rtl -top ${TOPNAME}
run_goal
## 输出报告并保存工程
write_report moresimple > ${top}_lint.rpt
save_project -force ${top}.prj
## 退出程序
exit -force
