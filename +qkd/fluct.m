function D = fluct(method, eps)
%FLUCT 给「估出来的数」留余量：三种算法任选一种（高斯 / 霍夫丁 / 切尔诺夫）
%
%   D = qkd.fluct(method, eps)
%
% ------------------------------------------------------------------------
%  为什么需要这一步？一句话：样本不够多，估出来的数不老实。
%
%  真实世界里，Q（收到光的概率）是个固定的数，但我们只能发有限个脉冲
%  （题目里是 1e8 ~ 1e10 个）去「估」它。于是估出来的 Q* 会和真值 Q 有偏差。
%  安全分析不能自欺欺人，必须说清楚：我有 1-ε 的把握，真值落在 [下界, 上界]。
%
%  ε（eps）就是「我说错的概率」，题目取 1e-7（千万分之一）。
%  ε 越小越安全，但余量也要留得越宽 → 能算出的密钥越少、传得越近。
%
%  三种方法，其实就是三种「留多少余量」的算法：
%    高斯   ：相信「样本一多就接近正态分布」，余量最窄 → 最乐观（但需要大 N）
%    霍夫丁 ：不假设任何分布，只要求「有界」，最坏情况 → 最保守、余量最宽
%    切尔诺夫：专门为「计数」设计，余量介于两者之间，而且上下不对称
%
%  记住这个顺序：余量越宽 → 扣掉的越多 → 最远能传的距离越短。
%  这就是任务 2 里三条曲线高低不同的全部原因。
% ------------------------------------------------------------------------
%
%  这个函数聪明的地方：它返回的不是一个数，而是三个「函数」（句柄）。
%
%    用法是 D.Q(增益, 脉冲数, 总计数) → 返回 [下界, 上界]。
%    也就是说：「怎么留余量」这件事被打包好了，用的时候才代入具体数字。
%
%  这样设计的好处：estimate.m 从头到尾不用写一句
%  「如果是高斯就……如果是霍夫丁就……」，它只管调 D.Q。以后想加第四种方法，
%  只要在这里加一个 case，别的文件一个字都不用改。
%
%  MATLAB 语法点：@(x) 某某 是「匿名函数」，返回的是函数句柄（相当于函数指针）；
%  赋值时外面的 gamma、eps 会被「记住」（闭包）。所以下面三个句柄各带各的参数，
%  不会互相干扰。
% ------------------------------------------------------------------------
%
%  method : 'gauss' | 'hoeffding' | 'chernoff'
%  eps    : 说错的概率（默认 1e-7，对应指导书里的 gamma=5.3）
%
%  返回 D 里有三个句柄，参数含义统一：
%       [lo, hi] = D.Q (Q,  Nl, nW)   % 增益 Q_l 的上下界
%       [lo, hi] = D.T (T,  Nl, nW)   % 误码计数 T_l 的上下界
%       [lo, hi] = D.Y0(Y0, N0)       % 真空态响应率的上下界（真空不选基，单独处理）
%       Nl = 这个强度在这个基里发了多少个脉冲
%       nW = 这个基里所有强度加起来收到多少个事件（霍夫丁界要用，见指导书 (3.33)）
% ------------------------------------------------------------------------

if nargin < 2 || isempty(eps)
    eps = 1e-7;     % MATLAB 语法：没传参数就用默认值，这是最基本的「容错」写法
end

% ---- 缓存（小技巧，不影响物理）----
% 一条曲线要调这个函数几百次，但 method 和 eps 在这条曲线里根本不变。
% 每次重新搭一遍结构体、造三个句柄太浪费，所以第一次算完就记下来，下次直接返回。
% MATLAB 语法：persistent 变量「函数退出后还记得」，相当于这个函数自己的小仓库。
persistent cacheKey cacheD
key = sprintf('%s|%.17g', lower(method), eps);   % 17 位有效数字，保证能区分不同的 eps
if ~isempty(cacheKey) && strcmp(cacheKey, key)
    D = cacheD;
    return
end

D.eps    = eps;
D.method = lower(method);   % 统一转小写，'Gauss' 和 'gauss' 当同一个

