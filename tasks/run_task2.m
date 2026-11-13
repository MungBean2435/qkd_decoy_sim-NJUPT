function res = run_task2(opt)
%RUN_TASK2 任务 2：三种统计起伏方法比一比，同时优化信号态光强 u
%
%   题目要求：画出高斯、霍夫丁、切尔诺夫三种方法下，N=10^9 时
%             优化信号态 u 后密钥率随传输距离变化的图像。
%
% ------------------------------------------------------------------------
%  这个脚本想回答两个问题：
%     ① 三种「留余量」的方法，谁更宽松？（宽松 = 能传得更远）
%     ② 把光强 u 调到当前距离上最合适的值，能多赚多少？
%
%  它一共出两张图：
%     fig2_three_methods  三种方法的 R–L 曲线（主图）
%     fig2b_optimal_u     最优 u 本身随距离怎么变（理解题，答辩常问）
% ------------------------------------------------------------------------
%
%  「逐距离最优」是什么意思：每个距离点各挑各的 u，而不是一条曲线统一用一个 u。
%  好处是这条曲线代表「该方法最好能到什么水平」；代价是实际系统得按距离重新标定。

if nargin < 1 || isempty(opt)
    opt = struct();
end

p    = qkd.params();
N    = 1e9;                                        % 题目指定：十亿个脉冲
meth = {'gauss', 'hoeffding', 'chernoff'};         % 三种方法的内核名字
labs = {'高斯 (Gaussian)', '霍夫丁 (Hoeffding)', '切尔诺夫 (Chernoff)'};   % 图例（带英文便于对照）
tags = {'高斯', '霍夫丁', '切尔诺夫'};              % 进度条上用的短名
cols = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.35 0.60 0.25];
mks  = {'o', 's', '^'};

[f, ax]   = newFig(800, 560);     % 主图：R–L 曲线
[f2, ax2] = newFig(760, 440);     % 副图：u*(L) 曲线
cleanup   = onCleanup(@() closeQuietly([f f2]));   % 异常/取消时把两张图一起关掉

res = cell(1, numel(meth));
for k = 1:numel(meth)
    % 关键三行：method 选方法、opt='u' 表示只优化 u、optU 给出搜索范围
    spec = struct('method', meth{k}, 'N', N, 'eps', 1e-7, ...
                  'L', [0 300 1], 'opt', 'u', ...
                  'optU', struct('lb', 0.10, 'ub', 1.30, 'n', 61, 'mode', 'perDistance'));
    %   lb/ub：u 的搜索上下界（0.10 ~ 1.30，太大会有多光子风险）
    %   n    ：在区间里均匀取 61 个候选
    %   mode ：perDistance = 每个距离点各选最优（另一种是 fixed，全程统一）
    spec.onProgress = @(frc, msg) taskReport(opt, ((k - 1) + frc) / numel(meth), ...
                                            ['任务2 · ' tags{k} ' · ' msg]);
    res{k} = qkd.runCase(p, spec);
    semilogy(ax, res{k}.L, res{k}.R, '-', 'Color', cols(k, :), 'LineWidth', 1.9, ...
             'Marker', mks{k}, 'MarkerSize', 4, 'MarkerIndices', 1:25:numel(res{k}.L), ...
             'DisplayName', sprintf('%s   (最远 %.0f km)', labs{k}, res{k}.Lmax));
end

set(ax, 'XLim', [0 210], 'YLim', [1e-12 5e-2]);
xlabel(ax, '传输距离 L (km)');
ylabel(ax, '安全密钥率 R (bit/pulse)');
title(ax, sprintf('N = 10^9 时三种统计起伏方法对比（逐距离优化信号态 u）'));
legend(ax, 'Location', 'northeast', 'FontName', cjkFont());
grid(ax, 'on');

saveResult(f, 'fig2_three_methods', res{end});   % 用切尔诺夫那条（最后一条）写 CSV

% ---- 副图：最优光强 u*(L) 随距离怎么变 ----
% 纵轴改成线性（不取对数），因为 u 是 0.1~1.3 这种量级的普通数值。
set(ax2, 'YScale', 'linear');
for k = 1:numel(meth)
    plot(ax2, res{k}.L, res{k}.u, '-', 'Color', cols(k, :), 'LineWidth', 1.9, ...
         'DisplayName', labs{k});
end
set(ax2, 'XLim', [0 200], 'YLim', [0 1.4]);
xlabel(ax2, '传输距离 L (km)');
ylabel(ax2, '最优信号态光强 u^*');
title(ax2, '最优信号态光强随距离的演化');
legend(ax2, 'Location', 'northeast', 'FontName', cjkFont());
grid(ax2, 'on');
saveResult(f2, 'fig2b_optimal_u', res{end});

taskReport(opt, 1, '任务2 完成');
fprintf('图2 完成：gauss Lmax=%.0f, hoeffding Lmax=%.0f, chernoff Lmax=%.0f\n', ...
        res{1}.Lmax, res{2}.Lmax, res{3}.Lmax);
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
