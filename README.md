# IntelITT.jl

## Basic usage

We recommend to use "Start Paused" mode in conjuction with `IntelITT.resume()` and `IntelITT.pause()` to measure a specific instrumented part of your code (and not, e.g., julia startup and compilation).

```julia
using IntelITT

# Check if we are running under VTune
@assert IntelITT.available()

function profile_test(n)
    for i = 1:n
        A = randn(100,100,20)
        m = maximum(A)
        Am = mapslices(sum, A; dims=2)
        B = A[:,:,5]
        Bsort = mapslices(sort, B; dims=1)
        b = rand(100)
        C = B.*b
    end
end

# Compile code once
profile_test(1)

# Resume profiling
IntelITT.resume()
profile_test(100)
# Pause profiling
IntelITT.pause()
```

## Julia and VTunes

You need to set the environment variable `ENABLE_JITPROFILING=1`.

For Julia < 1.9, you need to compile Julia from source with `USE_INTEL_JITEVENTS=1`.

More information, including, e.g., a [Intel VTune remote usage example](https://juliahpc.github.io/JuliaOnHPCClusters/user_hpcprofiling/intel_vtune/) can be found in the [Julia On HPC Clusters](https://juliahpc.github.io/JuliaOnHPCClusters/) notes.

## Acknowledgments

- https://discourse.julialang.org/t/using-the-intel-vtune-profiler-with-julia/34327/17
- https://github.com/mchristianl/IntelITT.jl

