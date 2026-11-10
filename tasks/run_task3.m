function res = run_task3(opt)
%RUN_TASK3 图3：切尔诺夫，N = 1e9，全局优化 (u, v, P_u, P_v)
%
%   题目要求（提高项）：切尔诺夫起伏分析方法下，N=10^9 全局优化时
%   密钥率随传输距离变化的图像。
%
%   同时画一条“不优化”的基准曲线，便于直接看出优化增益。
%
%   opt 为可选项（GUI 批量出图时传入）：
%       .onProgress  function handle @(frac, msg)，用于更新进度条。

if nargin < 1 || isempty(opt)
    opt = struct();
end

p  = qkd.params();
N  = 1e9;
[f, ax]   = newFig(800, 560);
[f2, ax2] = newFig(820, 520);
cleanup   = onCleanup(@() closeQuietly([f f2]));   % 取消/报错时也关闭图窗

% --- 基准：不优化 ---
specB = struct('method', 'chernoff', 'N', N, 'eps', 1e-7, 'L', [0 300 1], 'opt', 'none');
specB.onProgress = @(frc, msg) taskReport(opt, 0.02 * frc, ['任务3 · 基准 · ' msg]);
b = qkd.runCase(p, specB);
semilogy(ax, b.L, b.R, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.7, ...
         'DisplayName', sprintf('未优化  (最远 %.0f km)', b.Lmax));

% --- 全局优化 ---
specG = struct('method', 'chernoff', 'N', N, 'eps', 1e-7, 'L', [0 300 1], ...
               'opt', 'global', 'optG', struct('npop', 30, 'ngen', 40));
specG.onProgress = @(frc, msg) taskReport(opt, 0.02 + 0.96 * frc, ['任务3 · 全局优化 · ' msg]);
g = qkd.runCase(p, specG);
semilogy(ax, g.L, g.R, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.1, ...
         'DisplayName', sprintf('全局优化  (最远 %.0f km)', g.Lmax));

set(ax, 'XLim', [0 220], 'YLim', [1e-12 5e-2]);
xlabel(ax, '传输距离 L (km)');
ylabel(ax, '安全密钥率 R (bit/pulse)');
title(ax, '切尔诺夫统计起伏：全局优化 (u, v, P_u, P_v) 前后的密钥率');
legend(ax, 'Location', 'northeast', 'FontName', cjkFont());
grid(ax, 'on');

saveResult(f, 'fig3_chernoff_global', g);

% 附加图：四个最优参数随距离的演化
set(ax2, 'YScale', 'linear');
plot(ax2, g.L, g.u,  '-', 'Color', [0.00 0.45 0.74], 'LineWidth', 1.8, 'DisplayName', 'u^*');
plot(ax2, g.L, g.v,  '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.8, 'DisplayName', 'v^*');
plot(ax2, g.L, g.Pu, '--', 'Color', [0.35 0.60 0.25], 'LineWidth', 1.6, 'DisplayName', 'P_u^*');
plot(ax2, g.L, g.Pv, '--', 'Color', [0.60 0.30 0.65], 'LineWidth', 1.6, 'DisplayName', 'P_v^*');
set(ax2, 'XLim', [0 200], 'YLim', [0 1.0]);
xlabel(ax2, '传输距离 L (km)');
ylabel(ax2, '优化后的参数值');
title(ax2, '全局优化得到的参数随距离演化');
legend(ax2, 'Location', 'northeast', 'FontName', cjkFont());
grid(ax2, 'on');
saveResult(f2, 'fig3b_optimal_params', g);
taskReport(opt, 1, '任务3 完成');

fprintf('图3 完成：未优化 Lmax=%.0f km，全局优化 Lmax=%.0f km\n', b.Lmax, g.Lmax);
res = struct('base', b, 'opt', g);
end

% ---------------------------------------------------------------- helpers
function taskReport(opt, frac, msg)
if isfield(opt, 'onProgress') && ~isempty(opt.onProgress)
    opt.onProgress(min(max(frac, 0), 1), msg);
end
end

function closeQuietly(h)
for k = 1:numel(h)
    if isvalid(h(k))
        close(h(k));
    end
end
end
