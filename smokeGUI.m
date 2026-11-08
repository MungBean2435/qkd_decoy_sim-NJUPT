function smokeGUI()
%SMOKEGUI GUI 无头自检：构造窗口 → 跑三条曲线 → 导出界面截图 → 关闭
%
%   用途：在没有人工点击的情况下验证界面能正常构建、回调能跑通。
%   运行： addpath(genpath('qkd_decoy_sim')); smokeGUI

root = fileparts(mfilename('fullpath'));
app  = QKDApp();
app.UIFigure.Visible = 'off';

try
    % 曲线 1：高斯，不优化
    app.ddlMethod.Value = 'gauss';
    app.ddlOpt.Value    = 'none';
    app.edN.Value       = 1e9;
    app.edLmax.Value    = 250;
    o1 = app.runSim();

    % 曲线 2：霍夫丁，仅优化 u
    app.ddlMethod.Value = 'hoeffding';
    app.ddlOpt.Value    = 'u';
    o2 = app.runSim();

    % 曲线 3：切尔诺夫，全局优化（步长放粗，自检要快）
    app.ddlMethod.Value = 'chernoff';
    app.ddlOpt.Value    = 'global';
    app.edLstep.Value   = 5;
    o3 = app.runSim();

    fprintf('曲线1 最远 %.0f km / 曲线2 最远 %.0f km / 曲线3 最远 %.0f km\n', ...
            o1.Lmax, o2.Lmax, o3.Lmax);

    % 界面截图：仅在交互式桌面下导出（-batch 无图形界面时无法渲染 uifigure）
    if usejava('desktop')
        outdir = fullfile(root, 'results');
        if ~exist(outdir, 'dir'), mkdir(outdir); end
        exportgraphics(app.UIFigure, fullfile(outdir, 'gui_preview.png'), 'Resolution', 150);
        fprintf('界面截图已导出: %s\n', fullfile(outdir, 'gui_preview.png'));
    end

    % 检验叠加逻辑
    fprintf('叠加曲线数 = %d（应为 3）\n', numel(app.curves));
catch ME
    fprintf('FAILED: %s\n%s\n', ME.message, getReport(ME, 'basic'));
    delete(app.UIFigure);
    rethrow(ME);
end

delete(app.UIFigure);
fprintf('GUI 自检通过。\n');
end
