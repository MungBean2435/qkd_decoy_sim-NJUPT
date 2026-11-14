function out = runCase(p, spec) 
%   out = qkd.runCase(p, spec)
%  输入
%     p    : qkd.params() 给的参数表（调用方可以改里面的字段再传进来）
%     spec : 「算什么的说明书」，字段如下
%           .method  'gauss' | 'hoeffding' | 'chernoff'   用哪种统计界
%           .N       发射脉冲数（1e8 ~ 1e10）
%           .eps     说错的概率（默认 1e-7）
%           .L       [起点 终点 步长]，单位 km，例如 [0 300 1]
%           .opt     'none' | 'u' | 'global'
%           .optU    （只有 opt='u' 用）结构体：.lb .ub .n .mode('perDistance'|'fixed')
%           .optG    （只有 opt='global' 用）结构体：.npop .ngen
%                    .strideL 粗网格步长（km，默认 5；设成 1 就是逐点全优化）
%           .onProgress  可选，进度回调（GUI 用它更新进度条）
%
%  输出 out
%           .L .R        距离数组和对应的密钥率
%           .u .v .Pu .Pv 每个距离点实际用的（或优化出来的）参数
%           .Lmax        最远成码距离：最后一个 R>0 的点
%           .method .N .opt .spec .p   把输入原样带出来，方便画图时写标题

if ~isfield(spec, 'eps') || isempty(spec.eps), spec.eps = 1e-7; end
if ~isfield(spec, 'opt') || isempty(spec.opt), spec.opt = 'none'; end

L = spec.L(1) : spec.L(3) : spec.L(2);
n = numel(L); 

stride = max(1, floor(n / 50));

out = struct();
out.L   = L;
out.R   = zeros(1, n);
out.u   = p.u * ones(1, n);
out.v   = p.v * ones(1, n);
out.Pu  = p.Pu * ones(1, n);
out.Pv  = p.Pv * ones(1, n);
out.method = spec.method;
out.N   = spec.N;
out.eps = spec.eps;
out.opt = spec.opt;
out.spec = spec;
out.p    = p;

