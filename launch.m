function app = launch()
%LAUNCH 一键启动仿真软件（自动把工程目录加入搜索路径）
%
%   用法：在 qkd_decoy_sim 的上一级目录执行
%       launch
%   或在本目录执行
%       addpath('..'); launch
root = projectRoot();
addpath(genpath(root));
app  = QKDApp();
end
