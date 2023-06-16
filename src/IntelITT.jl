module IntelITT
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

    function __init__()
        global libittnotify
        libittnotify = get(ENV, "INTEL_JIT_PROFILER64", "")
        if isempty(libittnotify)
            libittnotify = get(ENV, "INTEL_JIT_PROFILER32", "")
        end
        if isempty(libittnotify)
            libittnotify = get(ENV, "VS_PROFILER", "")
        end
        @debug "Using libittnotify" libittnotify
    end

    __itt_resume() = ccall((:__itt_resume, libittnotify), Cvoid,())
    __itt_pause() = ccall((:__itt_pause, libittnotify), Cvoid,())
    # __itt_detach() = ccall((:__itt_detach, libittnotify), Cvoid,())
    resume() = available() && __itt_resume()
    pause() = available() && __itt_pause()
    # detach() = available() && __itt_detach()

    const __itt_event = Cint

    struct Event
        id::__itt_event
        function Event(name)
            if available()
                id = ccall((:__itt_event_create, libittnotify), __itt_event, (Cstring, Cint), name, length(name))
            else
                id = -1
            end
            return new(id)
        end
    end
    Base.cconvert(::Type{__itt_event}, ev::Event) = ev.id

    function start(ev::Event)
        if ev != -1
            ccall((:__itt_event_start, libittnotify), Cint, (__itt_event,), ev)
        end
    end

    function stop(ev::Event)
        if ev != -1
            ccall((:__itt_event_end, libittnotify), Cint, (__itt_event,), ev)
        end
    end
end # module
