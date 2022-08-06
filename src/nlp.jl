export ADNLPModel

mutable struct ADNLPModel{T, S, Si} <: AbstractNLPModel{T, S}
  meta::NLPModelMeta{T, S}
  counters::Counters
  adbackend::ADModelBackend

  # Functions
  f

  clinrows::Si
  clincols::Si
  clinvals::S

  c
end

ADNLPModel(
  meta::NLPModelMeta{T, S},
  counters::Counters,
  adbackend::ADModelBackend,
  f,
  c,
) where {T, S} = ADNLPModel(meta, counters, adbackend, f, Int[], Int[], T[], c)

ADNLPModels.show_header(io::IO, nlp::ADNLPModel) =
  println(io, "ADNLPModel - Model with automatic differentiation backend $(nlp.adbackend)")

"""
    ADNLPModel(f, x0)
    ADNLPModel(f, x0, lvar, uvar)
    ADNLPModel(f, x0, clinrows, clincols, clinvals, lcon, ucon)
    ADNLPModel(f, x0, A, lcon, ucon)
    ADNLPModel(f, x0, c, lcon, ucon)
    ADNLPModel(f, x0, clinrows, clincols, clinvals, c, lcon, ucon)
    ADNLPModel(f, x0, A, c, lcon, ucon)
    ADNLPModel(f, x0, lvar, uvar, clinrows, clincols, clinvals, lcon, ucon)
    ADNLPModel(f, x0, lvar, uvar, A, lcon, ucon)
    ADNLPModel(f, x0, lvar, uvar, c, lcon, ucon)
    ADNLPModel(f, x0, lvar, uvar, clinrows, clincols, clinvals, c, lcon, ucon)
    ADNLPModel(f, x0, lvar, uvar, A, c, lcon, ucon)

ADNLPModel is an AbstractNLPModel using automatic differentiation to compute the derivatives.
The problem is defined as

     min  f(x)
    s.to  lcon ≤ (  Ax  ) ≤ ucon
                 ( c(x) )
          lvar ≤   x  ≤ uvar.

The following keyword arguments are available to all constructors:

- `minimize`: A boolean indicating whether this is a minimization problem (default: true)
- `name`: The name of the model (default: "Generic")

The following keyword arguments are available to the constructors for constrained problems:

- `y0`: An inital estimate to the Lagrangian multipliers (default: zeros)

`ADNLPModel` uses `ForwardDiff` for the automatic differentiation by default.
One can specify a new backend with the keyword arguments `backend::ADNLPModels.ADBackend`.
There are three pre-coded backends:
- the default `ForwardDiffAD`.
- `ReverseDiffAD` accessible after loading `ReverseDiff.jl` in your environment.
- `ZygoteDiffAD` accessible after loading `Zygote.jl` in your environment.
For an advanced usage, one can define its own backend and redefine the API as done in [ADNLPModels.jl/src/forward.jl](https://github.com/JuliaSmoothOptimizers/ADNLPModels.jl/blob/main/src/forward.jl).

# Examples
```julia
using ADNLPModels
f(x) = sum(x)
x0 = ones(3)
nvar = 3
ADNLPModel(f, x0) # uses the default ForwardDiffAD backend.

using ReverseDiff
ADNLPModel(f, x0; backend = ADNLPModels.ReverseDiffAD)

using Zygote
ADNLPModel(f, x0; backend = ADNLPModels.ZygoteAD)
```

```julia
using ADNLPModels
f(x) = sum(x)
x0 = ones(3)
c(x) = [1x[1] + x[2]; x[2]]
nvar, ncon = 3, 2
ADNLPModel(f, x0, c, zeros(ncon), zeros(ncon)) # uses the default ForwardDiffAD backend.

using ReverseDiff
ADNLPModel(f, x0, c, zeros(ncon), zeros(ncon); backend = ADNLPModels.ReverseDiffAD)

using Zygote
ADNLPModel(f, x0, c, zeros(ncon), zeros(ncon); backend = ADNLPModels.ZygoteAD)
```
"""
function ADNLPModel(f, x0::S; name::String = "Generic", minimize::Bool = true, kwargs...) where {S}
  T = eltype(S)
  nvar = length(x0)
  @lencheck nvar x0

  nnzh = nvar * (nvar + 1) / 2

  meta =
    NLPModelMeta{T, S}(nvar, x0 = x0, nnzh = nnzh, minimize = minimize, islp = false, name = name)
  adbackend = ADModelBackend(nvar, f; x0 = x0, kwargs...)

  return ADNLPModel(meta, Counters(), adbackend, f, x -> T[])
