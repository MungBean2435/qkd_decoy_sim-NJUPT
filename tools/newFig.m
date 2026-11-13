function [f, ax] = newFig(w, h)
%NEWFIG 造一个「风格统一」的空白图窗，省得每个脚本都重复设置一遍
%
%   [f, ax] = newFig(w, h)
%
%   返回图窗句柄 f 和它里面唯一的坐标轴句柄 ax。
%   为什么强调「唯一」？因为如果脚本里又随手 axes() 建一个，
%   就会出现两套刻度叠在一起、坐标轴乱跳的老问题。
%
%   w、h 是图窗宽高（像素），不给就用默认 780×540。
%
%   这个函数不画任何数据，只做「装修」：
%     白底、中文字体、对数纵轴、网格、坐标轴位置固定。

if nargin < 1, w = 780; end      % 没传宽高就用默认值
if nargin < 2, h = 540; end

% 'Visible','off' 让图窗先藏起来：批量出图时屏幕上不会疯狂闪窗，
% 需要看的时候再 set(f,'Visible','on')。
f  = figure('Color', 'w', 'Position', [120 100 w h], 'Visible', 'off');
ax = axes('Parent', f);
hold(ax, 'on');      % 允许后面一条条往上叠曲线，而不是互相覆盖

set(ax, 'FontName', cjkFont(), 'FontSize', 11, 'LineWidth', 1.0, ...
        'Box', 'on', 'TickDir', 'out', 'XGrid', 'on', 'YGrid', 'on', ...
        'GridAlpha', 0.15, 'YScale', 'log', ...      % 纵轴取对数：密钥率跨十几个数量级
        'XMinorGrid', 'off', 'YMinorGrid', 'off');

% 用「归一化」坐标定死坐标轴在窗口里的位置（0~1 的比例），
% 这样不同尺寸的窗口出来版式一致，图例也不会压住曲线。
ax.Units = 'normalized';
ax.Position = [0.135 0.135 0.80 0.755];
end
