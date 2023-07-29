# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENCE in the project root.
# ------------------------------------------------------------------

Makie.@recipe(VarioPlot, γ) do scene
  Makie.Attributes(
    # variogram options
    vcolor=:slategray,
    pshow=true,
    psize=12,
    tsize=12,
    ssize=1.5,

    # varioplane options
    vscheme=:viridis,

    # histogram options
    hshow=true,
    hcolor=:slategray
  )
end

# ----------
# EMPIRICAL
# ----------

Makie.plottype(::EmpiricalVariogram) = VarioPlot{<:Tuple{EmpiricalVariogram}}

function Makie.plot!(plot::VarioPlot{<:Tuple{EmpiricalVariogram}})
  # retrieve variogram object
  γ = plot[:γ]

  # get the data
  xyn = Makie.@lift values($γ)
  x = Makie.@lift $xyn[1]
  y = Makie.@lift $xyn[2]
  n = Makie.@lift $xyn[3]

  # discard empty bins
  x = Makie.@lift $x[$n .> 0]
  y = Makie.@lift $y[$n .> 0]
  n = Makie.@lift $n[$n .> 0]

  # visualize frequencies as bars
  if plot[:hshow][]
    f = Makie.@lift $n*(maximum($y) / maximum($n)) / 10
    Makie.barplot!(plot, x, f,
      color = plot[:hcolor],
      alpha = 0.3,
      gap   = 0.0,
    )
  end

  # visualize variogram
  Makie.scatterlines!(plot, x, y,
    color = plot[:vcolor],
    markersize = plot[:psize],
    linewidth  = plot[:ssize]
  )

  # visualize bin counts
  if plot[:pshow][]
    bincounts = Makie.@lift string.($n)
    positions = Makie.@lift collect(zip($x, $y))
    Makie.text!(plot, bincounts,
      position = positions,
      fontsize = plot[:tsize],
    )
  end
end

Makie.plottype(::EmpiricalVarioplane) = VarioPlot{<:Tuple{EmpiricalVarioplane}}

function Makie.plot!(plot::VarioPlot{<:Tuple{EmpiricalVarioplane}})
  # retrieve varioplane object
  v = plot[:γ]

  # underyling variograms
  γs = Makie.@lift $v.γs

  # polar angle
  θs = Makie.@lift $v.θs

  # polar radius
  rs = Makie.@lift values($γs[1])[1]

  # variogram values for all variograms
  Z = Makie.@lift begin
    zs = map($γs) do γ
      _, zs, __ = values(γ)

      # handle NaN values (i.e. empty bins)
      isnan(zs[1]) && (zs[1] = 0)
      for i in 2:length(zs)
        isnan(zs[i]) && (zs[i] = zs[i-1])
      end

      zs
    end
    reduce(hcat, zs)
  end

  # exploit symmetry
  θs = Makie.@lift range(0, 2π, length=2*length($θs))
  Z  = Makie.@lift [$Z $Z]

  # hide hole at center
  rs = Makie.@lift [0; $rs]
  Z  = Makie.@lift [$Z[1:1,:]; $Z]

  Makie.surface!(plot, rs, θs, Z,
    colormap = plot[:vscheme],
    shading = false
  )
end

# ------------
# THEORETICAL
# ------------

Makie.plottype(::Variogram) = VarioPlot{<:Tuple{Variogram}}

function Makie.plot!(plot::VarioPlot{<:Tuple{Variogram}})
  # retrieve variogram object
  γ = plot[:γ]

  # start at 1e-6 instead of 0 to avoid
  # nugget artifact in visualization
  x = Makie.@lift range(1e-6, stop=_maxlag($γ), length=100)
  y = Makie.@lift $γ.($x)

  # visualize variogram
  Makie.lines!(plot, x, y,
    color = plot[:vcolor],
  )
end

_maxlag(γ::Variogram)      = 3range(γ)
_maxlag(γ::PowerVariogram) = 3.0
_maxlag(γ::NuggetEffect)   = 3.0