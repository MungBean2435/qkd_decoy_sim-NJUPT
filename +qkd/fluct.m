function D = fluct(method, eps)


if nargin < 2 || isempty(eps)
    eps = 1e-7;     % MATLAB 语法：没传参数就用默认值，这是最基本的「容错」写法
end


persistent cacheKey cacheD
key = sprintf('%s|%.17g', lower(method), eps);   
if ~isempty(cacheKey) && strcmp(cacheKey, key)
    D = cacheD;
    return
end

D.eps    = eps;
D.method = lower(method);  

switch D.method

    case 'gauss'
        % 高斯界（对应指导书 (3.24)(3.25)）
        gamma = sqrt(2) * erfcinv(eps);
        D.name = 'Gaussian';
        D.desc = sprintf('高斯/中心极限定理：ΔQ=γ·sqrt(Q/N)，γ=%.3f (eps=%.0e)', gamma, eps);
        D.Q    = @(Q, Nl, nW) gaussBound(Q, Nl, gamma);
        D.T    = @(T, Nl, nW) gaussBound(T, Nl, gamma);
        D.Y0   = @(Y0, N0)    gaussBound(Y0, N0, gamma);

    case 'hoeffding'
        % 霍夫丁界（对应指导书 (3.31)(3.33)）
        k = sqrt(0.5 * log(1 / eps));
        D.name = 'Hoeffding';
        D.desc = sprintf('霍夫丁：|ΔQ|=sqrt(nW·ln(1/eps)/2)/N，k=%.3f', k);
        D.Q    = @(Q, Nl, nW) hoeffBound(Q, Nl, nW, k);
        D.T    = @(T, Nl, nW) hoeffBound(T, Nl, nW, k);
        D.Y0   = @(Y0, N0)    hoeffBoundY0(Y0, N0, k);

    case 'chernoff'
        % 切尔诺夫界（对应指导书 (3.37)）
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


function [lo, hi] = gaussBound(x, N, gamma)
% 高斯：余量 = gamma*sqrt(x/N)，用绝对形式写最直观
N   = max(N, realmin);  
x   = max(x, 0);        
dlt = gamma .* sqrt(x ./ N);
lo  = max(x - dlt, 0);  
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
