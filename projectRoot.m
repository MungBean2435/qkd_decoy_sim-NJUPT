function root = projectRoot()
%PROJECTROOT 返回仓库根目录（本文件所在目录）
%
%   重构后脚本分散在 tasks/、tools/、checks/ 下，任何“相对仓库根”的路径
%   （results/、+qkd/ 等）都必须经由本函数获得。
%
%   不要再用 fileparts(mfilename('fullpath')) 当根目录：那给出的是脚本自身
%   所在的子目录，重构后会导致把图写进 tasks/results 之类的错误位置。
%
%   用法：
%       root = projectRoot();
%       out  = fullfile(root, 'results', 'fig1.png');

root = fileparts(mfilename('fullpath'));
end
