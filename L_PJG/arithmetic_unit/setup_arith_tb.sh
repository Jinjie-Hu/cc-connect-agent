#!/bin/bash
# =============================================================================
# setup_arith_tb.sh
# -----------------
# Deploy L_PJG arithmetic_unit RTL + 16 testbenches + golden data into
# ~/projects/Template, and generate per-testbench filelists for use with
# Template's vcs/build.mk (SIM_FILE/TOP_MODULE/OUTPUT overridable).
#
# Run on eda_wsl:  bash /mnt/d/cc-connect-agent/L_PJG/arithmetic_unit/setup_arith_tb.sh
# =============================================================================
set -u

TMPL=~/projects/Template
VCS_DIR=$TMPL/vcs
TB_DIR=$VCS_DIR/tb
DATA_DIR=$VCS_DIR/data
RTL_DIR=$TMPL/RTL
VINC_DIR=$RTL_DIR/vinc

SRC=/mnt/d/cc-connect-agent/L_PJG/arithmetic_unit
TEST=$SRC/test

echo "=== [1/4] Copying RTL sources into $RTL_DIR ==="
mkdir -p "$RTL_DIR"
# backup existing real_multiplier.sv (Template version differs in defaults)
if [ -f "$RTL_DIR/real_multiplier.sv" ] && [ ! -f "$RTL_DIR/real_multiplier.sv.tmplbak" ]; then
  cp -f "$RTL_DIR/real_multiplier.sv" "$RTL_DIR/real_multiplier.sv.tmplbak"
  echo "backed up existing real_multiplier.sv -> real_multiplier.sv.tmplbak"
fi
RTL_SRCS="real_multiplier.sv real_adder.sv real_addsub.sv real_negative.sv \
          real_adder_tree.sv real_mac.sv complex_multiplier.sv complex_adder.sv \
          complex_addsub.sv complex_conj.sv complex_negative.sv \
          complex_adder_tree.sv complex_real_multiplier.sv complex_mac.sv"
for f in $RTL_SRCS; do
  cp -f "$SRC/$f" "$RTL_DIR/$f" && echo "  copied $f"
done
# make sure qtz header is the L_PJG version (should already be identical)
cp -f /mnt/d/cc-connect-agent/L_PJG/rtl/vinc/qtz_def.svh "$VINC_DIR/qtz_def.svh"
echo "  ensured qtz_def.svh = L_PJG version"

echo "=== [2/4] Copying 16 testbenches into $TB_DIR ==="
mkdir -p "$TB_DIR"
TBS="real_multiplier real_adder real_addsub real_negative real_adder_tree \
     real_mac real_mac_w_bias complex_multiplier complex_adder complex_addsub \
     complex_conj complex_negative complex_adder_tree complex_real_multiplier \
     complex_mac complex_mac_w_bias"
for tb in $TBS; do
  cp -f "$TEST/${tb}_tb.sv" "$TB_DIR/${tb}_tb.sv" && echo "  copied ${tb}_tb.sv"
done

echo "=== [3/4] Copying test data (data/ incl. out/) into $DATA_DIR ==="
rm -rf "$DATA_DIR"
cp -r "$TEST/data" "$DATA_DIR"
echo "  data copied. contents:"
ls "$DATA_DIR"
echo "  data/out:"
ls "$DATA_DIR/out" | head -40

echo "=== [4/4] Generating per-testbench filelists in $VCS_DIR ==="
declare -A SRCS=(
 [real_multiplier]="real_multiplier.sv"
 [real_adder]="real_adder.sv"
 [real_addsub]="real_addsub.sv"
 [real_negative]="real_negative.sv"
 [real_adder_tree]="real_adder_tree.sv"
 [real_mac]="real_mac.sv"
 [real_mac_w_bias]="real_mac.sv"
 [complex_multiplier]="complex_multiplier.sv real_multiplier.sv"
 [complex_adder]="complex_adder.sv real_adder.sv"
 [complex_addsub]="complex_addsub.sv real_addsub.sv"
 [complex_conj]="complex_conj.sv"
 [complex_negative]="complex_negative.sv"
 [complex_adder_tree]="complex_adder_tree.sv real_adder_tree.sv"
 [complex_real_multiplier]="complex_real_multiplier.sv real_multiplier.sv"
 [complex_mac]="complex_mac.sv"
 [complex_mac_w_bias]="complex_mac.sv"
)
for tb in $TBS; do
  fl="$VCS_DIR/${tb}_tb.filelist"
  {
    echo "+incdir+${VINC_DIR}"
    for s in ${SRCS[$tb]}; do echo "${RTL_DIR}/$s"; done
    echo "${TB_DIR}/${tb}_tb.sv"
  } > "$fl"
  echo "  wrote $fl"
done

echo "=== done ==="
ls "$VCS_DIR"/*.filelist
