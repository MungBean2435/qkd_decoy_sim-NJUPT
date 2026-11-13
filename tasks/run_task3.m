function res = run_task3(opt)
%RUN_TASK3 任务 3（提高项）：切尔诺夫起伏下，四个参数一起优化，能传多远？
%
%   题目要求（提高项）：切尔诺夫起伏分析方法下，N=10^9 全局优化时
%                       密钥率随传输距离变化的图像。
%
% ------------------------------------------------------------------------
%  和前两个任务的区别：这次一下子优化四个参数 —— (u, v, P_u, P_v)。
%  也就是「光发多强、诱骗态多弱、两种脉冲各占多少比例」全都交给算法去找。
%
%  为什么难：这四个参数互相牵制。
%     u 调亮 → 收到的光子多、误差小，但多光子比例上升，安全性变差；
%     P_u 调大 → 成码的脉冲更多，但真空态比例被挤小，暗计数就估不准；
%     v 必须比 u 小（否则单光子估计公式分母变号），所以两者得配合着调。
%  没有解析解，只能搜索。本工程用「差分进化 + 坐标下降」（见 runCase.m）。
%
%  本脚本出两张图：
%     fig3_chernoff_global  优化前 vs 优化后的 R–L 曲线（主图）
%     fig3b_optimal_params  四个最优参数各自随距离怎么变（理解题）
% ------------------------------------------------------------------------

if nargin < 1 || isempty(opt)
    opt = struct();
end

p  = qkd.params();
N  = 1e9;
[f, ax]   = newFig(800, 560);
[f2, ax2] = newFig(820, 520);
cleanup   = onCleanup(@() closeQuietly([f f2]));   % 取消/报错时也关掉图窗

% ---- 第一步：先画基准线（不优化），后面才有「优化前/后」的对比 ----
specB = struct('method', 'chernoff', 'N', N, 'eps', 1e-7, 'L', [0 300 1], 'opt', 'none');
specB.onProgress = @(frc, msg) taskReport(opt, 0.02 * frc, ['任务3 · 基准 · ' msg]);
b = qkd.runCase(p, specB);
% 基准线用灰色虚线：一眼就能看出「这只是参照物」
semilogy(ax, b.L, b.R, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.7, ...
         'DisplayName', sprintf('未优化  (最远 %.0f km)', b.Lmax));

% ---- 第二步：全局优化（这一步最慢，约占整个任务 3 的 96% 时间）----
specG = struct('method', 'chernoff', 'N', N, 'eps', 1e-7, 'L', [0 300 1], ...
               'opt', 'global', 'optG', struct('npop', 30, 'ngen', 40));
%   npop：每一代撒多少个候选参数（30 个）
%   ngen：一共进化多少代（40 代）
%   两个数越大越准，也越慢。自检里会调小，正式出图才用这个配置。
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

% ---- 第三步：附加图——四个最优参数随距离的演化 ----
% 这张图是「物理理解」的关键：为什么远距离要换一套参数？
% 实线画光强（u、v），虚线画概率（P_u、P_v），用线型区分两类量。
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
res = struct('base', b, 'opt', g);    % 两条曲线都返回，方便别处复用
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
