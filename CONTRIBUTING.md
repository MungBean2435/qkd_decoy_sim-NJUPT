# 贡献指南

## 环境

- MATLAB **R2020a 或更新**（`exportgraphics` 需要 R2020a+）；无需任何工具箱
- Git 2.30+
- 可选：Octave 仅能跑计算内核，GUI 与 `exportgraphics` 不支持

## 首次拉取

```bash
git clone https://github.com/MungBean2435/qkd_decoy_sim-NJUPT.git
cd qkd_decoy_sim
```

MATLAB 里：

```matlab
addpath(genpath(pwd));
runTests        % 应全部 PASS，否则先别动手
```

## 分支与提交

```bash
git switch -c feat/your-topic      # 新功能
git switch -c fix/your-bug         # 修 bug
```

提交信息用 Conventional Commits 前缀，一句话说清改了什么：

```
feat(fluct): 增加 Arimoto 型置信区间
fix(estimate): 修正 e1 上界在 Y1L=0 时的除零
docs(readme): 补充结果表
test(runTests): 更新高斯金标准
```

**不要**提交：`results/*.fig`、`*.asv`、个人路径、MATLAB 许可文件。

## 改代码前必读

这个项目的价值在于**物理可核对**，所以有三条硬约束：

1. **物理公式只能出现在 `+qkd/` 里**
   GUI（`QKDApp.m`）与出图脚本（`run_task*.m`）只负责收集参数和画图。
   发现公式泄漏到界面层，请顺手搬回内核。

2. **改动物理模型必须同步更新 `runTests.m` 的金标准**
   那些数值是从已验证结果固化下来的。如果改完测试红了：
   - 先确认新结果**物理上合理**（参考指导书公式编号、量级、单调性）；
   - 再更新金标准，并在 PR 描述里写：改了什么、为什么、对应指导书哪条式子。

3. **三种起伏方法共用同一条估计链**
   新增方法 = 在 [`+qkd/fluct.m`](../+qkd/fluct.m) 里加一个 `case`，
   实现 `D.Q` / `D.T` / `D.Y0` 三个偏差函数即可，`estimate.m` 不用动。

## 提交 PR 前

```matlab
runTests        % 必须全 PASS
selfTest        % 粗略打印关键数值，看量级是否正常
smokeGUI        % 只在改了 QKDApp.m 时需要（会弹窗）
```

PR 描述里请写清：

- 改了什么（对应哪条公式 / 哪个文件）
- 测试结果（贴 `runTests` 的通过行数即可）
- 是否需要队友同步重跑 `results/` 里的图

## 更新生成结果

如果改动影响了数值，请同时重新生成并提交图与表：

```matlab
run_task1; run_task2; run_task3; verify; exportReportData
```

然后 `git add results/*.png results/*.csv results/*.log`（`.fig` 会被 `.gitignore` 挡掉）。

## 冲突处理建议

- `results/*.png`、`results/*.csv` 是生成物，冲突时**不要手工合并**：
  取期望的分支版本后重新跑一遍脚本生成。
- `.m` 文件已用 `.gitattributes` 统一为 LF，若仍出现整文件 diff，
  检查本机 `core.autocrlf`（建议 `input` 或 `false`）。
