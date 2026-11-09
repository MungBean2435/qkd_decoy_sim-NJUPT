classdef QKDApp < handle
%QKDAPP 仿真软件界面层（纯代码 uifigure，无 .mlapp 二进制）
%
%   【本文件只做三件事】
%       1) 收集参数  → 结构体 p 与 spec
%       2) 调用 qkd.runCase(p, spec)   ← 唯一的计算入口
%       3) 把 out 画出来
%
%   【不含任何物理公式】所有模型都在 +qkd/ 包里，
%   答辩时讲完 +qkd/ 的 6 个函数，本文件只需说明“界面怎么把参数喂进去”。
%
%   左下角「一键出图」调用 run_task1/2/3（与命令行完全同一套脚本），
%   按题目默认参数把 Fig.1–3 的 PNG/CSV 写入 results/，带进度条与取消。
%
%   用法：
%       launch                % 自动 addpath 后打开窗口

    properties (Constant)
        % 参数键名、显示名（顺序与题目参数表一致）
        KEYS = {'u','v','Pu','Pv','Pza_u','Pza_v','Pzb','f', ...
                'alpha','etad','d','etaA','dA','ed'};
        SHOW = {'u  信号态光强', 'v  诱骗态光强', 'P_u  信号态概率', 'P_v  诱骗态概率', ...
                'P^A_{Z|u}  选 Z 基概率', 'P^A_{Z|v}  选 Z 基概率', 'P^B_Z  Bob 选 Z 基', ...
                'f  纠错效率', 'alpha  损耗(dB/km)', 'eta_d  探测效率', ...
                'd  暗计数', 'eta_A  本地探测效率', 'd_A  本地暗计数', 'e_d  本底误码'};
    end

    properties (Access = public)
        UIFigure          % 主窗口
        p                 % 当前参数结构体
        tblParams         % 14 个参数的表格控件
        ddlMethod         % 统计起伏方法
        edN               % 发射脉冲数 N
        edEps             % 失败概率 eps
        ddlOpt            % 优化方式
        edLmax            % 最大距离
        edLstep           % 距离步长
        btnRun, btnClear, btnExport
        btnTask1, btnTask2, btnTask3, btnTaskAll   % 一键出图
        ax                % 曲线区
        txtLog            % 状态/日志区
        curves = {}       % 已叠加的曲线：每项 {out, 名称, 颜色}
        batchRunning = false   % 批量出图运行标志（防重复点击）
        palette = [ ...   % 曲线配色
            0.00 0.45 0.74
            0.85 0.33 0.10
            0.35 0.60 0.25
            0.60 0.30 0.65
            0.30 0.30 0.30
            0.90 0.60 0.10
            0.10 0.65 0.65
            0.75 0.25 0.45];
    end

    methods (Access = public)
        function app = QKDApp()
            app.p = qkd.params();
            buildUI(app);
            app.updateButtons();
            app.log(sprintf('就绪：P_0 = %.3f，Y_0 = %.2e。', app.p.P0, app.p.Y0));
        end
    end

    methods (Access = public)   % 全部公开，便于脚本/自检直接驱动（界面层本身无状态风险）

        % ============================================================
        % 界面搭建
        % ============================================================
        function buildUI(app)
            app.UIFigure = uifigure('Name', 'WCS 三强度诱骗态 BB84 仿真软件', ...
                                    'Position', [30 30 1240 880], ...
                                    'Color', [0.96 0.96 0.97]);

            % ---------- 左侧：参数与设置 ----------
            pnl = uipanel(app.UIFigure, 'Title', '参数与计算设置', ...
                          'Position', [12 12 430 856], 'FontName', cjkFont(), ...
                          'FontSize', 11, 'BackgroundColor', [0.96 0.96 0.97]);

            data = cell(numel(app.KEYS), 2);
            for i = 1:numel(app.KEYS)
                data{i, 1} = app.SHOW{i};
                data{i, 2} = app.fmtVal(app.p.(app.KEYS{i}));
            end
            app.tblParams = uitable(pnl, 'Data', data, ...
                'ColumnName', {'参数', '取值'}, 'ColumnFormat', {'char', 'char'}, ...
                'ColumnEditable', [false true], 'ColumnWidth', {232 122}, ...
                'RowName', [], 'FontName', cjkFont(), 'FontSize', 9, ...
                'Position', [10 510 410 332], ...
                'CellEditCallback', @(~, e) app.onEditParam(e));

            % ---- 计算设置 ----
            y = 484;
            uilabel(pnl, 'Text', '统计起伏方法', 'Position', [14 y 120 22], ...
                    'FontName', cjkFont());
            app.ddlMethod = uidropdown(pnl, 'Position', [138 y-3 278 26], ...
                'Items', {'高斯 (Gaussian)', '霍夫丁 (Hoeffding)', '切尔诺夫 (Chernoff)'}, ...
                'ItemsData', {'gauss', 'hoeffding', 'chernoff'}, ...
                'Value', 'gauss', 'FontName', cjkFont());

            y = y - 34;
            uilabel(pnl, 'Text', '发射脉冲数 N', 'Position', [14 y 120 22], ...
                    'FontName', cjkFont());
            app.edN = uieditfield(pnl, 'numeric', 'Position', [138 y-3 278 26], ...
                                  'Value', 1e9, 'Limits', [1e4 1e14]);

            y = y - 34;
            uilabel(pnl, 'Text', '失败概率 eps', 'Position', [14 y 120 22], ...
                    'FontName', cjkFont());
            app.edEps = uieditfield(pnl, 'numeric', 'Position', [138 y-3 278 26], ...
                                    'Value', 1e-7, 'Limits', [1e-15 1e-2]);

            y = y - 34;
            uilabel(pnl, 'Text', '优化方式', 'Position', [14 y 120 22], ...
                    'FontName', cjkFont());
            app.ddlOpt = uidropdown(pnl, 'Position', [138 y-3 278 26], ...
                'Items', {'不优化', '仅优化信号态 u', '全局优化 (u, v, P_u, P_v)'}, ...
                'ItemsData', {'none', 'u', 'global'}, ...
                'Value', 'none', 'FontName', cjkFont());

            y = y - 34;
            uilabel(pnl, 'Text', '最大距离 (km)', 'Position', [14 y 108 22], ...
                    'FontName', cjkFont());
            app.edLmax = uieditfield(pnl, 'numeric', 'Position', [130 y-3 120 26], ...
                                     'Value', 300, 'Limits', [10 1000]);
            uilabel(pnl, 'Text', '步长 (km)', 'Position', [262 y 58 22], ...
                    'FontName', cjkFont());
            app.edLstep = uieditfield(pnl, 'numeric', 'Position', [322 y-3 94 26], ...
                                      'Value', 1, 'Limits', [0.1 20]);

            % ---- 曲线按钮 ----
            by = 300;
            app.btnRun = uibutton(pnl, 'Text', '运行并叠加曲线', ...
                'Position', [10 by 146 34], 'FontName', cjkFont(), ...
                'FontWeight', 'bold', 'BackgroundColor', [0.20 0.50 0.85], ...
                'FontColor', [1 1 1], 'ButtonPushedFcn', @(~, ~) app.runSim(), ...
                'Tooltip', '按左侧当前参数计算一条曲线，叠加到右侧图中');
            app.btnClear = uibutton(pnl, 'Text', '清空曲线', ...
                'Position', [166 by 112 34], 'FontName', cjkFont(), ...
                'ButtonPushedFcn', @(~, ~) app.clearCurves(), ...
                'Tooltip', '清空右侧所有已叠加的曲线');
            app.btnExport = uibutton(pnl, 'Text', '导出 PNG', ...
                'Position', [288 by 128 34], 'FontName', cjkFont(), ...
                'ButtonPushedFcn', @(~, ~) app.exportPNG(), ...
                'Tooltip', '把当前界面导出为 PNG（含曲线与参数表）');

            % ---- 一键出图（左下角）----
            pnlTask = uipanel(pnl, 'Title', '一键出图（题目默认参数 → results/）', ...
                              'Position', [10 160 410 124], 'FontName', cjkFont(), ...
                              'FontSize', 10, 'BackgroundColor', [0.96 0.96 0.97]);

            app.btnTask1 = uibutton(pnlTask, 'Text', '任务1：N 对比', ...
                'Position', [8 58 190 32], 'FontName', cjkFont(), 'FontSize', 10, ...
                'ButtonPushedFcn', @(~, ~) app.runTaskBatch(1), ...
                'Tooltip', 'run_task1：生成 fig1_gauss_threeN.png / .csv');
            app.btnTask2 = uibutton(pnlTask, 'Text', '任务2：三方法对比', ...
                'Position', [212 58 190 32], 'FontName', cjkFont(), 'FontSize', 10, ...
                'ButtonPushedFcn', @(~, ~) app.runTaskBatch(2), ...
                'Tooltip', 'run_task2：生成 fig2_three_methods 与 fig2b_optimal_u');
            app.btnTask3 = uibutton(pnlTask, 'Text', '任务3：全局优化', ...
                'Position', [8 22 190 32], 'FontName', cjkFont(), 'FontSize', 10, ...
                'ButtonPushedFcn', @(~, ~) app.runTaskBatch(3), ...
                'Tooltip', 'run_task3：生成 fig3_chernoff_global 与 fig3b_optimal_params（约 1 分钟）');
            app.btnTaskAll = uibutton(pnlTask, 'Text', '一键全部（1 → 2 → 3）', ...
                'Position', [212 22 190 32], 'FontName', cjkFont(), 'FontSize', 10, ...
                'FontWeight', 'bold', 'BackgroundColor', [0.20 0.50 0.85], ...
                'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~, ~) app.runTaskBatch(0), ...
                'Tooltip', '依次运行任务1、2、3，生成全部图像与数据表');

            % ---- 日志 ----
            app.txtLog = uitextarea(pnl, 'Position', [10 10 410 140], ...
                'Editable', 'off', 'FontName', cjkFont(), 'FontSize', 10, ...
                'Value', {'就绪：修改参数后点击“运行并叠加曲线”。', ...
                          '左下角“一键出图”按题目默认参数生成 Fig.1–3。'});

            % ---------- 右侧：曲线区 ----------
            app.ax = uiaxes(app.UIFigure, 'Position', [460 40 760 830]);
            app.ax.YScale  = 'log';
            app.ax.FontName = cjkFont();
            app.ax.FontSize = 11;
            app.ax.XGrid = 'on';  app.ax.YGrid = 'on';
            app.ax.XMinorGrid = 'off';  app.ax.YMinorGrid = 'off';
            app.ax.GridAlpha = 0.15;
            hold(app.ax, 'on');
            xlabel(app.ax, '传输距离 L (km)');
            ylabel(app.ax, '安全密钥率 R (bit/pulse)');
            title(app.ax, '安全密钥率随传输距离的变化');
            app.ax.YLim = [1e-12 5e-2];
        end

        % ============================================================
        % 参数显示与解析
        % ============================================================
        function s = fmtVal(~, v)
            % 小量用科学计数法，避免 1e-6 被显示成 0.0000 而误读为 0
            if v == 0
                s = '0';
            elseif abs(v) < 1e-3
                s = sprintf('%.2e', v);
            else
                s = sprintf('%.4g', v);
            end
        end

        function v = parseVal(~, s)
            if isnumeric(s)
                v = double(s);
                return
            end
            v = str2double(strtrim(char(s)));
        end

        % ============================================================
        % 单元格编辑回调：解析 → 校验 → 更新派生量 → 回写规范显示
        % ============================================================
        function onEditParam(app, evt)
            i = evt.Indices(1);
            old = app.p.(app.KEYS{i});
            v = app.parseVal(evt.NewData);

            if ~isscalar(v) || ~isfinite(v) || v <= 0
                app.log(sprintf('参数 %s 非法，已恢复原值。', app.KEYS{i}));
                app.refreshTable();
                return
            end
            app.p.(app.KEYS{i}) = v;

            % 派生量必须同步重算
            app.p.P0 = 1 - app.p.Pu - app.p.Pv;
            app.p.Y0 = 2 * app.p.d * (1 - app.p.d);

            if app.p.P0 <= 0
                app.p.(app.KEYS{i}) = old;
                app.p.P0 = 1 - app.p.Pu - app.p.Pv;
                app.log('约束违反：P_u + P_v 必须小于 1（要留真空态）。');
            elseif app.p.v >= app.p.u
                app.p.(app.KEYS{i}) = old;
                app.p.P0 = 1 - app.p.Pu - app.p.Pv;
                app.log('约束违反：诱骗态光强 v 必须小于信号态 u。');
            end
            app.refreshTable();
        end

        function refreshTable(app)
            d = app.tblParams.Data;
            for i = 1:numel(app.KEYS)
                d{i, 2} = app.fmtVal(app.p.(app.KEYS{i}));
            end
            app.tblParams.Data = d;
        end

        % ============================================================
        % 运行：收集 spec → 调内核 → 入栈 → 重绘
        % ============================================================
        function out = runSim(app)
            out = [];
            if app.p.P0 <= 0 || app.p.v >= app.p.u
                app.log('参数不满足物理约束，请先修正。');
                return
            end
            if app.edLstep.Value > app.edLmax.Value
                app.log('步长不能大于最大距离。');
                return
            end

            spec = struct();
            spec.method = app.ddlMethod.Value;
            spec.N      = app.edN.Value;
            spec.eps    = app.edEps.Value;
            spec.L      = [0 app.edLmax.Value app.edLstep.Value];
            spec.opt    = app.ddlOpt.Value;
            spec.optU   = struct('lb', 0.10, 'ub', 1.30, 'n', 61, 'mode', 'perDistance');
            spec.optG   = struct('npop', 30, 'ngen', 40);

            app.setBusy(true);
            cleanup = onCleanup(@() app.setBusy(false));

            app.log('计算中…');
            if usejava('desktop'), drawnow; end
            t0 = tic;
            try
                out = qkd.runCase(app.p, spec);
            catch ME
                app.log(['计算失败：' ME.message]);
                return
            end
            dt  = toc(t0);

            name = sprintf('%s | N = %s | %s', app.methodCN(spec.method), ...
                           app.numCN(spec.N), app.optCN(spec.opt));
            app.curves{end + 1} = {out, name, app.palette(mod(numel(app.curves), ...
                                  size(app.palette, 1)) + 1, :)};
            app.redraw();
            app.updateButtons();

            if isnan(out.Lmax)
                app.log(sprintf('%s：全程无正密钥（%.1f s）', name, dt));
            else
                r100 = NaN;
                if out.L(end) >= 100
                    r100 = interp1(out.L, out.R, 100, 'linear', 0);
                end
                if isnan(r100)
                    app.log(sprintf('%s：最远 %.0f km（%.1f s）', name, out.Lmax, dt));
                else
                    app.log(sprintf('%s：R(0)=%.2e，R(100 km)=%.2e，最远 %.0f km（%.1f s）', ...
                                    name, out.R(1), r100, out.Lmax, dt));
                end
            end
        end

        % ============================================================
        % 一键出图：界面 → run_task1/2/3 → results/
        % ============================================================
        function runTaskBatch(app, which)
            % 创建进度对话框；真正的计算在 runTaskSet 中同步执行，
            % batchProgress 负责刷新进度并响应“取消”。
            if app.batchRunning
                app.log('已有出图任务在运行，请等待完成或取消。');
                return
            end
            dlg = uiprogressdlg(app.UIFigure, 'Title', '一键出图', ...
                'Message', '准备…', 'Value', 0, ...
                'Cancelable', 'on', 'CancelText', '取消', ...
                'Indeterminate', 'off');
            cleanupDlg = onCleanup(@() app.closeDialog(dlg));

            app.runTaskSet(which, @(frac, msg) app.batchProgress(dlg, frac, msg));
        end

        function ok = runTaskSet(app, which, progressFcn)
            % 批量出图核心：不依赖对话框，便于无头自检直接调用。
            %   which = 1/2/3 单个任务，0 表示依次全部
            %   progressFcn(frac, msg) 可省略
            ok = false;
            if app.batchRunning
                app.log('已有出图任务在运行，请等待完成或取消。');
                return
            end
            if nargin < 3 || isempty(progressFcn)
                progressFcn = @(~, ~) [];
            end

            app.batchRunning = true;
            app.setBusy(true);
            cleanup = onCleanup(@() app.finishBatch());

            t0 = tic;
            try
                switch which
                    case 1
                        run_task1(app.taskOpt(progressFcn, [0 1]));
                    case 2
                        run_task2(app.taskOpt(progressFcn, [0 1]));
                    case 3
                        run_task3(app.taskOpt(progressFcn, [0 1]));
                    case 0
                        % 按实测耗时加权：任务1/2 不到 1 s，任务3 约 1 分钟
                        app.log('一键出图：按题目默认参数依次生成任务1、2、3（表格编辑不影响出图）。');
                        run_task1(app.taskOpt(progressFcn, [0.00 0.02]));
                        run_task2(app.taskOpt(progressFcn, [0.02 0.10]));
                        run_task3(app.taskOpt(progressFcn, [0.10 1.00]));
                    otherwise
                        error('qkd:gui:badTask', '未知任务编号: %g', which);
                end
                ok = true;
                app.log(sprintf('出图完成（%.1f s）：%s', toc(t0), app.taskFiles(which)));
            catch ME
                if strcmp(ME.identifier, 'qkd:gui:canceled')
                    app.log(sprintf('已取消出图（已完成的图保留），用时 %.1f s。', toc(t0)));
                else
                    app.log(sprintf('出图失败（%.1f s）：%s', toc(t0), ME.message));
                end
            end
        end

        function opt = taskOpt(~, progressFcn, band)
            % 把单个任务的 0–1 进度线性映射到总进度 band = [lo hi]
            opt = struct('onProgress', ...
                @(frac, msg) progressFcn(band(1) + frac * (band(2) - band(1)), msg));
        end

        function batchProgress(app, dlg, frac, msg)
            if ~isvalid(dlg) || dlg.CancelRequested
                error('qkd:gui:canceled', '用户取消出图。');
            end
            dlg.Value = min(max(frac, 0), 1);
            if nargin >= 4 && ~isempty(msg)
                dlg.Message = msg;
            end
            if usejava('desktop'), drawnow limitrate; end
        end

        function closeDialog(~, dlg)
            if isvalid(dlg)
                try
                    close(dlg);
                catch
                    delete(dlg);
                end
            end
        end

        function finishBatch(app)
            app.batchRunning = false;
            app.setBusy(false);
        end

        function s = taskFiles(~, which)
            switch which
                case 1
                    s = '已生成 results/fig1_gauss_threeN.png / .csv';
                case 2
                    s = '已生成 results/fig2_three_methods.png、fig2b_optimal_u.png（含 CSV）';
                case 3
                    s = '已生成 results/fig3_chernoff_global.png、fig3b_optimal_params.png（含 CSV）';
                case 0
                    s = '已生成 Fig.1–3 全部图像与 CSV（results/）';
                otherwise
                    s = '';
            end
        end

        % ============================================================
        % 重绘：把所有已叠加的曲线画一遍
        % ============================================================
        function redraw(app)
            cla(app.ax);
            hold(app.ax, 'on');
            for k = 1:numel(app.curves)
                c = app.curves{k};
                semilogy(app.ax, c{1}.L, c{1}.R, '-', 'Color', c{3}, ...
                         'LineWidth', 1.8, 'DisplayName', c{2});
            end
            if isempty(app.curves)
                title(app.ax, '安全密钥率随传输距离的变化');
                legend(app.ax, 'off');
            else
                title(app.ax, sprintf('密钥率对比（共 %d 条曲线）', numel(app.curves)));
                lg = legend(app.ax, 'Location', 'northeast');
                lg.FontName = cjkFont();
                lg.FontSize = 9;
                lg.Interpreter = 'tex';
            end
            app.ax.YScale = 'log';
            app.ax.YLim   = [1e-12 5e-2];
            xlim(app.ax, [0 app.edLmax.Value]);
        end

        % ============================================================
        % 其它
        % ============================================================
        function clearCurves(app)
            app.curves = {};
            app.redraw();
            app.updateButtons();
            app.log('已清空曲线。');
        end

        function exportPNG(app)
            if isempty(app.curves)
                app.log('没有曲线可导出。');
                return
            end
            [f, fn] = uiputfile('*.png', '导出曲线图', fullfile(pwd, 'keyrate.png'));
            if isequal(f, 0)
                return
            end
            exportgraphics(app.UIFigure, fullfile(fn, f), 'Resolution', 200);
            app.log(['已导出：' fullfile(fn, f)]);
        end

        % ============================================================
        % 控件状态
        % ============================================================
        function setBusy(app, tf)
            if tf
                app.btnRun.Enable   = 'off';
                app.btnClear.Enable = 'off';
                app.btnExport.Enable = 'off';
                app.btnTask1.Enable = 'off';
                app.btnTask2.Enable = 'off';
                app.btnTask3.Enable = 'off';
                app.btnTaskAll.Enable = 'off';
                % 仅桌面环境刷新；-batch 无桌面时对 uifigure 调 drawnow 会挂起
                if usejava('desktop'), drawnow; end
            else
                app.updateButtons();
            end
        end

        function updateButtons(app)
            has = ~isempty(app.curves);
            app.btnRun.Enable    = 'on';
            app.btnClear.Enable  = app.onOff(has);
            app.btnExport.Enable = app.onOff(has);
            app.btnTask1.Enable  = 'on';
            app.btnTask2.Enable  = 'on';
            app.btnTask3.Enable  = 'on';
            app.btnTaskAll.Enable = 'on';
        end

        function s = onOff(~, cond)
            if cond
                s = 'on';
            else
                s = 'off';
            end
        end

        function log(app, msg)
            v = app.txtLog.Value;
            if ischar(v), v = {v}; end
            v{end + 1} = msg;
            if numel(v) > 9, v = v(end - 8:end); end
            app.txtLog.Value = v;
            if usejava('desktop'), drawnow; end
        end

        % ---- 文本转换 ----
        function s = methodCN(~, m)
            switch m
                case 'gauss',     s = '高斯';
                case 'hoeffding', s = '霍夫丁';
                case 'chernoff',  s = '切尔诺夫';
                otherwise,        s = m;
            end
        end

        function s = optCN(~, o)
            switch o
                case 'none',   s = '不优化';
                case 'u',      s = '优化 u';
                case 'global', s = '全局优化';
                otherwise,     s = o;
            end
        end

        function s = numCN(~, N)
            % 10 的整数次幂写成 10^n 的 TeX 形式，便于图例阅读
            k = log10(N);
            if abs(k - round(k)) < 1e-9
                s = sprintf('10^{%d}', round(k));
            else
                s = sprintf('%.1e', N);
            end
        end
    end
end
