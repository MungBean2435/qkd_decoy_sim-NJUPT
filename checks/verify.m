function verify()
%VERIFY 一致性核查：优化结果不得低于对应基准，结果写入 UTF-8 日志
fid = fopen(fullfile(projectRoot(), 'results', 'verify.log'), 'w', 'n', 'UTF-8');
c = onCleanup(@() fclose(fid));

p = qkd.params();
lv = [30 60 90 120 150 180];

logf(fid, '=== 基准 vs 优化（N=1e9, eps=1e-7, chernoff）===\n');
base = struct('method', 'chernoff', 'N', 1e9, 'eps', 1e-7, 'L', [0 300 1], 'opt', 'none');
b = qkd.runCase(p, base);

gu = struct('method', 'gauss', 'N', 1e9, 'eps', 1e-7, 'L', [0 300 1], 'opt', 'none');
g = qkd.runCase(p, gu);

logf(fid, '%6s %14s %14s %14s\n', 'L(km)', 'chernoff基准', '高斯基准', '切尔诺夫/u');
for L0 = lv
    i = L0 + 1;
    uo = struct('method', 'chernoff', 'N', 1e9, 'eps', 1e-7, 'L', [L0 L0 1], ...
                'opt', 'u', 'optU', struct('lb', 0.1, 'ub', 1.3, 'n', 61, 'mode', 'perDistance'));
    o = qkd.runCase(p, uo);
    logf(fid, '%6.0f %14.4e %14.4e %14.4e (u*=%.2f)\n', L0, b.R(i), g.R(i), o.R(1), o.u(1));
end

logf(fid, '\n=== 全局优化是否优于“仅优化 u”（同一方法 chernoff）===\n');
for L0 = lv
    uo = struct('method', 'chernoff', 'N', 1e9, 'eps', 1e-7, 'L', [L0 L0 1], ...
                'opt', 'u', 'optU', struct('lb', 0.1, 'ub', 1.3, 'n', 61, 'mode', 'perDistance'));
    o1 = qkd.runCase(p, uo);
    go = struct('method', 'chernoff', 'N', 1e9, 'eps', 1e-7, 'L', [L0 L0 1], ...
                'opt', 'global', 'optG', struct('npop', 30, 'ngen', 40));
    o2 = qkd.runCase(p, go);
    flag = 'OK';
    if o2.R(1) < o1.R(1) * 0.999, flag = 'WORSE!'; end
    logf(fid, 'L=%3.0f  仅u=%.3e  全局=%.3e  [%s]  u*=%.2f v*=%.3f Pu*=%.2f Pv*=%.2f\n', ...
         L0, o1.R(1), o2.R(1), flag, o2.u(1), o2.v(1), o2.Pu(1), o2.Pv(1));
end
logf(fid, '\n完成\n');
end

function logf(fid, fmt, varargin)
fprintf(fid, fmt, varargin{:});
end
