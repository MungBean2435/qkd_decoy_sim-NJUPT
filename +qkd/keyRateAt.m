function [R, d] = keyRateAt(p, L, spec)
%KEYRATEAT 给定距离 L 处的安全密钥率（对应指导书 (3.30)）
%
%   [R, d] = qkd.keyRateAt(p, L, spec)
%
%       R >= P_u·P^A_{Z|u}·P^B_Z · { P1^u·Y~1^{Z,L}·[1 - H2(e~1^{X,U})]
%                                     - Q_u·f·H2(E_u) }
%
%   L 可为标量或数组；p 的 u/v/Pu/Pv 可被优化器改写后复用，
%   因此“优化某参数”在代码上就是“把 p 的字段改掉再调本函数”。

if ~isfield(spec, 'eps') || isempty(spec.eps)
    spec.eps = 1e-7;
end

[Y1Lz, e1Ux, d] = qkd.estimate(p, L, spec);
d.P1u  = exp(-p.u) .* p.u;
d.e1Ux = e1Ux;
d.Y1Lz = Y1Lz;

% 二进制熵 H2(x)
H2 = @(x) -(x .* log2(max(x, realmin)) + (1 - x) .* log2(max(1 - x, realmin)));

% 成码部分 - 纠错部分
R = p.Pu .* p.Pza_u .* p.Pzb .* ...
    (d.P1u .* Y1Lz .* (1 - H2(e1Ux)) - d.Qu .* p.f .* H2(d.Eu));

% 非物理区（无正密钥）置 0
R(~isfinite(R)) = 0;
R(R < 0) = 0;

end
