function [Y1Lz, e1Ux, d] = estimate(p, L, spec)
%ESTIMATE 诱骗态估计：单光子响应率下界 Y1L 与单光子误码率上界 e1U
%
%   [Y1Lz, e1Ux, d] = qkd.estimate(p, L, spec)
%
%   Y1Lz : Z 基（成码基）单光子响应率下界  Y~1^{Z,L}
%   e1Ux : X 基（参数估计基）单光子误码率上界  e~1^{X,U}
%
%   公式对应指导书：
%       (3.28)  Y~1^{W,L} = [P2^u·Qv^L - P2^v·Qu^U + (P2^v·P0^u - P2^u·P0^v)·Y0^U]
%                          / (P1^v·P2^u - P1^u·P2^v)
%       (3.29)  e~1^{X,U} = (Tv^U - P0^v·e0·Y0^L) / (P1^v·Y~1^{X,L})
%
%   spec 需包含字段：N, method, eps（优化时由调用方改写 p 的 u/v/Pu/Pv）

D  = qkd.fluct(spec.method, spec.eps);
g  = qkd.gain(p, L);
N  = spec.N;
np = @(n, l) exp(-l) .* l.^n ./ factorial(n);   % 泊松分布 P_n^l

% ---- 两个基上的“强度选择 × 基选择”权重 ----
wZ_u = p.Pza_u;       wZ_v = p.Pza_v;
wX_u = 1 - p.Pza_u;   wX_v = 1 - p.Pza_v;

% ---- 基内脉冲数与真空态脉冲数 ----
NuZ = p.Pu * wZ_u * N;
NvZ = p.Pv * wZ_v * N;
NuX = p.Pu * wX_u * N;
NvX = p.Pv * wX_v * N;
N0  = p.P0 * N;

% ---- 真空态响应率的上下界（真空态不选基）----
[Y0_lo, Y0_hi] = D.Y0(p.Y0, N0);

% ---- Z 基：增益/误码计数的置信区间 ----
nWz = NuZ .* g.Qu + NvZ .* g.Qv;                 % 基内总计数（霍夫丁界用）
[QuZ_lo, QuZ_hi] = D.Q(g.Qu, NuZ, nWz);
[QvZ_lo, QvZ_hi] = D.Q(g.Qv, NvZ, nWz);

% ---- X 基：增益/误码计数的置信区间 ----
nWx = NuX .* g.Qu + NvX .* g.Qv;
[QuX_lo, QuX_hi] = D.Q(g.Qu, NuX, nWx);
[QvX_lo, QvX_hi] = D.Q(g.Qv, NvX, nWx);
[~, TvX_hi]      = D.T(g.Tv, NvX, nWx);

% ---- (3.28) 分母上的泊松项 ----
P1u = np(1, p.u);  P2u = np(2, p.u);  P0u = np(0, p.u);
P1v = np(1, p.v);  P2v = np(2, p.v);  P0v = np(0, p.v);
den = P1v .* P2u - P1u .* P2v;                   % 恒 > 0（u > v）

% ---- Z 基单光子响应率下界 ----
Y1Lz = (P2u .* QvZ_lo - P2v .* QuZ_hi + (P2v .* P0u - P2u .* P0v) .* Y0_hi) ./ den;
Y1Lz = max(Y1Lz, 0);

% ---- X 基单光子响应率下界（用于 e1 估计的分母）----
Y1Lx = (P2u .* QvX_lo - P2v .* QuX_hi + (P2v .* P0u - P2u .* P0v) .* Y0_hi) ./ den;
Y1Lx = max(Y1Lx, 0);

% ---- (3.29) X 基单光子误码率上界 ----
e1Ux = (TvX_hi - P0v .* p.e0 .* Y0_lo) ./ (P1v .* max(Y1Lx, realmin));
e1Ux = min(max(e1Ux, 0), 0.5);
e1Ux(Y1Lx <= 0) = 0.5;                           % 无法估计时取最坏值

% ---- 诊断量（供绘图与报告用）----
d.Qu = g.Qu;   d.Qv = g.Qv;
d.Eu = g.Eu;   d.Ev = g.Ev;
d.Y0_lo = Y0_lo;   d.Y0_hi = Y0_hi;
d.Y1Lx = Y1Lx;
d.P1u = P1u;   d.P1v = P1v;   d.den = den;
d.nuZ = NuZ;   d.nvZ = NvZ;

end
