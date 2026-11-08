function exportReportData()
%EXPORTREPORTDATA 为课程设计报告导出数值表（CSV，UTF-8）
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
b = qkd.runCase(p, specB);
specG = struct('method', 'chernoff', 'N', 1e9, 'eps', 1e-7, 'L', [0 300 1], ...
               'opt', 'global', 'optG', struct('npop', 30, 'ngen', 40));
g = qkd.runCase(p, specG);
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
