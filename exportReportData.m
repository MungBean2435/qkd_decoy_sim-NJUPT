function exportReportData()
%EXPORTREPORTDATA 为课程设计报告导出数值表（CSV，UTF-8）
%
%   图1（3 条曲线 × 301 点，不优化）与图2（3 种方法 × 61 个候选）都很便宜，
%   直接重算即可；图3 的全局优化是 301 个距离点逐个做四参数搜索（实测约 20 s），
%   而 run_task3 已经把同一条曲线写进了 results/fig3_chernoff_global.csv，
%   所以这里优先复用那份结果，避免把最贵的一段算两遍。
%
%   复用有两个前提，任一不满足就退回完整重算（宁可慢，也不能出错的表）：
%     1) CSV 比 +qkd/ 下任何一个源文件都新 —— 物理模型改过就必须重算；
%     2) CSV 的网格仍是 L = 0:1:300 共 301 点、且 6 列齐全。
%   注意：若只改了 run_task3 里的优化设置（npop/ngen），本检查发现不了，
%   请重新跑一次 run_task3 再导出。

root = fileparts(mfilename('fullpath'));
out  = fullfile(root, 'results', 'report_tables.csv');
fid  = fopen(out, 'w', 'n', 'UTF-8');
c    = onCleanup(@() fclose(fid));

p = qkd.params();
Lv = [25 50 75 100 125 150];

fprintf(fid, 'section,curve,L_km,R_per_pulse,Lmax_km\n');

% ---- 图1：高斯，N = 1e8/1e9/1e10 ----
for N = [1e8, 1e9, 1e10]
    spec = struct('method', 'gauss', 'N', N, 'eps', 1e-7, 'L', [0 300 1], 'opt', 'none');
    o = qkd.runCase(p, spec);
    for L0 = Lv
        fprintf(fid, 'fig1,gauss_N%.0e,%d,%.4e,%.0f\n', N, L0, o.R(L0 + 1), o.Lmax);
    end
end

% ---- 图2：三种方法，N=1e9，仅优化 u ----
for m = {'gauss', 'hoeffding', 'chernoff'}
    spec = struct('method', m{1}, 'N', 1e9, 'eps', 1e-7, 'L', [0 300 1], 'opt', 'u', ...
                  'optU', struct('lb', 0.10, 'ub', 1.30, 'n', 61, 'mode', 'perDistance'));
    o = qkd.runCase(p, spec);
    for L0 = Lv
        fprintf(fid, 'fig2,%s,%d,%.4e,%.0f\n', m{1}, L0, o.R(L0 + 1), o.Lmax);
    end
    fprintf(fid, 'fig2u,%s,100,%.4f,%.0f\n', m{1}, o.u(101), o.Lmax);
end

% ---- 图3：切尔诺夫，N=1e9，全局优化 ----
specB = struct('method', 'chernoff', 'N', 1e9, 'eps', 1e-7, 'L', [0 300 1], 'opt', 'none');
b = qkd.runCase(p, specB);                       % 基准曲线，便宜，仍现算

[g, src] = fig3Optimized(root, p);
fprintf('  图3 全局优化数据：%s\n', src);

for L0 = Lv
    fprintf(fid, 'fig3_base,chernoff_none,%d,%.4e,%.0f\n', L0, b.R(L0 + 1), b.Lmax);
    fprintf(fid, 'fig3_opt,chernoff_global,%d,%.4e,%.0f\n', L0, g.R(L0 + 1), g.Lmax);
end
for L0 = [50 100 150]
    fprintf(fid, 'fig3par,%d,%.3f,%.3f,%.2f,%.2f\n', L0, g.u(L0 + 1), g.v(L0 + 1), ...
            g.Pu(L0 + 1), g.Pv(L0 + 1));
end

fprintf('导出完成: %s\n', out);
end

% ======================================================================
% 图3 优化曲线：优先复用 run_task3 的 CSV，否则重算
% ======================================================================

function [g, src] = fig3Optimized(root, p)
csvPath = fullfile(root, 'results', 'fig3_chernoff_global.csv');

g = [];
if exist(csvPath, 'file') && csvIsFresh(csvPath, root)
    g = readCurveCsv(csvPath);
end

if isempty(g)
    specG = struct('method', 'chernoff', 'N', 1e9, 'eps', 1e-7, 'L', [0 300 1], ...
                   'opt', 'global', 'optG', struct('npop', 30, 'ngen', 40));
    g   = qkd.runCase(p, specG);
    src = '重算（无可用 CSV）';
else
    src = '复用 results/fig3_chernoff_global.csv';
end
end

function ok = csvIsFresh(csvPath, root)
% CSV 必须不早于 +qkd/ 下的所有源文件；物理公式改过就必须重算
d = dir(csvPath);
ok = ~isempty(d);
if ~ok
    return
end
srcs = dir(fullfile(root, '+qkd', '*.m'));
for k = 1:numel(srcs)
    if srcs(k).datenum > d.datenum
        ok = false;
        return
    end
end
end

function c = readCurveCsv(csvPath)
% 读 saveResult 写出的表：L_km,R_per_pulse,u,v,Pu,Pv
c = [];
try
    M = dlmread(csvPath, ',', 1, 0);
catch
    return
end
if size(M, 2) < 6 || size(M, 1) ~= 301
    return
end
L = M(:, 1)';
if L(1) ~= 0 || L(end) ~= 300 || abs(L(2) - L(1) - 1) > 1e-9
    return          % 网格被改过（例如步长不同），交给重算
end

c      = struct();
c.L    = L;
c.R    = M(:, 2)';
c.u    = M(:, 3)';
c.v    = M(:, 4)';
c.Pu   = M(:, 5)';
c.Pv   = M(:, 6)';

idx = find(c.R > 0, 1, 'last');
if isempty(idx)
    c.Lmax = NaN;
else
    c.Lmax = c.L(idx);
end
end