switch lower(spec.opt)

    case 'none'
        % ============ 模式一：参数全固定，只扫距离（任务 1）============
        for i = 1:n
            out.R(i) = rateFor(p, L(i), spec, p.u, p.v, p.Pu, p.Pv);
            if i == 1 || i == n || mod(i, stride) == 0
                notifyProgress(spec, i / n, ...
                    sprintf('扫描距离 L = %.0f km（%d/%d）', L(i), i, n));
            end
        end

    case 'u'
        % ============ 模式二：只优化信号态光强 u（任务 2）============
        ug = linspace(spec.optU.lb, spec.optU.ub, spec.optU.n);

        if strcmpi(spec.optU.mode, 'perDistance')        
            for i = 1:n
                % 一次把 601 个候选全算出来
                Rv = rateFor(p, L(i), spec, ug, p.v, p.Pu, p.Pv);
                [rmax, k] = max(Rv);   % 挑最大那个，k 是它在候选里的位置
                out.R(i) = rmax;
                out.u(i) = ug(k);
                if i == 1 || i == n || mod(i, stride) == 0
                    notifyProgress(spec, i / n, ...
                        sprintf('逐距离优化 u：L = %.0f km（%d/%d）', L(i), i, n));
                end
            end
        else
            error('qkd:runCase:badOptU', 'optU.mode 只能是 perDistance ');
        end

    case 'global'
        % ============ 模式三：四个参数一起优化（任务 3）============
        % 联合优化 (u, v, P_u, P_v)。注意这里没有解析解，只能靠搜索算法。
        if ~isfield(spec, 'optG') || isempty(spec.optG)
            spec.optG = struct('npop', 40, 'ngen', 60);   % 种群大小、迭代代数
        end
        gopt = spec.optG;

        % 粗网格步长（km），默认 5。
        if ~isfield(gopt, 'strideL') || isempty(gopt.strideL)
            gopt.strideL = 5;
        end
        stepIdx = max(1, round(gopt.strideL / spec.L(3)));   % 5 km / 1 km = 每隔 5 个点
        idxC    = unique([1:stepIdx:n, n]);                  % 粗网格点的下标（保证带上最后一个点）
        nc      = numel(idxC);

        % 先准备好容器，装每个粗网格点优化出来的四个参数和对应的密钥率
        Xu = nan(1, nc);  Xv  = nan(1, nc);
        XPu = nan(1, nc); XPv = nan(1, nc);
        Rc  = zeros(1, nc);
        for j = 1:nc
            i = idxC(j);
            % 交给下面的 optimizeGlobal 去做差分进化搜索
            [xb, fb] = optimizeGlobal(p, L(i), spec, gopt);
            Xu(j)  = xb(1);                 % u
            Xv(j)  = xb(1) * xb(2);         % v = u × 比值（优化器内部用比值，见 objFun）
            XPu(j) = xb(3);                 % P_u
            XPv(j) = xb(4);                 % P_v
            Rc(j)  = fb;                    % 这个点能到的最优密钥率
            % 全局优化很慢，所以每算完一个点就报一次进度，用户点「取消」才能及时生效
            notifyProgress(spec, j / nc, ...
                sprintf('全局优化 (u, v, P_u, P_v)：L = %.0f km（%d/%d）', L(i), j, nc));
        end

        if nc == 1
            % 只有一个点（自检里常这么用，比如 L=[100 100 1]）：
            % 就把优化出来的这组参数铺到整条曲线上重算一遍。
            out.u  = Xu  * ones(1, n);
            out.v  = Xv  * ones(1, n);
            out.Pu = XPu * ones(1, n);
            out.Pv = XPv * ones(1, n);
            out.R  = rateFor(p, L, spec, out.u, out.v, out.Pu, out.Pv);
        else
            % 只有「确实算出了正密钥」的粗点才拿来插值；
            % 已经没密钥的区域（R=0 或参数是 NaN）不参与，避免把曲线插到不该去的地方。
            good = isfinite(Xu) & isfinite(Xv) & isfinite(XPu) & isfinite(XPv) & (Rc > 0);
            if nnz(good) < 2
                % 有密钥的点不足 2 个，根本连不成线，整条曲线按「无密钥」处理
                out.R = zeros(1, n);
            else
                Lg = L(idxC(good));
                % 关键技巧：插值的是「参数」，不是曲线！
                % 把粗网格上求出的最优 u,v,Pu,Pv 插值到每个 1 km 点上，
                % 然后逐个点重新算 R。这样每个细点都是真算出来的，
                % 只是因为参数未必对该点最优，所以结果略偏保守（宁可低估）。
                out.u  = interp1(Lg, Xu(good),  L, 'linear', NaN);
                out.v  = interp1(Lg, Xv(good),  L, 'linear', NaN);
                out.Pu = interp1(Lg, XPu(good), L, 'linear', NaN);
                out.Pv = interp1(Lg, XPv(good), L, 'linear', NaN);
                out.R  = rateFor(p, L, spec, out.u, out.v, out.Pu, out.Pv);

                % 补救：曲线在远处会「断崖式」归零。粗网格每 5 km 才有一个点，
                % 可能把最后不足 5 km 的成码区整段漏掉，让 Lmax 少算几公里。
                % 所以把「最后一个有密钥的粗点」到「下一个粗点」之间逐点补算一遍。
                kl = find(Rc > 0, 1, 'last');
                if ~isempty(kl) && kl < nc
                    for i = idxC(kl) + 1 : idxC(kl + 1) - 1
                        [xb, fb] = optimizeGlobal(p, L(i), spec, gopt);
                        out.u(i)  = xb(1);
                        out.v(i)  = xb(1) * xb(2);
                        out.Pu(i) = xb(3);
                        out.Pv(i) = xb(4);
                        out.R(i)  = fb;
                    end
                    notifyProgress(spec, 1, '断崖区已按原网格细化');
                end
            end
        end

    otherwise
        error('qkd:runCase:badOpt', '未知优化模式: %s', spec.opt);
end

% 收尾一：没有密钥的地方（R<=0）不要给「最优参数」。
% 因为那边根本不存在最优，硬画出来会让参数曲线出现无意义的跳变，
% 所以统一置成 NaN，画图时自然断掉（这是「别让图说谎」的小细节）。
if ~strcmpi(out.opt, 'none')
    dead = out.R <= 0;
    out.u(dead)  = NaN;   out.v(dead)  = NaN;
    out.Pu(dead) = NaN;   out.Pv(dead) = NaN;
end

% 收尾二：定义并算出「最远成码距离」Lmax = 最后一个还有正密钥的距离点。
% 这是三个题目都要报的核心指标（比曲线本身更好比较）。
idx = find(out.R > 0, 1, 'last');
if isempty(idx)
    out.Lmax = NaN;     % 全程都没密钥（参数明显不合理时才会发生）
else
    out.Lmax = out.L(idx);
end

end

% ======================================================================
% 下面是内部小函数（局部函数）：外面看不到，只在 runCase 内部用。
% ======================================================================

function R = rateFor(p, L, spec, u, v, Pu, Pv)
% 把「待优化的参数」写回参数表，再交给内核算密钥率。
% 为什么这样做？因为 keyRateAt 只认参数表 p，不认「优化变量」，
% 所以优化的本质就是：改 p → 重算 → 比较 → 再改。这个函数就是那个「改」的动作。
q = p;          % 先复制一份，绝不污染调用方传进来的 p（重要习惯）
q.u  = u;
q.v  = v;
q.Pu = Pu;
q.Pv = Pv;
q.P0 = 1 - Pu - Pv;    % 真空态概率要跟着一起变，否则三种强度就不归一了
R = qkd.keyRateAt(q, L, spec);
end