switch D.method

    case 'gauss'
        % 高斯界（对应指导书 (3.24)(3.25)）
        % 思路：抛硬币次数够多时，正面比例近似正态分布，标准差是 sqrt(Q/N)。
        % 所以余量 = gamma * sqrt(Q/N)，其中 gamma 由「允许错多少」决定：
        %     gamma = sqrt(2)*erfcinv(eps)
        % eps=1e-7 时 gamma≈5.33，也就是说要留 5.33 个标准差才敢开口。
        % 这个 gamma 被下面的句柄「记住」，所以只需算一次。
        gamma = sqrt(2) * erfcinv(eps);
        D.name = 'Gaussian';
        D.desc = sprintf('高斯/中心极限定理：ΔQ=γ·sqrt(Q/N)，γ=%.3f (eps=%.0e)', gamma, eps);
        D.Q    = @(Q, Nl, nW) gaussBound(Q, Nl, gamma);
        D.T    = @(T, Nl, nW) gaussBound(T, Nl, gamma);
        D.Y0   = @(Y0, N0)    gaussBound(Y0, N0, gamma);

    case 'hoeffding'
        % 霍夫丁界（对应指导书 (3.31)(3.33)）
        % 思路：我不猜数据是什么分布，只用「它不会超过某个范围」这一个条件，
        % 就给出最坏情况的余量。代价是余量特别宽。
        %     |Q* - Q| = sqrt(nW/2 * ln(1/eps)) / Nl
        % 注意它用的是「这个基里收到的总事件数 nW」，这是指导书 (3.33) 的写法。
        k = sqrt(0.5 * log(1 / eps));
        D.name = 'Hoeffding';
        D.desc = sprintf('霍夫丁：|ΔQ|=sqrt(nW·ln(1/eps)/2)/N，k=%.3f', k);
        D.Q    = @(Q, Nl, nW) hoeffBound(Q, Nl, nW, k);
        D.T    = @(T, Nl, nW) hoeffBound(T, Nl, nW, k);
        D.Y0   = @(Y0, N0)    hoeffBoundY0(Y0, N0, k);

    case 'chernoff'
        % 切尔诺夫界（对应指导书 (3.37)）
        % 思路：计数不是抛硬币，它天生适合用切尔诺夫界的乘性余量。
        % 关键特点：上下不对称——下界留得宽（往少了算），上界留得紧（往多了算）。
        %     E(x) = x + δ,  δ ∈ [-Δ, Δ̂]
        %     Δ  = sqrt(2x·ln(16/eps^4))     ← 下界用，故意留宽
        %     Δ̂  = sqrt(2x·ln(eps^-1.5))    ← 上界用，相对紧
        % 为什么故意不对称？见下面 estimate.m 的注释：算密钥时用下界、算误码时用上界，
        % 两个方向都取「对自己不利」的那一侧，冗余换安全。
        D.name = 'Chernoff';
        D.desc = sprintf('切尔诺夫：Δ=sqrt(2x·ln(16/eps^4))，Δ̂=sqrt(2x·ln(eps^{-1.5}))，eps=%.0e', eps);
        D.Q    = @(Q, Nl, nW) chernoffBound(Q, Nl, eps);
        D.T    = @(T, Nl, nW) chernoffBound(T, Nl, eps);
        D.Y0   = @(Y0, N0)    chernoffBound(Y0, N0, eps);

    otherwise
        error('qkd:fluct:badMethod', '未知统计起伏方法: %s', method);
end

% 全部搭好之后再入仓。出错的那条路径不会写缓存，
% 免得把「半个 D」留给下一次调用（这是个容易踩的坑）。
cacheKey = key;
cacheD   = D;

end

% ======================================================================
% 下面是三种方法各自的「余量计算器」，都是本文件的内部小函数（局部函数），
% 外面看不见、也调不到，改它们不会影响别的文件。
% ======================================================================

function [lo, hi] = gaussBound(x, N, gamma)
% 高斯：余量 = gamma*sqrt(x/N)，用绝对形式写最直观
N   = max(N, realmin);   % MATLAB 语法：realmin 是最小的正数，防「除以 0」
x   = max(x, 0);         % 概率不可能是负数，先夹一下
dlt = gamma .* sqrt(x ./ N);
lo  = max(x - dlt, 0);   % 下界不能是负的
hi  = x + dlt;
end

function [lo, hi] = hoeffBound(x, N, nW, k)
% 霍夫丁：|ΔQ| = k*sqrt(nW)/N，k = sqrt(ln(1/eps)/2)
N   = max(N, realmin);
dlt = k .* sqrt(max(nW, 0)) ./ N;
lo  = max(x - dlt, 0);
hi  = x + dlt;
end

function [lo, hi] = hoeffBoundY0(Y0, N0, k)
% 真空态的霍夫丁界（指导书 (3.35) 的注释）
% 真空态没有「基」的概念，所以只用真空脉冲数 N0，不用 nW。
N0  = max(N0, realmin);
dlt = k .* sqrt(max(Y0, 0) ./ N0);
lo  = max(Y0 - dlt, 0);
hi  = Y0 + dlt;
end

function [lo, hi] = chernoffBound(x, N, eps)
% 切尔诺夫：先把「比例」还原成「计数」再定界，最后除回比例。
% x 是比例，xobs = x*N 就是观测到的个数。
N    = max(N, realmin);
xobs = max(x, 0) .* N;
dLo  = sqrt(2 .* xobs .* log(16 ./ eps.^4));   % 下界余量（宽）
dHi  = sqrt(2 .* xobs .* log(eps .^-1.5));     % 上界余量（紧）
lo   = max(xobs - dLo, 0) ./ N;
hi   = (xobs + dHi) ./ N;
end
