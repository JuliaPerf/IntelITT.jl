module ITT
    # Notes:
    # Only supports Linux for now.
    # ENABLE_JITPROFILING=1
    # INTEL_JIT_BACKWARD_COMPATIBILITY
    # 0: Resolves inlined call-stacks
    # 1: Groups at the level of LLVM functions compiled
    # 
    # IMPORTANT: Do not use `detach`, doing so causes VTunes
    #            to not resolve jitted functions.
    libittnotify::String = ""
    available() = !isempty(libittnotify)

    function __init()
        global libittnotify
        libittnotify = get(ENV, "INTEL_JIT_PROFILER64", "")
        if isempty(libittnotify)
            libittnotify = get(ENV, "INTEL_JIT_PROFILER32", "")
        end
        if isempty(libittnotify)
            libittnotify = get(ENV, "VS_PROFILER", "")
        end
    end

    __itt_resume() = ccall((:__itt_resume, libittnotify), Cvoid,())
    __itt_pause() = ccall((:__itt_pause, libittnotify), Cvoid,())
    # __itt_detach() = ccall((:__itt_detach, libittnotify), Cvoid,())
    resume() = available() && __itt_resume()
    pause() = available() && __itt_pause()
    # detach() = available() && __itt_detach()
end # module