end

function ADNLPModel(
  f,
  x0::S,
  lvar::S,
  uvar::S;
  name::String = "Generic",
  minimize::Bool = true,
  kwargs...,
) where {S}
  T = eltype(S)
  nvar = length(x0)
  @lencheck nvar x0 lvar uvar

  nnzh = nvar * (nvar + 1) / 2

  meta = NLPModelMeta{T, S}(
    nvar,
    x0 = x0,
    lvar = lvar,
    uvar = uvar,
    nnzh = nnzh,
    minimize = minimize,
    islp = false,
    name = name,
  )
  adbackend = ADModelBackend(nvar, f; x0 = x0, kwargs...)

  return ADNLPModel(meta, Counters(), adbackend, f, x -> T[])
end

function ADNLPModel(
  f,
  x0::S,
  c,
  lcon::S,
  ucon::S;
  y0::S = fill!(similar(lcon), zero(eltype(S))),
  name::String = "Generic",
  minimize::Bool = true,
  kwargs...,
) where {S}
  T = eltype(S)
  nvar = length(x0)
  ncon = length(lcon)
  @lencheck nvar x0
  @lencheck ncon ucon y0

  nnzh = nvar * (nvar + 1) / 2
  nnzj = nvar * ncon

  meta = NLPModelMeta{T, S}(
    nvar,
    x0 = x0,
    ncon = ncon,
    y0 = y0,
    lcon = lcon,
    ucon = ucon,
    nnzj = nnzj,
    nnzh = nnzh,
    minimize = minimize,
    islp = false,
    name = name,
  )
  adbackend = ADModelBackend(nvar, f, ncon; x0 = x0, kwargs...)

  return ADNLPModel(meta, Counters(), adbackend, f, c)
end

function ADNLPModel(
  f,
  x0::S,
  clinrows,
  clincols,
  clinvals::S,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S}
  T = eltype(S)
  return ADNLPModel(f, x0, clinrows, clincols, clinvals, x -> T[], lcon, ucon; kwargs...)
end

function ADNLPModel(
  f,
  x0::S,
  A::AbstractSparseMatrix{Tv, Ti},
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Tv, Ti}
  return ADNLPModel(f, x0, findnz(A)..., lcon, ucon; kwargs...)
end

function ADNLPModel(
  f,
  x0::S,
  clinrows,
  clincols,
  clinvals::S,
  c,
  lcon::S,
  ucon::S;
  y0::S = fill!(similar(lcon), zero(eltype(S))),
  name::String = "Generic",
  minimize::Bool = true,
  kwargs...,
) where {S}
  T = eltype(S)
  nvar = length(x0)
  ncon = length(lcon)
  @lencheck nvar x0
  @lencheck ncon ucon y0

  nnzh = nvar * (nvar + 1) / 2

  nlin = maximum(clinrows)
  lin = 1:nlin
  lin_nnzj = length(clinvals)
  nln_nnzj = nvar * (ncon - nlin)
  nnzj = lin_nnzj + nln_nnzj
  @lencheck lin_nnzj clinrows clincols

  meta = NLPModelMeta{T, S}(
    nvar,
    x0 = x0,
    ncon = ncon,
    y0 = y0,
    lcon = lcon,
    ucon = ucon,
    nnzj = nnzj,
    nnzh = nnzh,
    lin = lin,
    lin_nnzj = lin_nnzj,
    nln_nnzj = nln_nnzj,
    minimize = minimize,
    islp = false,
    name = name,
  )
  adbackend = ADModelBackend(nvar, f, ncon; x0 = x0, kwargs...)

  return ADNLPModel(meta, Counters(), adbackend, f, clinrows, clincols, clinvals, c)
end

function ADNLPModel(f, x0, A::AbstractSparseMatrix{Tv, Ti}, c, lcon, ucon; kwargs...) where {Tv, Ti}
  return ADNLPModel(f, x0, findnz(A)..., c, lcon, ucon; kwargs...)
end

function ADNLPModel(
  f,
  x0::S,
  lvar::S,
  uvar::S,
  clinrows,
  clincols,
  clinvals::S,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S}
  T = eltype(S)
  return ADNLPModel(
    f,
    x0,
    lvar,
    uvar,
    clinrows,
    clincols,
    clinvals,
    x -> T[],
    lcon,
    ucon;
    kwargs...,
  )
end

function ADNLPModel(
  f,
  x0::S,
  lvar::S,
  uvar::S,
  A::AbstractSparseMatrix{Tv, Ti},
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Tv, Ti}
  return ADNLPModel(f, x0, lvar, uvar, findnz(A)..., lcon, ucon; kwargs...)
