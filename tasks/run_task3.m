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
%     fig3_chernoff_global  优化前 vs 优化后（三联图：全景 / 尾部放大 / 增益倍数）
%     fig3b_optimal_params  四个最优参数各自随距离怎么变（理解题）
%
%  为什么主图要拆成三联？
%  实测下来，全局优化相对不优化只快 1.1–1.6 倍、最远只多 7 km（164→171）。
%  把这些数字放在一张横轴 220 km、纵轴跨十个数量级的单图里，肉眼几乎分不出来。
%  三联图各自负责一件事：
%     ① 全景 —— 交代两条曲线的整体走势，并标出放大区；
%     ② 尾部 —— 把 155–175 km 拉开，直接看出「灰线在 164 断、橙线到 171」；
%     ③ 倍数 —— 把「同一距离上快多少」单独画成一条 1.1–1.6 的曲线。
%  计算部分一行没改（仍是同一份 qkd.runCase 结果），这一版只改呈现方式。
% ------------------------------------------------------------------------

if nargin < 1 || isempty(opt)
    opt = struct();
end

p  = qkd.params();
N  = 1e9;
[f, ax0]  = newFig(1200, 780);
[f2, ax2] = newFig(820, 520);
delete(ax0);                       % 三联图要自己摆三个轴，先删掉 newFig 的默认单轴
cleanup   = onCleanup(@() closeQuietly([f f2]));   % 取消/报错时也关掉图窗

% ---- 第一步：先画基准线（不优化），后面才有「优化前/后」的对比 ----
specB = struct('method', 'chernoff', 'N', N, 'eps', 1e-7, 'L', [0 300 1], 'opt', 'none');
specB.onProgress = @(frc, msg) taskReport(opt, 0.02 * frc, ['任务3 · 基准 · ' msg]);
b = qkd.runCase(p, specB);

% ---- 第二步：全局优化（这一步最慢，约占整个任务 3 的 96% 时间）----
specG = struct('method', 'chernoff', 'N', N, 'eps', 1e-7, 'L', [0 300 1], ...
               'opt', 'global', 'optG', struct('npop', 30, 'ngen', 40));
%   npop：每一代撒多少个候选参数（30 个）
%   ngen：一共进化多少代（40 代）
%   两个数越大越准，也越慢。自检里会调小，正式出图才用这个配置。
specG.onProgress = @(frc, msg) taskReport(opt, 0.02 + 0.96 * frc, ['任务3 · 全局优化 · ' msg]);
g = qkd.runCase(p, specG);

% ======================================================================
% 第三步：画三联对比图（本版唯一的改动都集中在这一段）
% ======================================================================
grey   = [0.45 0.45 0.45];      % 基准线
orange = [0.85 0.33 0.10];      % 优化线
green  = [0.35 0.60 0.25];      % 增益曲线

% 对数纵轴上 log(0) 没法画。把 R<=0 的点置成 NaN，曲线就会在
% 「最后一个还有正密钥的距离」干净地收尾，而不是垂直掉到图底。
% 注意：这只影响绘图，CSV 里保存的仍是原始 R 值（下面的 saveResult 用的是 g）。
Rb = b.R;  Rb(Rb <= 0) = NaN;
Rg = g.R;  Rg(Rg <= 0) = NaN;

a1 = panel(f, [0.065 0.545 0.385 0.345], true);    % ① 全景
a2 = panel(f, [0.565 0.545 0.385 0.345], true);    % ② 尾部放大
a3 = panel(f, [0.095 0.085 0.820 0.315], false);   % ③ 增益倍数

% ---- 面板 ①：全景（0–220 km，纵轴对数）----
% 灰带标出面板 ② 要放大的区间；先画 patch 再画曲线，曲线才压在上面。
patch(a1, [148 178 178 148], [1e-9 1e-9 5e-2 5e-2], [0.85 0.85 0.85], ...
      'FaceAlpha', 0.35, 'EdgeColor', 'none', 'HandleVisibility', 'off');
semilogy(a1, b.L, Rb, '--', 'Color', grey, 'LineWidth', 1.6, ...
         'DisplayName', sprintf('未优化（最远 %.0f km）', b.Lmax));
semilogy(a1, g.L, Rg, '-', 'Color', orange, 'LineWidth', 2.0, ...
         'DisplayName', sprintf('全局优化（最远 %.0f km）', g.Lmax));
set(a1, 'XLim', [0 220], 'YLim', [1e-9 5e-2], 'XTick', 0:50:200, ...
        'YTick', [1e-9 1e-7 1e-5 1e-3 1e-2]);
xlabel(a1, '传输距离 L (km)');
ylabel(a1, 'R (bit/pulse)');
title(a1, '① 全景（灰带为放大区）');
legend(a1, 'Location', 'southwest', 'FontName', cjkFont());

