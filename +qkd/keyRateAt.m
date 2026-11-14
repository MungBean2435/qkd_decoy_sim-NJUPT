function [R, d] = keyRateAt(p, L, spec)
%   [R, d] = qkd.keyRateAt(p, L, spec)

if ~isfield(spec, 'eps') || isempty(spec.eps)
    spec.eps = 1e-7;
end

[Y1Lz, e1Ux, d] = qkd.estimate(p, L, spec);

d.P1u  = exp(-p.u) .* p.u;
d.e1Ux = e1Ux;
d.Y1Lz = Y1Lz;

% 二进制熵 H2(x) = -x·log2(x) - (1-x)·log2(1-x)
H2 = @(x) -(x .* log2(max(x, realmin)) + (1 - x) .* log2(max(1 - x, realmin)));

R = p.Pu .* p.Pza_u .* p.Pzb .* ...
    (d.P1u .* Y1Lz .* (1 - H2(e1Ux)) - d.Qu .* p.f .* H2(d.Eu));

R(~isfinite(R)) = 0;
R(R < 0) = 0;

end
