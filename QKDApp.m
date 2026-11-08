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
        ax                % 曲线区
        txtLog            % 状态/日志区
        curves = {}       % 已叠加的曲线：每项 {out, 名称, 颜色}
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
        end
    end

    methods (Access = public)   % 全部公开，便于脚本/自检直接驱动（界面层本身无状态风险）

        % ============================================================
        % 界面搭建
        % ============================================================
        function buildUI(app)
            app.UIFigure = uifigure('Name', 'WCS 三强度诱骗态 BB84 仿真软件', ...
                                    'Position', [30 30 1240 820], ...
                                    'Color', [0.96 0.96 0.97]);

            % ---------- 左侧：参数与设置 ----------
            pnl = uipanel(app.UIFigure, 'Title', '参数与计算设置', ...
                          'Position', [12 12 430 796], 'FontName', 'Microsoft YaHei', ...
                          'FontSize', 11, 'BackgroundColor', [0.96 0.96 0.97]);

            data = cell(numel(app.KEYS), 2);
            for i = 1:numel(app.KEYS)
                data{i, 1} = app.SHOW{i};
                data{i, 2} = app.fmtVal(app.p.(app.KEYS{i}));
            end
            app.tblParams = uitable(pnl, 'Data', data, ...
                'ColumnName', {'参数', '取值'}, 'ColumnFormat', {'char', 'char'}, ...
                'ColumnEditable', [false true], 'ColumnWidth', {232 122}, ...
                'RowName', [], 'FontName', 'Microsoft YaHei', 'FontSize', 9, ...
                'Position', [10 438 410 332], ...
                'CellEditCallback', @(~, e) app.onEditParam(e));

            % ---- 计算设置 ----
            y = 412;
            uilabel(pnl, 'Text', '统计起伏方法', 'Position', [14 y 120 22], ...
                    'FontName', 'Microsoft YaHei');
            app.ddlMethod = uidropdown(pnl, 'Position', [138 y-3 278 26], ...
                'Items', {'高斯 (Gaussian)', '霍夫丁 (Hoeffding)', '切尔诺夫 (Chernoff)'}, ...
                'ItemsData', {'gauss', 'hoeffding', 'chernoff'}, ...
                'Value', 'gauss', 'FontName', 'Microsoft YaHei');

            y = y - 34;
            uilabel(pnl, 'Text', '发射脉冲数 N', 'Position', [14 y 120 22], ...
                    'FontName', 'Microsoft YaHei');
            app.edN = uieditfield(pnl, 'numeric', 'Position', [138 y-3 278 26], ...
                                  'Value', 1e9, 'Limits', [1e4 1e14]);

            y = y - 34;
            uilabel(pnl, 'Text', '失败概率 eps', 'Position', [14 y 120 22], ...
                    'FontName', 'Microsoft YaHei');
            app.edEps = uieditfield(pnl, 'numeric', 'Position', [138 y-3 278 26], ...
                                    'Value', 1e-7, 'Limits', [1e-15 1e-2]);

            y = y - 34;
            uilabel(pnl, 'Text', '优化方式', 'Position', [14 y 120 22], ...
                    'FontName', 'Microsoft YaHei');
            app.ddlOpt = uidropdown(pnl, 'Position', [138 y-3 278 26], ...
                'Items', {'不优化', '仅优化信号态 u', '全局优化 (u, v, P_u, P_v)'}, ...
                'ItemsData', {'none', 'u', 'global'}, ...
                'Value', 'none', 'FontName', 'Microsoft YaHei');

            y = y - 34;
            uilabel(pnl, 'Text', '最大距离 (km)', 'Position', [14 y 108 22], ...
                    'FontName', 'Microsoft YaHei');
            app.edLmax = uieditfield(pnl, 'numeric', 'Position', [130 y-3 120 26], ...
                                     'Value', 300, 'Limits', [10 1000]);
            uilabel(pnl, 'Text', '步长 (km)', 'Position', [262 y 58 22], ...
                    'FontName', 'Microsoft YaHei');
            app.edLstep = uieditfield(pnl, 'numeric', 'Position', [322 y-3 94 26], ...
                                      'Value', 1, 'Limits', [0.1 20]);

            % ---- 按钮 ----
            by = 226;
            app.btnRun = uibutton(pnl, 'Text', '运行并叠加曲线', ...
                'Position', [10 by 146 34], 'FontName', 'Microsoft YaHei', ...
                'FontWeight', 'bold', 'BackgroundColor', [0.20 0.50 0.85], ...
                'FontColor', [1 1 1], 'ButtonPushedFcn', @(~, ~) app.runSim());
            app.btnClear = uibutton(pnl, 'Text', '清空曲线', ...
                'Position', [166 by 112 34], 'FontName', 'Microsoft YaHei', ...
                'ButtonPushedFcn', @(~, ~) app.clearCurves());
            app.btnExport = uibutton(pnl, 'Text', '导出 PNG', ...
                'Position', [288 by 128 34], 'FontName', 'Microsoft YaHei', ...
                'ButtonPushedFcn', @(~, ~) app.exportPNG());

            % ---- 日志 ----
            app.txtLog = uitextarea(pnl, 'Position', [10 10 410 200], ...
                'Editable', 'off', 'FontName', 'Microsoft YaHei', 'FontSize', 10, ...
                'Value', {'就绪：修改参数后点击“运行并叠加曲线”。', ...
                          '多次运行会叠加不同配置的曲线，便于对比。'});

            % ---------- 右侧：曲线区 ----------
            app.ax = uiaxes(app.UIFigure, 'Position', [460 40 760 770]);
            app.ax.YScale  = 'log';
            app.ax.FontName = 'Microsoft YaHei';
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

            spec = struct();
            spec.method = app.ddlMethod.Value;
            spec.N      = app.edN.Value;
            spec.eps    = app.edEps.Value;
            spec.L      = [0 app.edLmax.Value app.edLstep.Value];
            spec.opt    = app.ddlOpt.Value;
            spec.optU   = struct('lb', 0.10, 'ub', 1.30, 'n', 61, 'mode', 'perDistance');
            spec.optG   = struct('npop', 30, 'ngen', 40);

            app.log('计算中…');
            if usejava('desktop'), drawnow; end
            t0  = tic;
            out = qkd.runCase(app.p, spec);
            dt  = toc(t0);

            name = sprintf('%s | N = %s | %s', app.methodCN(spec.method), ...
                           app.numCN(spec.N), app.optCN(spec.opt));
            app.curves{end + 1} = {out, name, app.palette(mod(numel(app.curves), ...
                                  size(app.palette, 1)) + 1, :)};
            app.redraw();

            if isnan(out.Lmax)
                app.log(sprintf('%s：全程无正密钥（%.1f s）', name, dt));
            else
                app.log(sprintf('%s：最远 %.0f km（%.1f s）', name, out.Lmax, dt));
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
                lg.FontName = 'Microsoft YaHei';
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

        function log(app, msg)
            v = app.txtLog.Value;
            if ischar(v), v = {v}; end
            v{end + 1} = msg;
            if numel(v) > 11, v = v(end - 10:end); end
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
