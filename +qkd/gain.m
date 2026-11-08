function g = gain(p, L)
%GAIN 信道穿透率、各强度脉冲的增益 Q_l 与量子误码率 E_l
%
%   g = qkd.gain(p, L)
%
%   L 可以是标量或数组（逐元素计算，便于优化时对整群参数一次求值）。
%
%   物理模型：
%       穿透率      eta   = eta_d * 10^(-alpha*L/10)
%       增益        Q_l   = Y0 + 1 - exp(-eta*l)          (真空态 Q_0 = Y0)
%       误码率      E_l   = (e0*Y0 + e_d*(1-exp(-eta*l))) / Q_l
%       误码计数    T_l   = E_l * Q_l                     （即 (3.27) 中的 T_l）
%
%   对应指导书 (3.8) 与 (3.27) 的模型。

g = struct();

% 信道总穿透率（含 Bob 端探测效率）
g.eta = p.etad .* 10 .^ (-p.alpha .* L ./ 10);

% 单光子到达被探测的概率（不含暗计数）
g.eta_u = 1 - exp(-g.eta .* p.u);
g.eta_v = 1 - exp(-g.eta .* p.v);

% 增益
g.Qu = p.Y0 + g.eta_u;
g.Qv = p.Y0 + g.eta_v;

% 量子误码率（本底误码 + 真空态误码）
g.Eu = (p.e0 .* p.Y0 + p.ed .* g.eta_u) ./ g.Qu;
g.Ev = (p.e0 .* p.Y0 + p.ed .* g.eta_v) ./ g.Qv;

% 误码计数（增益 × 误码率）
g.Tu = g.Eu .* g.Qu;
g.Tv = g.Ev .* g.Qv;

end