% ---- 面板 ②：尾部放大 155–175 km ----
% 纵轴范围按窗口内的有效值自动取，上下各留 1.6 倍余量。
% 这样两条曲线能撑满画布，0.2 个数量级的差距才看得见。
win = b.L >= 155 & b.L <= 175;
vv  = [Rb(win), Rg(win)];
vv  = vv(isfinite(vv) & vv > 0);
if isempty(vv)
    ylo = 1e-9;  yhi = 1e-5;        % 极端参数下窗口内没有密钥时的兜底
else
    ylo = min(vv) / 1.6;
    yhi = max(vv) * 1.6;
end

semilogy(a2, b.L, Rb, '--', 'Color', grey, 'LineWidth', 1.6);
semilogy(a2, g.L, Rg, '-', 'Color', orange, 'LineWidth', 2.0);

% 两条曲线各自的「最后一个正密钥点」：倒三角 + 点状竖线，一眼看出差 7 km
if isfinite(b.Lmax)
    xline(a2, b.Lmax, ':', 'Color', grey, 'LineWidth', 1.2);
    plot(a2, b.Lmax, Rb(b.L == b.Lmax), 'v', 'Color', grey, ...
         'MarkerFaceColor', grey, 'MarkerSize', 7);
end
if isfinite(g.Lmax)
    xline(a2, g.Lmax, ':', 'Color', orange, 'LineWidth', 1.2);
    plot(a2, g.Lmax, Rg(g.L == g.Lmax), 'v', 'Color', orange, ...
         'MarkerFaceColor', orange, 'MarkerSize', 7);
end

set(a2, 'XLim', [155 175], 'YLim', [ylo yhi], 'XTick', 155:5:175);
xlabel(a2, '传输距离 L (km)');
ylabel(a2, 'R (bit/pulse)');
if isfinite(b.Lmax) && isfinite(g.Lmax)
    title(a2, sprintf('② 尾部放大：%.0f → %.0f km（+%.0f km）', ...
          b.Lmax, g.Lmax, g.Lmax - b.Lmax));
else
    title(a2, '② 尾部放大 155–175 km');
end

% ---- 面板 ③：同距离下的增益倍数 R_opt / R_base ----
% 只保留两边都有正密钥的点；基准为 0 的地方比值会发散，没有意义。
ratio = g.R ./ b.R;
ratio(b.R <= 0 | g.R <= 0) = NaN;

plot(a3, g.L, ratio, '-', 'Color', green, 'LineWidth', 1.9);
yline(a3, 1, '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.0);
set(a3, 'XLim', [0 160], 'YLim', [0.9 1.9], 'XTick', 0:20:160);
xlabel(a3, '传输距离 L (km)');
ylabel(a3, 'R_{opt} / R_{base}');
title(a3, '③ 优化增益 R_{opt}/R_{base}');

if all(~isfinite(ratio))
    text(a3, 10, 1.4, '窗口内无可比数据', 'FontName', cjkFont());
else
    % 起点和 140 km 两处标数值；中途只靠曲线本身读
    r0 = ratio(find(b.L == 0, 1));
    if isfinite(r0)
        text(a3, 2, r0 + 0.04, sprintf('×%.2f @ 0 km', r0), ...
             'FontName', cjkFont(), 'FontSize', 9);
    end
    i140 = find(b.L == 140, 1);
    if ~isempty(i140) && isfinite(ratio(i140))
        text(a3, 126, 1.08, sprintf('×%.2f @ 140 km', ratio(i140)), ...
             'FontName', cjkFont(), 'FontSize', 9);
    end
    text(a3, 4, 0.94, '注：160 km 之后基准曲线迅速归零，比值发散，看面板②', ...
         'FontName', cjkFont(), 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
end

sgtitle(f, '切尔诺夫：全局优化 (u, v, P_u, P_v) 前后对比（N = 10^9）', ...
        'FontName', cjkFont(), 'FontSize', 11);

saveResult(f, 'fig3_chernoff_global', g);

% ---- 第四步：附加图——四个最优参数随距离的演化（本版未改动）----
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

function ax = panel(f, pos, useLog)
%PANEL 在三联图里造一个风格统一的坐标轴
%   newFig 只会造一个轴，多面板就得自己摆位置；这里把 newFig 的「装修」
%   复制一份，保证三联图和工程里其它图看起来是同一套样式。
ax = axes('Parent', f, 'Units', 'normalized', 'Position', pos);
hold(ax, 'on');
set(ax, 'FontName', cjkFont(), 'FontSize', 10, 'LineWidth', 1.0, ...
        'Box', 'on', 'TickDir', 'out', 'XGrid', 'on', 'YGrid', 'on', ...
        'GridAlpha', 0.15, 'XMinorGrid', 'off', 'YMinorGrid', 'off');
if useLog
    set(ax, 'YScale', 'log');
end
end