end

function ADNLPModel(
  f,
  x0::S,
  lvar::S,
  uvar::S,
  c,
  lcon::S,
  ucon::S;
  y0::S = fill!(similar(lcon), zero(eltype(S))),
  name::String = "Generic",
  minimize::Bool = true,
  kwargs...,
) where {S}
  T = eltype(S)
  nvar = length(x0)
  ncon = length(lcon)
  @lencheck nvar x0 lvar uvar
  @lencheck ncon y0 ucon

  nnzh = nvar * (nvar + 1) / 2
  nnzj = nvar * ncon

  meta = NLPModelMeta{T, S}(
    nvar,
    x0 = x0,
    lvar = lvar,
    uvar = uvar,
    ncon = ncon,
    y0 = y0,
    lcon = lcon,
    ucon = ucon,
    nnzj = nnzj,
    nnzh = nnzh,
    minimize = minimize,
    islp = false,
    name = name,
  )
  adbackend = ADModelBackend(nvar, f, ncon; x0 = x0, kwargs...)

  return ADNLPModel(meta, Counters(), adbackend, f, c)
end

function ADNLPModel(
  f,
  x0::S,
  lvar::S,
  uvar::S,
  clinrows,
  clincols,
  clinvals::S,
  c,
  lcon::S,
  ucon::S;
  y0::S = fill!(similar(lcon), zero(eltype(S))),
  name::String = "Generic",
  minimize::Bool = true,
  kwargs...,
) where {S}
  T = eltype(S)
  nvar = length(x0)
  ncon = length(lcon)
  @lencheck nvar x0 lvar uvar
  @lencheck ncon y0 ucon

  nnzh = nvar * (nvar + 1) / 2

  nlin = maximum(clinrows)
  lin = 1:nlin
  lin_nnzj = length(clinvals)
  nln_nnzj = nvar * (ncon - nlin)
  nnzj = lin_nnzj + nln_nnzj
  @lencheck lin_nnzj clinrows clincols

  meta = NLPModelMeta{T, S}(
    nvar,
    x0 = x0,
    lvar = lvar,
    uvar = uvar,
    ncon = ncon,
    y0 = y0,
    lcon = lcon,
    ucon = ucon,
    nnzj = nnzj,
    nnzh = nnzh,
    lin = lin,
    lin_nnzj = lin_nnzj,
    nln_nnzj = nln_nnzj,
    minimize = minimize,
    islp = false,
    name = name,
  )
  adbackend = ADModelBackend(nvar, f, ncon; x0 = x0, kwargs...)

  return ADNLPModel(meta, Counters(), adbackend, f, clinrows, clincols, clinvals, c)
end

function ADNLPModel(
  f,
  x0,
  lvar,
  uvar,
  A::AbstractSparseMatrix{Tv, Ti},
  c,
  lcon,
  ucon;
  kwargs...,
) where {Tv, Ti}
  return ADNLPModel(f, x0, lvar, uvar, findnz(A)..., c, lcon, ucon; kwargs...)
end

function NLPModels.obj(nlp::ADNLPModel, x::AbstractVector)
  @lencheck nlp.meta.nvar x
  increment!(nlp, :neval_obj)
  return nlp.f(x)
end

function NLPModels.grad!(nlp::ADNLPModel, x::AbstractVector, g::AbstractVector)
  @lencheck nlp.meta.nvar x g
  increment!(nlp, :neval_grad)
  gradient!(nlp.adbackend.gradient_backend, g, nlp.f, x)
  return g
end

function NLPModels.cons_lin!(nlp::ADNLPModel, x::AbstractVector, c::AbstractVector)
  @lencheck nlp.meta.nvar x
  @lencheck nlp.meta.nlin c
  increment!(nlp, :neval_cons_lin)
  coo_prod!(nlp.clinrows, nlp.clincols, nlp.clinvals, x, c)
  return c
end

function NLPModels.cons_nln!(nlp::ADNLPModel, x::AbstractVector, c::AbstractVector)
  @lencheck nlp.meta.nvar x
  @lencheck nlp.meta.nnln c
  increment!(nlp, :neval_cons_nln)
  c .= nlp.c(x)
  return c
end

function NLPModels.jac_lin_structure!(
  nlp::ADNLPModel,
  rows::AbstractVector{<:Integer},
  cols::AbstractVector{<:Integer},
)
  @lencheck nlp.meta.lin_nnzj rows cols
  rows .= nlp.clinrows
  cols .= nlp.clincols
  return rows, cols
end

