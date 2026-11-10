function name = cjkFont()
%CJKFONT 返回当前系统可用的中文字体名，供 uifigure / axes / legend 使用
%
%   name = cjkFont()
%
%   仓库里所有中文标注都通过本函数取字体，避免队友在 macOS 或 Linux
%   上克隆后出现方框字（Windows 的 Microsoft YaHei 在那些系统上不存在）。
%
%   匹配规则：优先精确匹配，其次前缀匹配（MATLAB 的 listfonts 里常常是
%   "Microsoft YaHei UI" 这种变体，而 "Microsoft YaHei" 本身并不出现在列表里，
%   但直接使用是有效的）。全都找不到时退回 Helvetica，中文会显示为方框，
%   但代码不会报错。

persistent cached
if ~isempty(cached)
    name = cached;
    return
end

switch computer('arch')
    case {'maci64', 'maca64'}
        candidates = {'PingFang SC', 'Heiti SC', 'STHeiti', 'Songti SC'};
    case {'glnxa64', 'glnx64'}
        candidates = {'Noto Sans CJK SC', 'Noto Sans SC', 'Source Han Sans SC', ...
                      'WenQuanYi Zen Hei', 'WenQuanYi Micro Hei', 'AR PL UMing CN'};
    otherwise
        candidates = {'Microsoft YaHei', 'SimHei', 'SimSun', 'DengXian'};
end

name = 'Helvetica';
try
    installed = listfonts();
    for k = 1:numel(candidates)
        % 精确匹配
        if any(strcmpi(installed, candidates{k}))
            name = candidates{k};
            break
        end
        % 前缀匹配：Microsoft YaHei -> Microsoft YaHei UI
        hit = installed(strncmpi(installed, candidates{k}, numel(candidates{k})));
        if ~isempty(hit)
            name = hit{1};
            break
        end
    end
catch
    % listfonts 在某些无头环境下可能失败，退回平台首选字体
    name = candidates{1};
end

cached = name;
end
