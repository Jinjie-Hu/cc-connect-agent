#!/bin/bash
# FC re-run: fused whole-design L_PJG vs per-write-register-truncation golden
# (Option A: platform mirrors RTL's per-cycle fp10/fp8 accumulator floors).
# golden: L_PJG/rtl/data/128x32_c5_fused/x_p8.txt   md5 <PENDING_MIMO_GOLDEN_MD5>
# NOTE: before running, install the per-write golden at the FC_DATA_DIR path
# below (L_PJG/rtl/data/128x32_c5_fused/x_p8.txt).
export VCS_HOME=/eda/synopsys/vcs/VCS/VCS2014
export NOVAS_HOME=/eda/synopsys/verdi/vJ-2014.12-SP2
export PATH=$VCS_HOME/bin:$PATH
export LD_LIBRARY_PATH=$VCS_HOME/amd64/lib:$NOVAS_HOME/share/PLI/VCS/LINUX64
export SNPSLMD_LICENSE_FILE=27000@icaislab

LPJG=/home/asic03/graduate/proj_hujinjie/L_PJG
OUT=vcs_top_fc_16_perwrite
RUN=$LPJG/$OUT

cd "$LPJG" || exit 1
rm -rf "$RUN"
mkdir -p "$RUN"
cd "$RUN" || exit 1

echo "=== compiling fused whole-design FC (per-write golden) ==="
/eda/synopsys/vcs/VCS/VCS2014/bin/vcs -sverilog +v2k -timescale=1ns/1ns \
  -top tb_fc_detector \
  +define+RTLVCD \
  -debug_all \
  +memcbk \
  +notimingcheck \
  +vcs+flush+all \
  +define+TEST_ITER_NUM=16 \
  +define+FC_DATA_DIR=\"/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/data/128x32_c5_fused\" \
  +define+FC_DUMP_XO \
  +define+FC_DUMP_FILE=\"$RUN/fc_dump.txt\" \
  -full64 -j16 -ignore all \
  -o sim_fc_perwrite \
  -l compile.log \
  -f /home/asic03/graduate/proj_hujinjie/L_PJG/sim_rtl_fc.f

RC_BUILD=$?
echo "VCS build rc=$RC_BUILD"
if [ $RC_BUILD -ne 0 ]; then echo "COMPILE FAILED"; exit 2; fi

cp -f compile.log vcs_build.log

echo "=== running ==="
./sim_fc_perwrite -l sim.log
RC_RUN=$?
cp -f sim.log vcs_run.log
echo "VCS run rc=$RC_RUN"

echo "=== FC result ==="
grep -a "FC:" sim.log
echo "=== dump file ==="
ls -l fc_dump.txt 2>/dev/null
exit $RC_RUN
