function res = run_task3(opt)
%RUN_TASK3 任务 3（提高项）：切尔诺夫起伏下，四个参数一起优化，能传多远？
%
%   题目要求（提高项）：切尔诺夫起伏分析方法下，N=10^9 全局优化时
%                       密钥率随传输距离变化的图像。

if nargin < 1 || isempty(opt)
    opt = struct();
end

p  = qkd.params();
N  = 1e9;
[f, ax0]  = newFig(1200, 780);
[f2, ax2] = newFig(820, 520);
delete(ax0);                       
cleanup   = onCleanup(@() closeQuietly([f f2]));  

% ---- 第一步：先画基准线（不优化），后面才有「优化前/后」的对比 ----
specB = struct('method', 'chernoff', 'N', N, 'eps', 1e-7, 'L', [0 300 1], 'opt', 'none');
specB.onProgress = @(frc, msg) taskReport(opt, 0.02 * frc, ['任务3 · 基准 · ' msg]);
b = qkd.runCase(p, specB);

% ---- 第二步：全局优化（这一步最慢，约占整个任务 3 的 96% 时间）----
specG = struct('method', 'chernoff', 'N', N, 'eps', 1e-7, 'L', [0 300 1], ...
               'opt', 'global', 'optG', struct('npop', 30, 'ngen', 40));
specG.onProgress = @(frc, msg) taskReport(opt, 0.02 + 0.96 * frc, ['任务3 · 全局优化 · ' msg]);
g = qkd.runCase(p, specG);

grey   = [0.45 0.45 0.45];
orange = [0.85 0.33 0.10];
green  = [0.35 0.60 0.25];

Rb = b.R;  Rb(Rb <= 0) = NaN;
Rg = g.R;  Rg(Rg <= 0) = NaN;

a1 = panel(f, [0.065 0.545 0.385 0.345], true);
a2 = panel(f, [0.565 0.545 0.385 0.345], true);
a3 = panel(f, [0.095 0.085 0.820 0.315], false);

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

win = b.L >= 155 & b.L <= 175;
vv  = [Rb(win), Rg(win)];
vv  = vv(isfinite(vv) & vv > 0);
if isempty(vv)
    ylo = 1e-9;  yhi = 1e-5;
else
    ylo = min(vv) / 1.6;
    yhi = max(vv) * 1.6;
end

semilogy(a2, b.L, Rb, '--', 'Color', grey, 'LineWidth', 1.6);
semilogy(a2, g.L, Rg, '-', 'Color', orange, 'LineWidth', 2.0);

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
ax = axes('Parent', f, 'Units', 'normalized', 'Position', pos);
hold(ax, 'on');
set(ax, 'FontName', cjkFont(), 'FontSize', 10, 'LineWidth', 1.0, ...
        'Box', 'on', 'TickDir', 'out', 'XGrid', 'on', 'YGrid', 'on', ...
        'GridAlpha', 0.15, 'XMinorGrid', 'off', 'YMinorGrid', 'off');
if useLog
    set(ax, 'YScale', 'log');
end
end