function R = objFun(p, L, spec, X)
% 目标函数：「给定一组参数，能得到多少密钥率」。
% 优化器看不懂物理，它只会问这一个问题，所以这里顺手把「不合法的参数」判掉。
% X 的每一行是一个候选：[u, v/u, P_u, P_v]
u  = X(:, 1);
v  = X(:, 1) .* X(:, 2);   % 用「比值」表示 v，天然保证 v 和 u 同量级
Pu = X(:, 3);
Pv = X(:, 4);
R  = rateFor(p, L, spec, u, v, Pu, Pv);
% 物理可行性检查：不满足的组合直接把密钥率记成 0（等于判死刑）。
%   v 必须比 u 小（否则 (3.28) 的分母会变号）
%   Pu+Pv 不能超过 0.95（还得给真空态留点位置）
%   三个概率都必须为正
bad = (v >= u) | (Pu + Pv > 0.95) | (Pu <= 0) | (Pv <= 0) | (u <= v);
R(bad) = 0;
R(~isfinite(R)) = 0;    % 计算里冒出 NaN 也一律当 0，免得把优化器带跑偏
end

function [xb, fb] = optimizeGlobal(p, L, spec, opt)
% 差分进化（Differential Evolution）：一种「不靠导数」的搜索方法。
% 直觉：撒一群候选点 → 让好的当模板、互相之间取差去扰动 → 好的留下、差的淘汰。
% 为什么不用更简单的梯度法？因为目标函数既非凸又带约束，还没有解析导数。
lb  = [ 0.10,  0.02, 0.05, 0.02];   % 下界：u, v/u, Pu, Pv
ub  = [ 1.40,  0.90, 0.90, 0.90];   % 上界
Dm  = numel(lb);                    % 变量个数 = 4
rng(20260101);                      % 固定随机种子：保证每次跑出来一模一样，方便复现

% 第一步：在边界内随机撒 npop 个候选（第一代种群）
npop = opt.npop;
pop  = lb + rand(npop, Dm) .* (ub - lb);
fit  = objFun(p, L, spec, pop);     % 一次算完一整代（向量化，比一个个算快得多）

idx = zeros(npop, 3);
for g = 1:opt.ngen                   % 逐代进化
    % 给每个个体抽 3 个「别的个体」的编号，要求互不相同
    for i = 1:npop
        idx(i, :) = randperm(npop, 3);
    end

    % 变异：拿两个个体的差去推着第三个个体走（F=0.6 是常用步长）
    mut = pop(idx(:, 1), :) + 0.6 * (pop(idx(:, 2), :) - pop(idx(:, 3), :));
    mut = min(max(mut, lb), ub);      % 越界就拉回边界

    % 交叉：每个维度以 0.7 的概率采用变异结果，其余保留原样
    cross = rand(npop, Dm) < 0.7;
    cross(sub2ind([npop, Dm], (1:npop)', randi(Dm, npop, 1))) = true;  % 至少换一维

    trial = pop;
    trial(cross) = mut(cross);

    % 整代一次评估：objFun 本来就支持矩阵输入，npop 个候选只跑一次内核
    ft = objFun(p, L, spec, trial);

    % 比父代好的才留下（这就是「进化」）
    better = ft > fit;
    pop(better, :) = trial(better, :);
    fit(better)    = ft(better);
end

[fb, k] = max(fit);   % 找出这一代里最好的那个
xb = pop(k, :);

% 第二步：局部打磨。差分进化擅长「找到大致方向」，但不擅长「精确到小数点后三位」，
% 所以在最优点附近做个坐标下降：逐维度左试一点右试一点，好了就挪过去，
% 连续 30 轮都没进步就把步长减半，直到步长小到没意义为止。
step = 0.05 * (ub - lb);
for iter = 1:30
    improved = false;
    for d = 1:Dm
        for s = [-1, 1]
            cand = xb;
            cand(d) = min(max(cand(d) + s * step(d), lb(d)), ub(d));
            fc = objFun(p, L, spec, cand);
            if fc > fb
                xb = cand; fb = fc; improved = true;
            end
        end
    end
    if ~improved
        step = step * 0.5;
        if all(step < 1e-4), break; end
    end
end

end


function notifyProgress(spec, frac, msg)

if isfield(spec, 'onProgress') && ~isempty(spec.onProgress)
    spec.onProgress(min(max(frac, 0), 1), msg);   % 夹在 0~1 之间，防手滑
end
end
