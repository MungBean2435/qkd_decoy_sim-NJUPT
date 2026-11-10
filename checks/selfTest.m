function selfTest()
%SELFTEST 计算内核自检：不画图，只打印关键数值，用于核对公式链是否跑通
%
%   用法（在 qkd_decoy_sim 的上一级目录）：
%       addpath(genpath('qkd_decoy_sim')); selfTest

p = qkd.params();
fprintf('=== 参数自检 ===\n');
fprintf('P0 = 1 - Pu - Pv = %.3f （真空态概率）\n', p.P0);
fprintf('Y0 = 2d(1-d)     = %.3e\n\n', p.Y0);

fprintf('=== 任务1：高斯，不优化（u=0.5, v=0.1, Pu=0.6, Pv=0.3）===\n');
for N = [1e8, 1e9, 1e10]
    spec = struct('method', 'gauss', 'N', N, 'eps', 1e-7, ...
                  'L', [0 300 1], 'opt', 'none');
    out = qkd.runCase(p, spec);
    fprintf('  N=%-6.0e  Lmax=%4.0f km   R(0)=%.3e   R(100)=%.3e\n', ...
            N, out.Lmax, out.R(1), out.R(101));
end

fprintf('\n=== 任务2：N=1e9，仅优化 u（逐距离最优）===\n');
for m = {'gauss', 'hoeffding', 'chernoff'}
    spec = struct('method', m{1}, 'N', 1e9, 'eps', 1e-7, ...
                  'L', [0 300 1], 'opt', 'u', ...
                  'optU', struct('lb', 0.1, 'ub', 1.3, 'n', 61, 'mode', 'perDistance'));
    out = qkd.runCase(p, spec);
    fprintf('  %-10s Lmax=%4.0f km   u*(100km)=%.2f\n', m{1}, out.Lmax, out.u(101));
end

fprintf('\n=== 任务3：切尔诺夫 N=1e9 全局优化（抽样 3 个距离点，验证优化器）===\n');
for L0 = [50, 100, 150]
    spec = struct('method', 'chernoff', 'N', 1e9, 'eps', 1e-7, ...
                  'L', [L0 L0 1], 'opt', 'global', ...
                  'optG', struct('npop', 30, 'ngen', 40));
    out = qkd.runCase(p, spec);
    fprintf('  L=%3.0f km  R=%.3e  u*=%.3f v*=%.3f Pu*=%.2f Pv*=%.2f\n', ...
            L0, out.R(1), out.u(1), out.v(1), out.Pu(1), out.Pv(1));
end
fprintf('\n自检结束。\n');

end
