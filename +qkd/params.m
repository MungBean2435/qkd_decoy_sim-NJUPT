function p = params()
%PARAMS 题目给定的固定仿真参数（2026 软件设计题目 · 表 1：三强度诱骗态 BB84）
%
%   字段与题目表格一一对应，便于答辩时逐项核对：
%   u  v  Pu  Pv  Pza_u  Pza_v  Pzb  f  alpha  etad  d  etaA  dA  ed
%
%   返回值 p 为结构体，额外包含派生量 Y0（真空态响应率）。
%   本函数不含任何绘图/界面代码，可独立调用。

p = struct();

% ---- 光强与选择概率 ----
p.u     = 0.5;      % 信号态光强 u
p.v     = 0.1;      % 诱骗态光强 v
p.Pu    = 0.6;      % 信号态选择概率 P_u
p.Pv    = 0.3;      % 诱骗态选择概率 P_v
p.Pza_u = 0.5;      % Alice 在信号态下选 Z 基的概率 P^A_{Z|u}
p.Pza_v = 0.5;      % Alice 在诱骗态下选 Z 基的概率 P^A_{Z|v}
p.Pzb   = 0.5;      % Bob 端选择 Z 基的概率 P^B_Z

% ---- 系统参数 ----
p.f     = 1.16;     % 纠错效率 f
p.alpha = 0.2;      % 光纤信道损耗 (dB/km)
p.etad  = 0.5;      % Bob 端探测效率 eta_d
p.d     = 1e-6;     % Bob 端暗计数 d
p.etaA  = 0.75;     % HSPS 本地探测器效率 eta_A（WCS 三强度场景不使用）
p.dA    = 1e-6;     % HSPS 本地暗计数 d_A（WCS 三强度场景不使用）
p.ed    = 0.015;    % 系统本底误码 e_d
p.e0    = 0.5;      % 真空态误码 e_0

% ---- 派生量 ----
% 真空态响应率：Bob 端两个探测器，任一个暗计数即触发
p.Y0    = 2 * p.d * (1 - p.d);

% 真空态概率由归一化约束给出（三强度方案：只有 u、v 与真空）
p.P0    = 1 - p.Pu - p.Pv;

end