function NLPModels.jac_nln_structure!(
  nlp::ADNLPModel,
  rows::AbstractVector{<:Integer},
  cols::AbstractVector{<:Integer},
)
  @lencheck nlp.meta.nln_nnzj rows cols
  return jac_structure!(nlp.adbackend.jacobian_backend, nlp, rows, cols)
end

function NLPModels.jac_lin_coord!(nlp::ADNLPModel, x::AbstractVector, vals::AbstractVector)
  @lencheck nlp.meta.nvar x
  @lencheck nlp.meta.lin_nnzj vals
  increment!(nlp, :neval_jac_lin)
  vals .= nlp.clinvals
  return vals
end

function NLPModels.jac_nln_coord!(nlp::ADNLPModel, x::AbstractVector, vals::AbstractVector)
  @lencheck nlp.meta.nvar x
  @lencheck nlp.meta.nln_nnzj vals
  increment!(nlp, :neval_jac_nln)
  return jac_coord!(nlp.adbackend.jacobian_backend, nlp, x, vals)
end

function NLPModels.jprod_lin!(
  nlp::ADNLPModel,
  x::AbstractVector,
  v::AbstractVector,
  Jv::AbstractVector{T},
) where {T}
  @lencheck nlp.meta.nvar x v
  @lencheck nlp.meta.nlin Jv
  increment!(nlp, :neval_jprod_lin)
  coo_prod!(nlp.clinrows, nlp.clincols, nlp.clinvals, v, Jv)
  return Jv
end

function NLPModels.jprod_nln!(
  nlp::ADNLPModel,
  x::AbstractVector,
  v::AbstractVector,
  Jv::AbstractVector,
)
  @lencheck nlp.meta.nvar x v
  @lencheck nlp.meta.nnln Jv
  increment!(nlp, :neval_jprod_nln)
  Jv .= Jprod(nlp.adbackend.jprod_backend, nlp.c, x, v)
  return Jv
end

function NLPModels.jtprod!(
  nlp::ADNLPModel,
  x::AbstractVector,
  v::AbstractVector,
  Jtv::AbstractVector{T},
) where {T}
  @lencheck nlp.meta.nvar x Jtv
  @lencheck nlp.meta.ncon v
  increment!(nlp, :neval_jtprod)
  if nlp.meta.nnln > 0
    jtprod_nln!(nlp, x, v[(nlp.meta.nlin + 1):end], Jtv)
    decrement!(nlp, :neval_jtprod_nln)
  else
    fill!(Jtv, zero(T))
  end
  for i = 1:(nlp.meta.lin_nnzj)
    Jtv[nlp.clincols[i]] += nlp.clinvals[i] * v[nlp.clinrows[i]]
  end
  return Jtv
end

function NLPModels.jtprod_lin!(
  nlp::ADNLPModel,
  x::AbstractVector,
  v::AbstractVector,
  Jtv::AbstractVector{T},
) where {T}
  @lencheck nlp.meta.nvar x Jtv
  @lencheck nlp.meta.nlin v
  increment!(nlp, :neval_jtprod_lin)
  coo_prod!(nlp.clincols, nlp.clinrows, nlp.clinvals, v, Jtv)
  return Jtv
end

function NLPModels.jtprod_nln!(
  nlp::ADNLPModel,
  x::AbstractVector,
  v::AbstractVector,
  Jtv::AbstractVector,
)
  @lencheck nlp.meta.nvar x Jtv
  @lencheck nlp.meta.nnln v
  increment!(nlp, :neval_jtprod_nln)
  Jtv .= Jtprod(nlp.adbackend.jtprod_backend, nlp.c, x, v)
  return Jtv
end

function NLPModels.hess(nlp::ADNLPModel, x::AbstractVector; obj_weight::Real = one(eltype(x)))
  @lencheck nlp.meta.nvar x
  increment!(nlp, :neval_hess)
  ℓ(x) = obj_weight * nlp.f(x)
  Hx = hessian(nlp.adbackend.hessian_backend, ℓ, x)
  return Symmetric(Hx, :L)
end

function NLPModels.hess(
  nlp::ADNLPModel,
  x::AbstractVector,
  y::AbstractVector;
  obj_weight::Real = one(eltype(x)),
)
  @lencheck nlp.meta.nvar x
  @lencheck nlp.meta.ncon y
  increment!(nlp, :neval_hess)
  ℓ(x) = obj_weight * nlp.f(x) + dot(nlp.c(x), view(y, (nlp.meta.nlin + 1):(nlp.meta.ncon)))
  Hx = hessian(nlp.adbackend.hessian_backend, ℓ, x)
  return Symmetric(Hx, :L)
