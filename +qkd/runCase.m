function out = runCase(p, spec)
%RUNCASE 一条密钥率曲线的统一入口（GUI 与脚本都只调用本函数）
%
%   out = qkd.runCase(p, spec)
%
%   p     : qkd.params() 返回的参数结构体（可被外部改写后传入）
%   spec  : 计算规格
%           .method  'gauss' | 'hoeffding' | 'chernoff'
%           .N       发射脉冲数
%           .eps     失败概率（默认 1e-7）
%           .L       [起点 终点 步长]，单位 km
%           .opt     'none' | 'u' | 'global'
%           .optU    （opt='u' 时）结构体：.lb .ub .n .mode('perDistance'|'fixed')
%           .optG    （opt='global' 时）结构体：.npop .ngen
%
%   out : .L .R .u .v .Pu .Pv .Lmax .method .N .opt .spec .p
%
%   本函数是“计算内核”与“界面/绘图”之间唯一的接口：
%   GUI 只是收集 spec → 调用 runCase → 画 out，不含任何物理公式。

if ~isfield(spec, 'eps') || isempty(spec.eps), spec.eps = 1e-7; end
if ~isfield(spec, 'opt') || isempty(spec.opt), spec.opt = 'none'; end

L = spec.L(1) : spec.L(3) : spec.L(2);
n = numel(L);

% 进度回调采样步长：逐点扫描时最多刷新约 50 次，避免界面被回调拖慢。
% spec.onProgress 为可选字段：命令行调用不传时行为与本函数原实现完全一致。
stride = max(1, floor(n / 50));

out = struct();
out.L   = L;
out.R   = zeros(1, n);
out.u   = p.u * ones(1, n);
out.v   = p.v * ones(1, n);
out.Pu  = p.Pu * ones(1, n);
out.Pv  = p.Pv * ones(1, n);
out.method = spec.method;
out.N   = spec.N;
out.eps = spec.eps;
out.opt = spec.opt;
out.spec = spec;
out.p    = p;

switch lower(spec.opt)

    case 'none'
        % 固定参数，仅扫描距离
        for i = 1:n
            out.R(i) = rateFor(p, L(i), spec, p.u, p.v, p.Pu, p.Pv);
            if i == 1 || i == n || mod(i, stride) == 0
                notifyProgress(spec, i / n, ...
                    sprintf('扫描距离 L = %.0f km（%d/%d）', L(i), i, n));
            end
        end

    case 'u'
        % 只优化信号态光强 u（v、P_u、P_v 固定）
        ug = linspace(spec.optU.lb, spec.optU.ub, spec.optU.n);

        if strcmpi(spec.optU.mode, 'perDistance')
            % 逐距离最优：每个距离点各自取使 R 最大的 u
            for i = 1:n
                Rv = rateFor(p, L(i), spec, ug, p.v, p.Pu, p.Pv);
                [rmax, k] = max(Rv);
                out.R(i) = rmax;
                out.u(i) = ug(k);
                if i == 1 || i == n || mod(i, stride) == 0
                    notifyProgress(spec, i / n, ...
                        sprintf('逐距离优化 u：L = %.0f km（%d/%d）', L(i), i, n));
                end
            end
        else
            % 整段统一：一个 u 用到底，取使最远成码距离最大的 u
            notifyProgress(spec, 0, sprintf('固定 u 批量扫描（%d 个候选）…', numel(ug)));
            Rm = zeros(numel(ug), n);
            for i = 1:n
                Rm(:, i) = rateFor(p, L(i), spec, ug, p.v, p.Pu, p.Pv);
            end
            [~, uIdx] = max(sum(Rm > 0, 2));
            out.R = Rm(uIdx, :);
            out.u = ug(uIdx) * ones(1, n);
            notifyProgress(spec, 1, sprintf('固定 u 扫描完成（u = %.2f）', out.u(1)));
        end

    case 'global'
        % 联合优化 (u, v, P_u, P_v)
        if ~isfield(spec, 'optG') || isempty(spec.optG)
            spec.optG = struct('npop', 40, 'ngen', 60);
        end
        for i = 1:n
            [xb, fb] = optimizeGlobal(p, L(i), spec, spec.optG);
            out.R(i)  = fb;
            out.u(i)  = xb(1);                 % u
            out.v(i)  = xb(1) * xb(2);         % v = u * ratio
            out.Pu(i) = xb(3);                 % P_u
            out.Pv(i) = xb(4);                 % P_v
            % 全局优化单点耗时远高于扫描，逐点上报以保证取消足够及时
            notifyProgress(spec, i / n, ...
                sprintf('全局优化 (u, v, P_u, P_v)：L = %.0f km（%d/%d）', L(i), i, n));
        end

    otherwise
        error('qkd:runCase:badOpt', '未知优化模式: %s', spec.opt);
