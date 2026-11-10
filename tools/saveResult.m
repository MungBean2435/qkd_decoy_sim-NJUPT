function outPath = saveResult(fig, name, out)
%SAVERESULT 保存 PNG(300dpi) + FIG + CSV 数据表
%
%   outPath = saveResult(fig, name, out)
%   name : 文件名（不含扩展名），如 'fig1_gauss_N'
%   out  : qkd.runCase 的返回值（需含 L, R 等字段）

root    = projectRoot();       % 本文件在 tools/ 下，仓库根要单独解析
resDir  = fullfile(root, 'results');
if ~exist(resDir, 'dir'), mkdir(resDir); end

pngPath = fullfile(resDir, [name '.png']);
figPath = fullfile(resDir, [name '.fig']);
csvPath = fullfile(resDir, [name '.csv']);

% 图像
if ~isempty(fig)
    exportgraphics(fig, pngPath, 'Resolution', 300);
    savefig(fig, figPath);
end

% 数据表（便于报告里贴数值、也便于别人复算）
if nargin >= 3 && ~isempty(out)
    fid = fopen(csvPath, 'w', 'n', 'UTF-8');
    fprintf(fid, 'L_km,R_per_pulse,u,v,Pu,Pv\n');
    for i = 1:numel(out.L)
        fprintf(fid, '%.1f,%.6e,%.6f,%.6f,%.6f,%.6f\n', ...
                out.L(i), out.R(i), out.u(i), out.v(i), out.Pu(i), out.Pv(i));
    end
    fclose(fid);
end

outPath = pngPath;
end
