function name = cjkFont()
%CJKFONT 挑一个当前系统上有的中文，供 uifigure / axes / legend 使用
%
%   name = cjkFont()
%
% ------------------------------------------------------------------------
%  为什么需要这个函数：MATLAB 画中文时如果字体里没有汉字，字就变成方框。
%  同一份代码，队友在 Windows 上跑是好的，在 macOS 或 Linux 上可能是方框，
%  因为「微软雅黑」在那些系统上根本不存在。
%
%  这里的做法：按平台列一串候选字体，从第一个开始挨个问「系统里有吗」，
%  有就用它。全都没有就退回 Helvetica —— 这时中文还是方块，但程序不会报错，
%  图也能存下来（属于显示问题，不是计算问题）。
% ------------------------------------------------------------------------
%
%  匹配规则：优先精确匹配；匹配不上再试「前缀匹配」。
%  原因：MATLAB 的 listfonts 里常常列出 "Microsoft YaHei UI" 这种变体，
%  而 "Microsoft YaHei" 本身却没出现在列表里 —— 但直接用它作图是有效的。

% MATLAB 语法：persistent 变量会被函数「记住」，下次调用直接用上次的结果。
% 字体不会中途变，所以测一次就够，没必要每次画图都重新扫一遍字体列表。
persistent cached
if ~isempty(cached)
    name = cached;
    return
end

% computer('arch') 返回当前系统架构，用它区分三大平台
switch computer('arch')
    case {'maci64', 'maca64'}
        candidates = {'PingFang SC', 'Heiti SC', 'STHeiti', 'Songti SC'};
    case {'glnxa64', 'glnx64'}
        % Linux 默认基本不带中文字体，CI 上要先装 fonts-noto-cjk
        candidates = {'Noto Sans CJK SC', 'Noto Sans SC', 'Source Han Sans SC', ...
                      'WenQuanYi Zen Hei', 'WenQuanYi Micro Hei', 'AR PL UMing CN'};
    otherwise
        candidates = {'Microsoft YaHei', 'SimHei', 'SimSun', 'DengXian'};
end

name = 'Helvetica';   % 兜底值：先假设找不到中文
try
    installed = listfonts();   % 问系统：你装了哪些字体
    for k = 1:numel(candidates)
        % ① 精确匹配：系统里正好有这个名字
        if any(strcmpi(installed, candidates{k}))
            name = candidates{k};
            break
        end
        % ② 前缀匹配：Microsoft YaHei → Microsoft YaHei UI 这类变体
        hit = installed(strncmpi(installed, candidates{k}, numel(candidates{k})));
        if ~isempty(hit)
            name = hit{1};
            break
        end
    end
catch
    % listfonts 在某些无窗口环境会失败，那就直接用该平台的首选字体名字赌一把
    name = candidates{1};
end

cached = name;   % 记住结果，下次不再扫字体列表
end