end

% 无密钥区（R = 0）不给出“最优参数”，置 NaN 以免图上出现无意义的跳变
if ~strcmpi(out.opt, 'none')
    dead = out.R <= 0;
    out.u(dead)  = NaN;   out.v(dead)  = NaN;
    out.Pu(dead) = NaN;   out.Pv(dead) = NaN;
end

% 最远成码距离（R > 0 的最后一个距离点）
idx = find(out.R > 0, 1, 'last');
if isempty(idx)
    out.Lmax = NaN;
else
    out.Lmax = out.L(idx);
end

end

% ======================================================================
% 局部函数：参数改写 + 目标函数 + 差分进化
% ======================================================================

function R = rateFor(p, L, spec, u, v, Pu, Pv)
% 把待优化的参数写回结构体后调用内核；u/v/Pu/Pv 可为向量（候选群）
q = p;
q.u  = u;
q.v  = v;
q.Pu = Pu;
q.Pv = Pv;
q.P0 = 1 - Pu - Pv;
R = qkd.keyRateAt(q, L, spec);
end

function R = objFun(p, L, spec, X)
% X 的每一行是一个候选： [u, v/u, P_u, P_v]
u  = X(:, 1);
v  = X(:, 1) .* X(:, 2);
Pu = X(:, 3);
Pv = X(:, 4);
R  = rateFor(p, L, spec, u, v, Pu, Pv);
% 物理可行性约束（不满足者直接置 0，等价于惩罚）
bad = (v >= u) | (Pu + Pv > 0.95) | (Pu <= 0) | (Pv <= 0) | (u <= v);
R(bad) = 0;
R(~isfinite(R)) = 0;
end

function [xb, fb] = optimizeGlobal(p, L, spec, opt)
% 带边界约束的差分进化（最大化密钥率）
lb  = [ 0.10,  0.02, 0.05, 0.02];
ub  = [ 1.40,  0.90, 0.90, 0.90];
Dm  = numel(lb);
rng(20260101);                      % 固定随机种子，保证结果可复现

pop = lb + rand(opt.npop, Dm) .* (ub - lb);
fit = objFun(p, L, spec, pop);

for g = 1:opt.ngen
    for i = 1:opt.npop
        idx = randperm(opt.npop, 3);
        mut = pop(idx(1), :) + 0.6 * (pop(idx(2), :) - pop(idx(3), :));
        mut = min(max(mut, lb), ub);
        cross = rand(1, Dm) < 0.7;
        cross(randi(Dm)) = true;
        trial = pop(i, :);
        trial(cross) = mut(cross);
        ft = objFun(p, L, spec, trial);
        if ft > fit(i)
            pop(i, :) = trial;
            fit(i) = ft;
        end
    end
end

[fb, k] = max(fit);
xb = pop(k, :);

% 局部细化：在当前最优点附近做坐标下降
step = 0.05 * (ub - lb);
for iter = 1:30
    improved = false;
    for d = 1:Dm
        for s = [-1, 1]
            cand = xb;
            cand(d) = min(max(cand(d) + s * step(d), lb(d)), ub(d));
            fc = objFun(p, L, spec, cand);
            if fc > fb
                xb = cand; fb = fc; improved = true;
            end
        end
    end
    if ~improved
        step = step * 0.5;
        if all(step < 1e-4), break; end
    end
end

end

% ======================================================================
% 可选的进度回调（界面层通过 spec.onProgress 注入）
% ======================================================================

function notifyProgress(spec, frac, msg)
%NOTIFYPROGRESS 若 spec 带 onProgress，则上报归一化进度与提示文字。
%
%   回调抛出的异常（例如用户取消）不在此捕获，直接向上传播，
%   由调用方（QKDApp）识别并收尾。

if isfield(spec, 'onProgress') && ~isempty(spec.onProgress)
    spec.onProgress(min(max(frac, 0), 1), msg);
end
end
