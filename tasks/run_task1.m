function res = run_task1(opt)
%RUN_TASK1 任务 1：高斯起伏下，不同发射脉冲数 N 的密钥率曲线（不优化）
%
%   题目要求：画出高斯型统计起伏分析方法下，发射脉冲数 N=10^8、10^9、10^10
%             不优化时密钥率随传输距离变化的图像。
%
% ------------------------------------------------------------------------
%  这个脚本只做三件事，看完就能照着写自己的脚本：
%     ① 收集参数（qkd.params + 一个 spec）
%     ② 调 qkd.runCase 算出曲线
%     ③ 画图 + 存盘
%  它里面没有任何物理公式 —— 公式都在 +qkd/ 里，这样改图不会碰到物理。
%
%  三个 N 一起画在一张图上，是为了回答一个问题：
%     「多发点脉冲，能传得更远吗？」答案见图（能，而且差别全在远端）。
% ------------------------------------------------------------------------
%
%  用法：在工程根目录（或已 addpath(genpath(root)) 的地方）直接敲
%       run_task1
%
%  opt 是可选参数（GUI 批量出图时传进来）：
%       .onProgress  function handle @(frac, msg)，用来更新进度条；
%                    回调抛出的异常（比如用户点了取消）会一路传上去。

if nargin < 1 || isempty(opt)
    opt = struct();     % MATLAB 小技巧：没传就造一个空结构体，后面 isfield 判断就安全了
end

p    = qkd.params();          % 题目给定的物理参数
Ns   = [1e8, 1e9, 1e10];      % 要比较的三个脉冲数（题目指定的）
cols = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.35 0.60 0.25];   % 三条线的颜色（RGB）
mks  = {'o', 's', '^'};                                      % 三条线的数据点形状

% 建一个统一风格的图窗：白底、尺寸 800×560，返回图窗句柄 f 和坐标轴句柄 ax
[f, ax] = newFig(800, 560);

% 收尾保险：无论脚本是正常结束、报错、还是被用户取消，
% 都自动把图窗关掉，免得在后台留下一堆看不见的窗口。
% MATLAB 语法：onCleanup 的对象在函数退出时自动执行括号里那件事。
cleanup = onCleanup(@() closeQuietly(f));

res = cell(1, numel(Ns));     % 装三条曲线的计算结果（cell 数组，每个格子放一个结构体）
for k = 1:numel(Ns)
    % spec 就是「说明书」：用什么方法、多少脉冲、多远、要不要优化
    spec = struct('method', 'gauss', 'N', Ns(k), 'eps', 1e-7, ...
                  'L', [0 300 1], 'opt', 'none');
    % 进度回调：把「第 k 条曲线的进度」换算成「整张图的总进度」再报上去
    spec.onProgress = @(frc, msg) taskReport(opt, ((k - 1) + frc) / numel(Ns), ...
                                            ['任务1 · ' msg]);
    res{k} = qkd.runCase(p, spec);     % ★ 真正干活的一行

    % semilogy：纵轴取对数。为什么？密钥率从 1e-2 掉到 1e-12，跨十几个数量级，
    % 用线性轴的话远端全挤成一条贴着 0 的线，什么都看不见。
    semilogy(ax, res{k}.L, res{k}.R, '-', 'Color', cols(k, :), 'LineWidth', 1.9, ...
             'Marker', mks{k}, 'MarkerSize', 4, ...
             'MarkerIndices', 1:25:numel(res{k}.L), ...   % 每 25 个点画一个标记，免得糊成一片
             'DisplayName', sprintf('N = 10^{%d}   (最远 %.0f km)', ...
                                    round(log10(Ns(k))), res{k}.Lmax));   % 图例文字
end

set(ax, 'XLim', [0 220], 'YLim', [1e-12 5e-2]);   % 固定坐标范围，三张图才好对比
xlabel(ax, '传输距离 L (km)');
ylabel(ax, '安全密钥率 R (bit/pulse)');
title(ax, '高斯统计起伏：不同发射脉冲数下的密钥率（未优化）');
legend(ax, 'Location', 'northeast', 'FontName', cjkFont());   % 中文字体要显式给，否则可能是方框
grid(ax, 'on');

% 存盘：PNG（300dpi，给报告用）+ .fig（可再编辑）+ CSV（数值可复查）
saveResult(f, 'fig1_gauss_threeN', res{end});   % 用最后一条曲线的数据写 CSV

taskReport(opt, 1, '任务1 完成');
fprintf('图1 完成：N=1e8 Lmax=%.0f km, N=1e9 Lmax=%.0f km, N=1e10 Lmax=%.0f km\n', ...
        res{1}.Lmax, res{2}.Lmax, res{3}.Lmax);
end

% ---------------------------------------------------------------- helpers
function taskReport(opt, frac, msg)
% 统一的进度上报：opt 里没有 onProgress 就什么也不做（命令行调用时就是这样）
if isfield(opt, 'onProgress') && ~isempty(opt.onProgress)
    opt.onProgress(min(max(frac, 0), 1), msg);
end
end

function closeQuietly(h)
% 关图窗时先检查它还在不在（可能已经被别处关掉了），避免报错
for k = 1:numel(h)
    if isvalid(h(k))
        close(h(k));
    end
end
end
