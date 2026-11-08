function ok = runTests()
%RUNTESTS 回归自检：核对关键数值，失败时抛错（供本地与 CI 调用）
%
%   用法（在 qkd_decoy_sim 目录）：
%       runTests
%   或从上一级目录：
%       addpath(genpath('qkd_decoy_sim')); runTests
%
%   断言的是“基准值”，来自 results/ 中已确认的正确结果。
%   改动物理模型时这些数字必然变化——那是有意修改，
%   请同时更新本文的金标准，并在 PR 里说明物理依据。

root = fileparts(mfilename('fullpath'));
addpath(genpath(root));

p  = qkd.params();
ok = true;

% ---- 参数与派生量 ----
ok = check(ok, 'P0 = 0.1',        p.P0, 0.1, 1e-12);
ok = check(ok, 'Y0 = 2d(1-d)',    p.Y0, 2 * 1e-6 * (1 - 1e-6), 1e-18);

% ---- 三种方法的关键数值（N = 1e9, eps = 1e-7）----
%   列：[R(0)  R(50)  R(100)  Lmax]
golden = struct( ...
    'gauss',     [1.522185154962e-02, 1.416636460921e-03, 1.314340882149e-04, 176], ...
    'hoeffding', [1.474999347927e-02, 1.268440071853e-03, 9.087648408323e-05, 150], ...
    'chernoff',  [1.513901424926e-02, 1.389369463380e-03, 1.220330769186e-04, 164]);

names = fieldnames(golden);
for k = 1:numel(names)
    m = names{k};
    spec = struct('method', m, 'N', 1e9, 'eps', 1e-7, ...
                  'L', [0 200 1], 'opt', 'none');
    out = qkd.runCase(p, spec);
    g   = golden.(m);
    ok = check(ok, [m ' R(0)'],    out.R(1),   g(1), 1e-9);
    ok = check(ok, [m ' R(50)'],   out.R(51),  g(2), 1e-9);
    ok = check(ok, [m ' R(100)'],  out.R(101), g(3), 1e-9);
    ok = check(ok, [m ' Lmax'],    out.Lmax,   g(4), 0);
end

% ---- 不同发射脉冲数的有限长趋势：N 越大，最远距离越远 ----
lm = zeros(1, 3);
for k = 1:3
    Ns = [1e8 1e9 1e10];
    spec = struct('method', 'gauss', 'N', Ns(k), 'eps', 1e-7, ...
                  'L', [0 300 1], 'opt', 'none');
    out = qkd.runCase(p, spec);
    lm(k) = out.Lmax;
end
ok = checkLogical(ok, 'Lmax 随 N 单调递增', all(diff(lm) > 0));

% ---- 优化不得劣于基准 ----
specU = struct('method', 'chernoff', 'N', 1e9, 'eps', 1e-7, 'L', [100 100 1], ...
               'opt', 'u', 'optU', struct('lb', 0.1, 'ub', 1.3, 'n', 61, 'mode', 'perDistance'));
oU = qkd.runCase(p, specU);
specB = struct('method', 'chernoff', 'N', 1e9, 'eps', 1e-7, 'L', [100 100 1], 'opt', 'none');
oB = qkd.runCase(p, specB);
ok = checkLogical(ok, '仅优化 u 不劣于基准', oU.R(1) >= oB.R(1) * 0.999);

specG = struct('method', 'chernoff', 'N', 1e9, 'eps', 1e-7, 'L', [100 100 1], ...
               'opt', 'global', 'optG', struct('npop', 20, 'ngen', 25));
oG = qkd.runCase(p, specG);
ok = checkLogical(ok, '全局优化不劣于仅优化 u', oG.R(1) >= oU.R(1) * 0.999);

% ---- 边界：无正密钥区应返回 0，而不是 NaN / 负数 ----
specFar = struct('method', 'hoeffding', 'N', 1e8, 'eps', 1e-7, ...
                 'L', [400 400 1], 'opt', 'none');
oFar = qkd.runCase(p, specFar);
ok = checkLogical(ok, '超远距离 R 有限且非负', isfinite(oFar.R(1)) && oFar.R(1) >= 0);

fprintf('\n');
if ok
    fprintf('全部自检通过。\n');
else
    error('qkd:runTests:failed', '自检未通过，见上方 FAIL 行。');
end
end

% ---------------------------------------------------------------- helpers
function ok = check(ok, name, got, want, tol)
if abs(got - want) <= tol
    fprintf('  PASS  %-24s = %.12g\n', name, got);
else
    fprintf('  FAIL  %-24s = %.12g  (期望 %.12g, 容差 %g)\n', name, got, want, tol);
    ok = false;
end
end

function ok = checkLogical(ok, name, cond)
if cond
    fprintf('  PASS  %s\n', name);
else
    fprintf('  FAIL  %s\n', name);
    ok = false;
end
end
