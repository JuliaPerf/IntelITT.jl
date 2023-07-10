# library wrappers

export isactive

const __itt_id = NTuple{3, Culonglong}
const __itt_null = __itt_id((0, 0, 0))

@inline lookup_function(name::Symbol) = _lookup_function(Val(name))
@generated function _lookup_function(::Val{name}) where {name}
    slot_name = String(name) * "_ptr__3_0"
    quote
        slot = cglobal(($(slot_name), ittapi_jll.libittnotify))
        unsafe_load(convert(Ptr{Ptr{Cvoid}}, slot))
    end
end

macro apicall(name, args...)
    quote
        ptr = lookup_function($(name))
        ccall(ptr, ($(map(esc, args)...)))
    end
end

@enum __itt_collection_state::Cint begin
    __itt_collection_uninitialized = 0          # uninitialized
    __itt_collection_init_fail = 1              # failed to init
    __itt_collection_collector_absent = 2       # non work state collector is absent
    __itt_collection_collector_exists = 3       # work state collector exists
    __itt_collection_init_successful = 4        # success to init
end

collection_state() =
    ccall((:__itt_get_collection_state, ittapi_jll.libittnotify), __itt_collection_state, ())

isactive() = collection_state() == __itt_collection_init_successful


#
# Domains
#

export Domain, name, isenabled, enable!

struct __itt_domain
    flags::Cint
    name::Cstring
    # don't care about the rest, for now
end

struct Domain
    handle::Ptr{__itt_domain}
end
Base.unsafe_convert(::Type{Ptr{__itt_domain}}, d::Domain) = d.handle

Domain(name::String) = Domain(@apicall(:__itt_domain_create, Ptr{__itt_domain}, (Cstring,), name))

# XXX: can we do this cleaner?
function Base.getproperty(d::Domain, name::Symbol)
    if name in [:flags, :name]
        d.handle == C_NULL && throw(UndefRefError())
        return getfield(unsafe_load(d.handle), name)
    else
        return getfield(d, name)
    end
end
function Base.setproperty!(d::Domain, name::Symbol, value)
    if name in [:flags]
        d.handle == C_NULL && throw(UndefRefError())
        idx = Base.fieldindex(__itt_domain, name)
        offset = Base.fieldoffset(__itt_domain, idx)
        typ = Base.fieldtype(__itt_domain, idx)
        return unsafe_store!(convert(Ptr{Cint}, d.handle) + offset, value)
    else
        return setfield!(d, name, value)
    end
end

Base.show(io::IO, d::Domain) = print(io, "Domain(", repr(name(d)), ", enabled=$(isenabled(d)))")

isenabled(d::Domain) = d.flags == 0 ? false : true
enable!(d::Domain, enable::Bool=true) = d.flags = enable ? 1 : 0

name(d::Domain) = unsafe_string(d.name)


#
# String handles
#

export StringHandle

struct __itt_string_handle
    str::Cstring
end

struct StringHandle
    handle::Ptr{__itt_string_handle}
end
Base.unsafe_convert(::Type{Ptr{__itt_string_handle}}, s::StringHandle) = s.handle

StringHandle(name::String) =
    StringHandle(@apicall(:__itt_string_handle_create, Ptr{__itt_string_handle}, (Cstring,), name))

String(s::StringHandle) = unsafe_string(unsafe_load(s.handle).str)


#
# Collection control
#

export pause, resume, detach

pause() = @apicall(:__itt_pause, Cvoid, ())
resume() = @apicall(:__itt_resume, Cvoid, ())
detach() = @apicall(:__itt_detach, Cvoid, ())


#
# Thread Naming
#

export thread_name!, thread_ignore

thread_name!(name::String) =
    @apicall(:__itt_thread_set_name, Cvoid, (Cstring,), name)

thread_ignore() = @apicall(:__itt_thread_ignore, Cvoid, ())


#
# Tasks
#

export task_begin, task_end

function task_begin(domain::Domain, name::String)
    @apicall(:__itt_task_begin, Cvoid,
             (Ptr{__itt_domain}, __itt_id, __itt_id, Ptr{__itt_string_handle},),
             domain, __itt_null, __itt_null, StringHandle(name))
end

task_end(domain::Domain) =
    @apicall(:__itt_task_end, Cvoid, (Ptr{__itt_domain},), domain)
