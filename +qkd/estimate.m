function [Y1Lz, e1Ux, d] = estimate(p, L, spec)
%   [Y1Lz, e1Ux, d] = qkd.estimate(p, L, spec)
%  (3.28)  Y~1^{W,L} = [P2^u·Qv^L - P2^v·Qu^U + (P2^v·P0^u - P2^u·P0^v)·Y0^U]
%                      / (P1^v·P2^u - P1^u·P2^v)
D  = qkd.fluct(spec.method, spec.eps);

g  = qkd.gain(p, L);
N  = spec.N;

np = @(n, l) exp(-l) .* l.^n ./ factorial(n);

wZ_u = p.Pza_u;       % 信号态选 Z 基的概率
wZ_v = p.Pza_v;       % 诱骗态选 Z 基的概率
wX_u = 1 - p.Pza_u;
wX_v = 1 - p.Pza_v;

NuZ = p.Pu * wZ_u * N;   % Z 基里信号态的脉冲数
NvZ = p.Pv * wZ_v * N;   % Z 基里诱骗态的脉冲数
NuX = p.Pu * wX_u * N;   % X 基里信号态的脉冲数
NvX = p.Pv * wX_v * N;   % X 基里诱骗态的脉冲数
N0  = p.P0 * N;          % 真空态脉冲数

[Y0_lo, Y0_hi] = D.Y0(p.Y0, N0);
% nWz 是这个基里收到的「总事件数」
nWz = NuZ .* g.Qu + NvZ .* g.Qv;
[QuZ_lo, QuZ_hi] = D.Q(g.Qu, NuZ, nWz);
[QvZ_lo, QvZ_hi] = D.Q(g.Qv, NvZ, nWz);
nWx = NuX .* g.Qu + NvX .* g.Qv;
[QuX_lo, QuX_hi] = D.Q(g.Qu, NuX, nWx);
[QvX_lo, QvX_hi] = D.Q(g.Qv, NvX, nWx);
[~, TvX_hi]      = D.T(g.Tv, NvX, nWx);


P1u = np(1, p.u);  P2u = np(2, p.u);  P0u = np(0, p.u);
P1v = np(1, p.v);  P2v = np(2, p.v);  P0v = np(0, p.v);
den = P1v .* P2u - P1u .* P2v;

Y1Lz = (P2u .* QvZ_lo - P2v .* QuZ_hi + (P2v .* P0u - P2u .* P0v) .* Y0_hi) ./ den;
Y1Lz = max(Y1Lz, 0);
Y1Lx = (P2u .* QvX_lo - P2v .* QuX_hi + (P2v .* P0u - P2u .* P0v) .* Y0_hi) ./ den;
Y1Lx = max(Y1Lx, 0);

e1Ux = (TvX_hi - P0v .* p.e0 .* Y0_lo) ./ (P1v .* max(Y1Lx, realmin));
e1Ux = min(max(e1Ux, 0), 0.5);   % 误码率只能在 [0, 0.5]：超过 0.5 说明数据全反了
e1Ux(Y1Lx <= 0) = 0.5;

d.Qu = g.Qu;   d.Qv = g.Qv;          % 增益
d.Eu = g.Eu;   d.Ev = g.Ev;          % 误码率
d.Y0_lo = Y0_lo;   d.Y0_hi = Y0_hi;  % 暗计数的上下界
d.Y1Lx = Y1Lx;                       % X 基单光子响应率下界
d.P1u = P1u;   d.P1v = P1v;   d.den = den;   % 三个泊松项和分母，答辩常被问
d.nuZ = NuZ;   d.nvZ = NvZ;          % Z 基各强度的脉冲数

end
