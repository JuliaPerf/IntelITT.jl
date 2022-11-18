# ITT.jl

## Julia and VTunes

You need to compile Julia locally with `USE_INTEL_JITEVENTS=1` and
set the environment variable `ENABLE_JITPROFILING=1`.

I recommend using "Start Paused" to minimize the amount of noise
you see due to startup and compilation.

## Example

```julia
using ITT

# Check if we are running under VTune
@assert ITT.available()

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
ITT.resume()
profile_test(100)
# Pause profiling
ITT.pause()
```