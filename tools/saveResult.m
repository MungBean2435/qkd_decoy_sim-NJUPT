function outPath = saveResult(fig, name, out)
%SAVERESULT 一张图存三份：PNG（插报告用）+ FIG（以后还能改）+ CSV（数值可复查）
%
%   outPath = saveResult(fig, name, out)
%     name : 文件名（不含扩展名），例如 'fig1_gauss_threeN'
%     out  : qkd.runCase 的返回值，需要里面有 L、R、u、v、Pu、Pv 这些字段
%
%   为什么三个都要？
%     PNG → 报告/PPT 直接用，300 dpi 打印不糊；
%     FIG → 以后发现图例位置不好还能打开再改，不用重算；
%     CSV → 别人（或未来的你）想核对某个点的数值，不必跑 MATLAB。
%
%   .fig 是二进制文件，已在 .gitignore 里排除，不纳入版本控制。

root    = projectRoot();       % 本文件在 tools/ 下，仓库根要单独解析（别用 mfilename）
resDir  = fullfile(root, 'results');
if ~exist(resDir, 'dir'), mkdir(resDir); end   % 第一次跑时 results/ 可能还不存在

pngPath = fullfile(resDir, [name '.png']);
figPath = fullfile(resDir, [name '.fig']);
csvPath = fullfile(resDir, [name '.csv']);

% ---- 图像 ----
% exportgraphics 是 R2020a 起才有的新函数，比老的 print/ saveas 清楚得多，
% 也是本工程要求 R2020a+ 的唯一原因。
if ~isempty(fig)
    exportgraphics(fig, pngPath, 'Resolution', 300);   % 300 dpi，够印刷用
    savefig(fig, figPath);                            % 存一份可再编辑的 .fig
end

% ---- 数据表 ----
% 有了 CSV，图上的每个点都能被复查：改模型后跑一遍，diff 一下就知道哪里变了。
if nargin >= 3 && ~isempty(out)
    % 'n' 这个参数表示「别自动加换行转换」，显式写 UTF-8 避免中文系统乱码
    fid = fopen(csvPath, 'w', 'n', 'UTF-8');
    fprintf(fid, 'L_km,R_per_pulse,u,v,Pu,Pv\n');
    for i = 1:numel(out.L)
        % %.6e 是科学计数法（密钥率很小），%.6f 是普通小数（参数是 0.x 量级）
        fprintf(fid, '%.1f,%.6e,%.6f,%.6f,%.6f,%.6f\n', ...
                out.L(i), out.R(i), out.u(i), out.v(i), out.Pu(i), out.Pv(i));
    end
    fclose(fid);
end

outPath = pngPath;   % 把 PNG 路径返回去，方便调用方接着用
end
