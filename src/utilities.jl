# high-level utilities

macro profile(ex)
    quote
        isactive() || @warn("No ITT collector present. Make sure you have a collector attached to your process, e.g., by running under VTune.")
        resume()
        # Use Expr(:tryfinally, ...) so we don't introduce a new soft scope.
        # TODO: switch to solution once https://github.com/JuliaLang/julia/pull/39217 is resolved
        $(Expr(:tryfinally, esc(ex), :(pause())))
    end
end

macro range(ex...)
    length(ex) >= 2 || error("Usage: IntelITT.@range [domain=...] name::String code")
    name = ex[end-1]
    code = ex[end]
    kwargs = ex[1:end-2]

    # handle kwargs
    domain = nothing
    for kwarg in kwargs
        key::Symbol, val = kwarg.args
        if key === :domain
            domain = val
        else
            error("unknown keyword argument: $key")
        end
    end
    if domain === nothing
        domain = :(Domain(string($__module__)))
    end

    domain

    quote
        _isactive = isactive()
        if _isactive
            _domain = $domain
            task_begin(_domain, $name)
        end
        # Use Expr(:tryfinally, ...) so we don't introduce a new soft scope.
        # TODO: switch to solution once https://github.com/JuliaLang/julia/pull/39217 is resolved
        $(Expr(:tryfinally, esc(code), :(_isactive && task_end(_domain))))
    end
end
