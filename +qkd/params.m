function p = params()
%   p = qkd.params()
p = struct();

p.u     = 0.5;      % 信号态光强 u
p.v     = 0.1;      % 诱骗态光强 v
p.Pu    = 0.6;      % 信号态选择概率
p.Pv    = 0.3;      % 诱骗态选择概率
p.Pza_u = 0.5;      % Alice 发信号态时选 Z 基的概率
p.Pza_v = 0.5;      % Alice 发诱骗态时选 Z 基的概率
p.Pzb   = 0.5;      % Bob 选 Z 基的概率
p.f     = 1.16;     % 纠错效率
p.alpha = 0.2;      % 光纤损耗
p.etad  = 0.5;      % Bob 的探测器效率
p.d     = 1e-6;     % 暗计数
p.etaA  = 0.75;     % 单光子源方案用的本地探测效率
p.dA    = 1e-6;     % 单光子源方案的本地暗计数
p.ed    = 0.015;    % 本底误码
p.e0    = 0.5;      % 真空态误码
p.Y0    = 2 * p.d * (1 - p.d);
p.P0    = 1 - p.Pu - p.Pv;

end
