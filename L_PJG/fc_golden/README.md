# L_PJG 整机 fused FC —— golden 参考集（0-LSB 位精确验证）

本目录归档 r4 阶段用于整机 fused `detector` 功能自检（`tb_fc_detector`，`FC_DUMP_XO`）的 **4 份 MIMO 平台生成的 golden `x_p8`**（32 行 `%08x`，token = `((real&0x7FF)<<11)|(imag&0x7FF)`，fp7，delivered `128x32_c5` 激励）。EDA 侧对应数据目录 `rtl/data/128x32_c5_fused_optb/x_p8.txt` = 本目录 `x_p8_fused_rtl_gauss.txt`。

| 文件 | md5 | 量化/截位语义 | 结论 |
|---|---|---|---|
| [x_p8_fused_rtl.txt](./x_p8_fused_rtl.txt) | `257a0b15d45824be8a741439b4c05d93` | fullsum：sites 1&2 整段求和单次截位 + site3 单次截位（平台最早 full_mac 模型） | r4 早期对照；RTL got 11/32 精确、其余 ±1 LSB（site3 实际为 Gauss-per-leaf） |
| [x_p8_fused_rtl_leaf.txt](./x_p8_fused_rtl_leaf.txt) | `1ab823c11b440f3dcd0f16fe9f339b78` | leaf：site3 改 per-leaf 单截，sites 1&2 单截 | RTL got 12/32（site3 对齐；sites 1&2 逐拍截位 vs 单截失配 ±1 LSB） |
| [x_p8_fused_rtl_gauss.txt](./x_p8_fused_rtl_gauss.txt) | `29cdbe71a026bb7f7cdd18620f1f585d` | gauss：sites 1&2 单截 + site3 Gauss-per-leaf | **= Option B RTL 语义 → FC PASS 0/32（0-LSB，EDA 复现 2026-09-06）** |
| [x_p8_fused_rtl_perwrite.txt](./x_p8_fused_rtl_perwrite.txt) | `94a04b706f8f12722fd235176092dfa9` | perwrite：sites 1&2 逐拍寄存器截位 + site3 Gauss-per-leaf（镜像旧 RTL 调度/天线配对） | 32/32 匹配旧「每拍截位」RTL → 决定性坐实根因（Option A 模型）；后被 Option B 取代 |

## 背景与根因（为什么 3 份 fused golden 曾差 ±1 LSB）

fused `complex_mac_w_bias` 内部全宽、仅在输出端一次截位，但其**反馈寄存器有宽截位**：`G_reg` = `G_MAC_QTZ`(1,9,10) fp10、`y_mf` = `YMF_ACC_QTZ`(1,10,8) fp8。systolic 每拍（SYSTOLIC_PARALLEL=2，INPUT_CC=64 拍/迭代）累加 2 个全宽乘积后寄存器被 floor 到 fp10/fp8 → **每元素每迭代 64 次逐拍截位**；而 fullsum/leaf/gauss 三 golden 都把 sites 1&2 建模成「128 天线整段求和后单次截位」，结构不符（差 carry∈{0,1} fp10-LSB，且依赖逐拍天线配对顺序）。compact 能 0/32 是因为逐乘积 floor 与分组无关。

两条路：
- **Option A（不改硬件）**：MIMO 平台按 RTL 真实调度建模逐拍截位 → `perwrite` golden（上表末行）32/32 匹配旧 RTL，坐实根因。
- **Option B（用户批准，最终采用）**：把 `G_reg`/`y_mf` 反馈寄存器加宽到 `complex_mac_w_bias` 内部 ACC3 全宽（`G_ACC_FULL_QTZ(1,10,12)` / `YMF_ACC_FULL_QTZ(1,13,11)`，见 [params.svh](../rtl/vinc/params.svh)），使每拍回馈成为恒等 transfer、整段扫描仅两次单次截位（G→`G_QTZ` fp5、y_mf→`YMF_QTZ` fp8）。语义与平台 `full_mac`/gauss golden 天然一致。

## 验证

- EDA 数据目录 `L_PJG/rtl/data/128x32_c5_fused_optb`（`x_p8.txt` = gauss golden，md5 `29cdbe71…`）。
- 运行：[run_fc_optb.sh](../run_fc_optb.sh)（VCS I-2014.03，`TEST_ITER_NUM=16`、32 TX），产物 `vcs_top_fc_16_optb_re/`（复现 2026-09-06）。
- 结果：`FC: PASS - x_o matches golden x_p8 for all 32 TX entries`；`fc_dump.txt` 32 条 `got==exp`，**0 mismatch / 0-LSB**。
