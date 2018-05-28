@inline ldof(S::Real) = Int(2S+1)
function Sp(S::Real)
    S2 = Int(2S)
    ret = [0.5sqrt((S2-m2)*(S2+m2+2) ) for m2 in (S2-2):-2:(-S2)]
    return diagm(ret,1)
end
function Sp(S::Real, L::Integer, i::Integer)
    leftN = ldof(S)^(i-1)
    rightN = ldof(S)^(L-i)
    kron(eye(leftN), kron(Sp(S), eye(rightN)))
end

function Sm(S::Real)
    S2 = Int(2S)
    ret = [0.5sqrt((S2+m2)*(S2-m2+2) ) for m2 in (S2):-2:(-S2+2)]
    return diagm(ret,-1)
end
function Sm(S::Real, L::Integer, i::Integer)
    leftN = ldof(S)^(i-1)
    rightN = ldof(S)^(L-i)
    kron(eye(leftN), kron(Sm(S), eye(rightN)))
end

function Sz(S::Real)
    S2 = Int(2S)
    ret = [0.5m2 for m2 in S2:-2:-S2]
    return diagm(ret)
end
function Sz(S::Real, L::Integer, i::Integer)
    leftN = ldof(S)^(i-1)
    rightN = ldof(S)^(L-i)
    kron(eye(leftN), kron(Sz(S), eye(rightN)))
end

function magnetization(S::Real,L::Integer,staggered::Bool=false)
    sz = Sz(S)
    S2 = Int(2S)
    ld = ldof(S)
    N = ld^L
    res = zeros(N)
    for i in 1:N
        for (j,m) in enumerate(digits(i-1,ld,L))
            res[i] += sz[m+1,m+1] * ifelse(staggered && iseven(j), -1.0, 1.0)
        end
    end
    res .*= 1.0/L
    return diagm(res)
end

function spinchain(S::Real, L::Integer, Jz::Real, Jxy::Real, h::Real)
    S2 = Int(2S)
    ld = ldof(S)
    sz = Sz(S)
    sp = Sp(S)
    sm = Sm(S)
    jxy = 0.5Jxy
    bondH = Jz.*kron(sz,sz) .+ jxy.*(kron(sp,sm) .+ kron(sm,sp)) - (0.5h).*(kron(sz, eye(ld)) .+ kron(eye(ld), sz))
    N = ld^L
    H = Jz.*kron(sz, kron(eye(div(N,ld*ld)), sz))
    H .+= jxy .* kron(sm, kron(eye(div(N,ld*ld)), sp))
    H .+= jxy .* kron(sp, kron(eye(div(N,ld*ld)), sm))
    H .+= (-0.5h) .* kron(sz, eye(div(N,ld)))
    H .+= (-0.5h) .* kron(eye(div(N,ld)), sz)

    leftN = 1
    rightN = ld^(L-2)
    for i in 1:L-1
        H .+= kron(eye(leftN), kron(bondH, eye(rightN)))
        leftN *= ld
        rightN = div(rightN,ld)
    end
    return H
end

doc"""
\mathcal{H} = Jz \sum_i(S^z_i S^z_{i+1}) + 0.5Jxy \sum_i(S^+_i S^-_{i+1} + h.c.) - h \sum_i S^z_i
"""
struct SpinChainSolver <: Solver
    ef :: Base.LinAlg.Eigen{Float64, Float64, Matrix{Float64}, Vector{Float64}}
    S :: Float64
    L :: Int
    SpinChainSolver(S::Real, L::Integer; Jz::Real=1.0, Jxy::Real=1.0, h::Real=0.0) = new(eigfact(spinchain(S, L, Jz, Jxy, h)), S, L)
end

creator(solver::SpinChainSolver) = Sp(solver.S)
creator(solver::SpinChainSolver, i::Integer) = Sp(solver.S, solver.L, i)
annihilator(solver::SpinChainSolver) = Sm(solver.S)
annihilator(solver::SpinChainSolver, i::Integer) = Sm(solver.S, solver.L, i)
basis(solver::SpinChainSolver) = Sz(solver.S)
basis(solver::SpinChainSolver, i::Integer) = Sz(solver.S, solver.L, i)
orderparameter(solver::SpinChainSolver, staggered::Bool=false) = magnetization(solver.S, solver.L, staggered)