end

function NLPModels.hess_structure!(
  nlp::ADNLPModel,
  rows::AbstractVector{<:Integer},
  cols::AbstractVector{<:Integer},
)
  @lencheck nlp.meta.nnzh rows cols
  return hess_structure!(nlp.adbackend.hessian_backend, nlp, rows, cols)
end

function NLPModels.hess_coord!(
  nlp::ADNLPModel,
  x::AbstractVector,
  vals::AbstractVector;
  obj_weight::Real = one(eltype(x)),
)
  @lencheck nlp.meta.nvar x
  @lencheck nlp.meta.nnzh vals
  increment!(nlp, :neval_hess)
  ℓ(x) = obj_weight * nlp.f(x)
  return hess_coord!(nlp.adbackend.hessian_backend, nlp, x, ℓ, vals)
end

function NLPModels.hess_coord!(
  nlp::ADNLPModel,
  x::AbstractVector,
  y::AbstractVector,
  vals::AbstractVector;
  obj_weight::Real = one(eltype(x)),
)
  @lencheck nlp.meta.nvar x
  @lencheck nlp.meta.ncon y
  @lencheck nlp.meta.nnzh vals
  increment!(nlp, :neval_hess)
  ℓ(x) = obj_weight * nlp.f(x) + dot(nlp.c(x), view(y, (nlp.meta.nlin + 1):(nlp.meta.ncon)))
  return hess_coord!(nlp.adbackend.hessian_backend, nlp, x, ℓ, vals)
end

function NLPModels.hprod!(
  nlp::ADNLPModel,
  x::AbstractVector,
  v::AbstractVector,
  Hv::AbstractVector;
  obj_weight::Real = one(eltype(x)),
)
  n = nlp.meta.nvar
  @lencheck n x v Hv
  increment!(nlp, :neval_hprod)
  ℓ(x) = obj_weight * nlp.f(x)
  Hv .= Hvprod(nlp.adbackend.hprod_backend, ℓ, x, v)
  return Hv
end

function NLPModels.hprod!(
  nlp::ADNLPModel,
  x::AbstractVector,
  y::AbstractVector,
  v::AbstractVector,
  Hv::AbstractVector;
  obj_weight::Real = one(eltype(x)),
)
  n = nlp.meta.nvar
  @lencheck n x v Hv
  @lencheck nlp.meta.ncon y
  increment!(nlp, :neval_hprod)
  ℓ(x) = obj_weight * nlp.f(x) + dot(nlp.c(x), view(y, (nlp.meta.nlin + 1):(nlp.meta.ncon)))
  Hv .= Hvprod(nlp.adbackend.hprod_backend, ℓ, x, v)
  return Hv
end

function NLPModels.jth_hess_coord!(
  nlp::ADNLPModel,
  x::AbstractVector,
  j::Integer,
  vals::AbstractVector{T},
) where {T}
  @lencheck nlp.meta.nnzh vals
  @lencheck nlp.meta.nvar x
  @rangecheck 1 nlp.meta.ncon j
  increment!(nlp, :neval_jhess)
  if j ≤ nlp.meta.nlin
    fill!(vals, zero(T))
  else
    hess_coord!(nlp.adbackend.hessian_backend, nlp, x, x -> nlp.c(x)[j - nlp.meta.nlin], vals)
  end
  return vals
end

function NLPModels.jth_hprod!(
  nlp::ADNLPModel,
  x::AbstractVector,
  v::AbstractVector,
  j::Integer,
  Hv::AbstractVector{T},
) where {T}
  @lencheck nlp.meta.nvar x v Hv
  @rangecheck 1 nlp.meta.ncon j
  increment!(nlp, :neval_jhprod)
  if j ≤ nlp.meta.nlin
    fill!(Hv, zero(T))
  else
    Hv .= Hvprod(nlp.adbackend.hprod_backend, x -> nlp.c(x)[j - nlp.meta.nlin], x, v)
  end
  return Hv
end

function NLPModels.ghjvprod!(
  nlp::ADNLPModel,
  x::AbstractVector,
  g::AbstractVector,
  v::AbstractVector,
  gHv::AbstractVector{T},
) where {T}
  @lencheck nlp.meta.nvar x g v
  @lencheck nlp.meta.ncon gHv
  increment!(nlp, :neval_hprod)
  @views gHv[1:(nlp.meta.nlin)] .= zero(T)
  @views gHv[(nlp.meta.nlin + 1):end] .=
    directional_second_derivative(nlp.adbackend.ghjvprod_backend, nlp.c, x, v, g)
  return gHv
end
