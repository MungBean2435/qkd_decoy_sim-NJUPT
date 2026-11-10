function [f, ax] = newFig(w, h)
%NEWFIG 统一出图风格：白底、中文字体、对数纵轴、网格
%   返回图窗与该图窗内唯一的坐标轴，避免重复创建 axes 导致刻度叠加。

if nargin < 1, w = 780; end
if nargin < 2, h = 540; end

f  = figure('Color', 'w', 'Position', [120 100 w h], 'Visible', 'off');
ax = axes('Parent', f);
hold(ax, 'on');
set(ax, 'FontName', cjkFont(), 'FontSize', 11, 'LineWidth', 1.0, ...
        'Box', 'on', 'TickDir', 'out', 'XGrid', 'on', 'YGrid', 'on', ...
        'GridAlpha', 0.15, 'YScale', 'log', ...
        'XMinorGrid', 'off', 'YMinorGrid', 'off');
ax.Units = 'normalized';
ax.Position = [0.135 0.135 0.80 0.755];
end
