# high-level utilities

macro collect(ex)
    quote
        isactive() || @warn("No ITT collector present. Make sure you have a collector attached to your process, e.g., by running under VTune.")
        resume()
        # Use Expr(:tryfinally, ...) so we don't introduce a new soft scope.
        # TODO: switch to solution once https://github.com/JuliaLang/julia/pull/39217 is resolved
        $(Expr(:tryfinally, esc(ex), :(pause())))
    end
end

macro task(ex...)
    length(ex) >= 2 || error("Usage: IntelITT.@task [domain=...] name::String code")
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
        _domain = $(esc(domain))
        _task = Task(_domain, $name)
        start(_task)
        # Use Expr(:tryfinally, ...) so we don't introduce a new soft scope.
        # TODO: switch to solution once https://github.com/JuliaLang/julia/pull/39217 is resolved
        $(Expr(:tryfinally, esc(code), :(stop(_task))))
    end
end
