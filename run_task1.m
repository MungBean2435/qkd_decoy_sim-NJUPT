function res = run_task1(opt)
%RUN_TASK1 图1：高斯型统计起伏，N = 1e8 / 1e9 / 1e10，不优化
%
%   题目要求：画出高斯型统计起伏分析方法下，发射脉冲数 N=10^8、10^9、10^10
%             不优化时密钥率随传输距离变化的图像。
%
%   本脚本只做三件事：调 qkd.runCase → 画线 → 存图，不含物理公式。
%
%   opt 为可选项（GUI 批量出图时传入）：
%       .onProgress  function handle @(frac, msg)，用于更新进度条；
%                    回调抛出的异常（如用户取消）会向上传播。

if nargin < 1 || isempty(opt)
    opt = struct();
end

p    = qkd.params();
Ns   = [1e8, 1e9, 1e10];
cols = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.35 0.60 0.25];
mks  = {'o', 's', '^'};

[f, ax] = newFig(800, 560);
cleanup = onCleanup(@() closeQuietly(f));   % 命令行/取消/报错时都关闭隐藏图窗

res = cell(1, numel(Ns));
for k = 1:numel(Ns)
    spec = struct('method', 'gauss', 'N', Ns(k), 'eps', 1e-7, ...
                  'L', [0 300 1], 'opt', 'none');
    spec.onProgress = @(frc, msg) taskReport(opt, ((k - 1) + frc) / numel(Ns), ...
                                            ['任务1 · ' msg]);
    res{k} = qkd.runCase(p, spec);
    semilogy(ax, res{k}.L, res{k}.R, '-', 'Color', cols(k, :), 'LineWidth', 1.9, ...
             'Marker', mks{k}, 'MarkerSize', 4, 'MarkerIndices', 1:25:numel(res{k}.L), ...
             'DisplayName', sprintf('N = 10^{%d}   (最远 %.0f km)', ...
                                    round(log10(Ns(k))), res{k}.Lmax));
end

set(ax, 'XLim', [0 220], 'YLim', [1e-12 5e-2]);
xlabel(ax, '传输距离 L (km)');
ylabel(ax, '安全密钥率 R (bit/pulse)');
title(ax, '高斯统计起伏：不同发射脉冲数下的密钥率（未优化）');
legend(ax, 'Location', 'northeast', 'FontName', cjkFont());
grid(ax, 'on');

saveResult(f, 'fig1_gauss_threeN', res{end});
taskReport(opt, 1, '任务1 完成');
fprintf('图1 完成：N=1e8 Lmax=%.0f km, N=1e9 Lmax=%.0f km, N=1e10 Lmax=%.0f km\n', ...
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
