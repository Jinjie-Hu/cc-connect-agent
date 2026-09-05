# L_PJG/syn_whole —— 整机综合 BEFORE/AFTER 两版 filelist（准备中，尚未综合）

> 用途：整颗 `detector` 顶层「BEFORE（compact，= git HEAD）vs AFTER（fused/full-lib，= 当前工作树）」DC 综合对比的 RTL 输入对。详细计划见 [../docs/整机综合对比准备计划.md](../docs/整机综合对比准备计划.md)。

| 文件 | 版本 | 内容 |
|---|---|---|
| `rtl_before.filelist` | BEFORE | 与 [../script/rtl.filelist](../script/rtl.filelist) 相同（compact，逐级截位 PE + compact `complex_multiplier`） |
| `rtl_after.filelist` | AFTER | fused 3 PE + full-lib `complex_mac.sv`/`complex_multiplier.sv`，去掉 compact `complex_multiplier.sv` |

两版差异（`diff rtl_before.filelist rtl_after.filelist`）仅：
1. AFTER 去掉 `rtl/arithmetic_unit/complex_multiplier.sv`；
2. AFTER 加入 `arithmetic_unit_full/complex_mac.sv` 与 `arithmetic_unit_full/complex_multiplier.sv`；
3. 3 个 PE 文件路径不变、内容为 fused 工作树版（随提交同步到 EDA）。

路径为 EDA 绝对路径（根 `/home/asic03/graduate/proj_hujinjie/`），与 [../script/rtl.filelist](../script/rtl.filelist)、[../sim_rtl_fc.f](../sim_rtl_fc.f) 同约定。

## 前置（跑综合前必须完成，当前均未达）
- 整机 fused FC 对正确 fused golden 0/32 通过（r4-verify-0lsb，见 docs/整机综合对比准备计划.md §1 根因记录 + §6）；
- AFTER 源码提交，使对比基线 = BEFORE(git HEAD) vs AFTER(提交后工作树)；
- 约束/流程沿用 `L_PJG/script/` 的 1..5 分步 tcl / `syn.tcl`（方案 A：logic、no retime、TT、1.25ns+20%，与 PE 级报告可比）。

## 暂不执行
本目录只备 filelist，**不触发综合**（用户要求先做 0-LSB 验证与提交准备，掌握完整综合流程后再跑）。
