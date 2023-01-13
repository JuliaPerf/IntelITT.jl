# IntelITT.jl

## Julia and VTunes

You need to set the environment variable `ENABLE_JITPROFILING=1`. Also note that for Julia <= 1.8, you need to compile Julia locally with `USE_INTEL_JITEVENTS=1`.

I recommend using "Start Paused" to minimize the amount of noise
you see due to startup and compilation.

## Example

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

## Acknowledgments

- https://discourse.julialang.org/t/using-the-intel-vtune-profiler-with-julia/34327/17
- https://github.com/mchristianl/IntelITT.jl

