function res = run_task2()
%RUN_TASK2 图2：高斯 / 霍夫丁 / 切尔诺夫，N = 1e9，仅优化信号态 u
%
%   题目要求：画出高斯、霍夫丁、切尔诺夫三种方法下，N=10^9 时
%             优化信号态 u 后密钥率随传输距离变化的图像。
%
%   优化口径：逐距离最优（每个距离点取使 R 最大的 u），
%             曲线因此包住所有固定 u 的结果。

p    = qkd.params();
N    = 1e9;
meth = {'gauss', 'hoeffding', 'chernoff'};
labs = {'高斯 (Gaussian)', '霍夫丁 (Hoeffding)', '切尔诺夫 (Chernoff)'};
cols = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.35 0.60 0.25];
mks  = {'o', 's', '^'};

[f, ax] = newFig(800, 560);

res = cell(1, numel(meth));
for k = 1:numel(meth)
    spec = struct('method', meth{k}, 'N', N, 'eps', 1e-7, ...
                  'L', [0 300 1], 'opt', 'u', ...
                  'optU', struct('lb', 0.10, 'ub', 1.30, 'n', 61, 'mode', 'perDistance'));
    res{k} = qkd.runCase(p, spec);
    semilogy(ax, res{k}.L, res{k}.R, '-', 'Color', cols(k, :), 'LineWidth', 1.9, ...
             'Marker', mks{k}, 'MarkerSize', 4, 'MarkerIndices', 1:25:numel(res{k}.L), ...
             'DisplayName', sprintf('%s   (最远 %.0f km)', labs{k}, res{k}.Lmax));
end

set(ax, 'XLim', [0 210], 'YLim', [1e-12 5e-2]);
xlabel(ax, '传输距离 L (km)');
ylabel(ax, '安全密钥率 R (bit/pulse)');
title(ax, sprintf('N = 10^9 时三种统计起伏方法对比（逐距离优化信号态 u）'));
legend(ax, 'Location', 'northeast', 'FontName', 'Microsoft YaHei');
grid(ax, 'on');

saveResult(f, 'fig2_three_methods', res{end});

% 附加图：最优信号态光强 u*(L) 的演化
[f2, ax2] = newFig(760, 440);
set(ax2, 'YScale', 'linear');
for k = 1:numel(meth)
    plot(ax2, res{k}.L, res{k}.u, '-', 'Color', cols(k, :), 'LineWidth', 1.9, ...
         'DisplayName', labs{k});
end
set(ax2, 'XLim', [0 200], 'YLim', [0 1.4]);
xlabel(ax2, '传输距离 L (km)');
ylabel(ax2, '最优信号态光强 u^*');
title(ax2, '最优信号态光强随距离的演化');
legend(ax2, 'Location', 'northeast', 'FontName', 'Microsoft YaHei');
grid(ax2, 'on');
saveResult(f2, 'fig2b_optimal_u', res{end});

fprintf('图2 完成：gauss Lmax=%.0f, hoeffding Lmax=%.0f, chernoff Lmax=%.0f\n', ...
        res{1}.Lmax, res{2}.Lmax, res{3}.Lmax);
end
