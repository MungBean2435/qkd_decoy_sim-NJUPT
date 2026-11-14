function g = gain(p, L)


g = struct();

% 透过率：光飞 L 公里后还剩几成。
g.eta = p.etad .* 10 .^ (-p.alpha .* L ./ 10);

% 一个脉冲里「至少有一个光子被收到」的概率。
g.eta_u = 1 - exp(-g.eta .* p.u);
g.eta_v = 1 - exp(-g.eta .* p.v);

g.Qu = p.Y0 + g.eta_u;
g.Qv = p.Y0 + g.eta_v;

% 误码率 E = 错误事件占所有响应的比例。
g.Eu = (p.e0 .* p.Y0 + p.ed .* g.eta_u) ./ g.Qu;
g.Ev = (p.e0 .* p.Y0 + p.ed .* g.eta_v) ./ g.Qv;

g.Tu = g.Eu .* g.Qu;
g.Tv = g.Ev .* g.Qv;

end
