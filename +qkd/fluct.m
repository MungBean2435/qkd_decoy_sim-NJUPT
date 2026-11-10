function D = fluct(method, eps)
%FLUCT 三种有限长统计起伏方法的“偏差函数”工厂
%
%   D = qkd.fluct(method, eps)
%
%   method : 'gauss' | 'hoeffding' | 'chernoff'
%   eps    : 失败概率（默认 1e-7，与指导书 γ=5.3 对应）
%
%   三种方法只差“观测值 → 置信区间”这一步，因此统一成同一组接口：
%       [lo, hi] = D.Q (Q,  Nl, nW)   % 增益 Q_l 的上下界
%       [lo, hi] = D.T (T,  Nl, nW)   % 误码计数 T_l 的上下界
%       [lo, hi] = D.Y0(Y0, N0)       % 真空态响应率的上下界（真空不选基，单独处理）
%   其中 Nl 为该强度的基内脉冲数，nW 为该基内所有强度的观测总计数
%   （霍夫丁界按指导书 (3.33) 使用 nW）。
%
%   这样后端的 estimate.m 完全不关心用的是哪种方法，答辩讲解只需说：
%   “三种方案共用同一条估计链，区别只在这一个偏差函数”。

if nargin < 2 || isempty(eps)
    eps = 1e-7;
end

% ---- 缓存（与 cjkFont.m 的 persistent 用法一致）----
% estimate.m 每算一个距离点都会调一次本函数，而 method 与 eps 在一条曲线内
% 恒定，所以单槽缓存即可命中几乎全部调用，省掉每次重建 struct 与 3 个句柄。
% 句柄在创建时按值捕获 gamma/k/eps，缓存副本与新建副本行为完全一致。
persistent cacheKey cacheD
key = sprintf('%s|%.17g', lower(method), eps);
if ~isempty(cacheKey) && strcmp(cacheKey, key)
    D = cacheD;
    return
end

D.eps    = eps;
D.method = lower(method);

switch D.method
    case 'gauss'
        % (3.24)(3.25)：Δ = γ·sqrt(Q/N)，双边 Pr(|X-E|≥Δ) ≤ eps
        gamma = sqrt(2) * erfcinv(eps);
        D.name = 'Gaussian';
        D.desc = sprintf('高斯/中心极限定理：ΔQ=γ·sqrt(Q/N)，γ=%.3f (eps=%.0e)', gamma, eps);
        D.Q    = @(Q, Nl, nW) gaussBound(Q, Nl, gamma);
        D.T    = @(T, Nl, nW) gaussBound(T, Nl, gamma);
        D.Y0   = @(Y0, N0)    gaussBound(Y0, N0, gamma);

    case 'hoeffding'
        % (3.31)(3.33)：|Q* - Q| = sqrt(nW/2·ln(1/eps))/Nl，对基内总计数 nW 定界
        k = sqrt(0.5 * log(1 / eps));
        D.name = 'Hoeffding';
        D.desc = sprintf('霍夫丁：|ΔQ|=sqrt(nW·ln(1/eps)/2)/N，k=%.3f', k);
        D.Q    = @(Q, Nl, nW) hoeffBound(Q, Nl, nW, k);
        D.T    = @(T, Nl, nW) hoeffBound(T, Nl, nW, k);
        D.Y0   = @(Y0, N0)    hoeffBoundY0(Y0, N0, k);

    case 'chernoff'
        % (3.37)：E(x)=x+δ，δ∈[-Δ,Δ̂]，Δ=g(x,eps^4/16)，Δ̂=g(x,eps^1.5)
        D.name = 'Chernoff';
        D.desc = sprintf('切尔诺夫：Δ=sqrt(2x·ln(16/eps^4))，Δ̂=sqrt(2x·ln(eps^{-1.5}))，eps=%.0e', eps);
        D.Q    = @(Q, Nl, nW) chernoffBound(Q, Nl, eps);
        D.T    = @(T, Nl, nW) chernoffBound(T, Nl, eps);
        D.Y0   = @(Y0, N0)    chernoffBound(Y0, N0, eps);

    otherwise
        error('qkd:fluct:badMethod', '未知统计起伏方法: %s', method);
end

% 构建成功后入槽；出错路径不入槽，避免把半个 D 留给下一次调用
cacheKey = key;
cacheD   = D;

end

% ======================================================================
% 各方法的偏差计算（局部函数）
% ======================================================================

function [lo, hi] = gaussBound(x, N, gamma)
% 相对形式 x*(1 ± γ/sqrt(xN))，等价于绝对形式 x ± γ·sqrt(x/N)
N   = max(N, realmin);
x   = max(x, 0);
dlt = gamma .* sqrt(x ./ N);
lo  = max(x - dlt, 0);
hi  = x + dlt;
end

function [lo, hi] = hoeffBound(x, N, nW, k)
% |ΔQ| = k·sqrt(nW)/N，k = sqrt(ln(1/eps)/2)
N   = max(N, realmin);
dlt = k .* sqrt(max(nW, 0)) ./ N;
lo  = max(x - dlt, 0);
hi  = x + dlt;
end

function [lo, hi] = hoeffBoundY0(Y0, N0, k)
% (3.35) 注：Y0^L = Y0 - (1/(N p0))·sqrt(Y0·N p0·ln(1/eps)/2)
N0  = max(N0, realmin);
dlt = k .* sqrt(max(Y0, 0) ./ N0);
lo  = max(Y0 - dlt, 0);
hi  = Y0 + dlt;
end

function [lo, hi] = chernoffBound(x, N, eps)
% 计数 x_obs = N·x，下界用 Δ=g(x,eps^4/16)，上界用 Δ̂=g(x,eps^1.5)
N    = max(N, realmin);
xobs = max(x, 0) .* N;
dLo  = sqrt(2 .* xobs .* log(16 ./ eps.^4));
dHi  = sqrt(2 .* xobs .* log(eps .^-1.5));
lo   = max(xobs - dLo, 0) ./ N;
hi   = (xobs + dHi) ./ N;
end
