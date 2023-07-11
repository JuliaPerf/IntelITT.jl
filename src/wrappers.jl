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

struct MissingCollectorError <: Exception
end

function Base.showerror(io::IO, e::MissingCollectorError)
    print(io, "This API cannot be used without an active collector.")
end

macro apicall(name, args...)
    quote
        ptr = lookup_function($(name))
        ptr == C_NULL && throw(MissingCollectorError())
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
        d.handle == C_NULL && throw(MissingCollectorError())
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

function Base.show(io::IO, d::Domain)
    print(io, "Domain(")
    if isactive()
        print(io, repr(name(d)), ", enabled=$(isenabled(d))")
    end
    print(io, ")")
end

isenabled(d::Domain) = d.flags == 0 ? false : true
enable!(d::Domain, enable::Bool=true) = d.flags = enable ? 1 : 0

name(d::Domain) = d.name == C_NULL ? "" : unsafe_string(d.name)


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

String(s::StringHandle) = s.handle == C_NULL ? "" : unsafe_string(unsafe_load(s.handle).str)


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
    isactive() || return
    @apicall(:__itt_task_begin, Cvoid,
             (Ptr{__itt_domain}, __itt_id, __itt_id, Ptr{__itt_string_handle},),
             domain, __itt_null, __itt_null, StringHandle(name))
end

function task_end(domain::Domain)
    isactive() || return
    @apicall(:__itt_task_end, Cvoid, (Ptr{__itt_domain},), domain)
end


#
# Events
#

export Event, start, stop

const __itt_event = Cint

struct Event
    id::__itt_event
end
Base.convert(::Type{__itt_event}, ev::Event) = ev.id

function Event(name::String)
    # XXX: the stub library doesn't have a no-op __itt_event_create; handle it ourselves
    isactive() || return Event(-1)

    Event(@apicall(:__itt_event_create, __itt_event, (Cstring, Cint), name, length(name)))
end

function start(ev::Event)
    ev.id == -1 && return
    @apicall(:__itt_event_start, Cint, (__itt_event,), ev)
end

function stop(ev::Event)
    ev.id == -1 && return
    @apicall(:__itt_event_end, Cint, (__itt_event,), ev)
end



#
# Counters
#

export Counter, increment!, decrement!

struct __itt_counter end

@enum __itt_metadata_type::Cint begin
    __itt_metadata_unknown = 0
    __itt_metadata_u64
    __itt_metadata_s64
    __itt_metadata_u32
    __itt_metadata_s32
    __itt_metadata_u16
    __itt_metadata_s16
    __itt_metadata_float
    __itt_metadata_double
end

function Base.convert(::Type{__itt_metadata_type}, t::Type)
    if t == UInt64
        __itt_metadata_u64
    elseif t == Int64
        __itt_metadata_s64
    elseif t == UInt32
        __itt_metadata_u32
    elseif t == Int32
        __itt_metadata_s32
    elseif t == UInt16
        __itt_metadata_u16
    elseif t == Int16
        __itt_metadata_s16
    elseif t == Float32
        __itt_metadata_float
    elseif t == Float64
        __itt_metadata_double
    else
        throw(ArgumentError("unsupported counter type: $t"))
    end
end

mutable struct Counter{T}
    handle::Ptr{__itt_counter}

    function Counter{T}(name::String, domain::String) where T
        handle = @apicall(:__itt_counter_create, Ptr{__itt_counter},
                          (Cstring, Cstring, __itt_metadata_type), name, domain, T)
        obj = new{T}(handle)
        finalizer(obj) do _
            # XXX: under VTune, __itt_counter_destroy is not implemented
            if lookup_function(:__itt_counter_destroy) != C_NULL
                @apicall(:__itt_counter_destroy, Cvoid, (Ptr{__itt_counter},), obj)
            end
        end
    end
end
Base.unsafe_convert(::Type{Ptr{__itt_counter}}, c::Counter) = c.handle

function Base.setindex!(c::Counter{T}, value) where T
    c.handle == C_NULL && return
    @apicall(:__itt_counter_set_value, Cvoid,
             (Ptr{__itt_counter}, Ptr{Nothing}),
             c, Ref{T}(value))
end

function increment!(c::Counter{UInt64})
    c.handle == C_NULL && return
    @apicall(:__itt_counter_inc, Cvoid, (Ptr{__itt_counter},), c)
end
function increment!(c::Counter{UInt64}, value)
    c.handle == C_NULL && return
    @apicall(:__itt_counter_inc_delta, Cvoid, (Ptr{__itt_counter}, Culonglong), c, value)
end

function decrement!(c::Counter{UInt64})
    c.handle == C_NULL && return
    @apicall(:__itt_counter_dec, Cvoid, (Ptr{__itt_counter},), c)
end
function decrement!(c::Counter{UInt64}, value)
    c.handle == C_NULL && return
    @apicall(:__itt_counter_dec_delta, Cvoid, (Ptr{__itt_counter}, Culonglong), c, value)
end


#
# Memory Allocations
#

export HeapFunction,
       alloc_begin, alloc_end, alloc,
       free_begin, free_end, free,
       realloc_begin, realloc_end, realloc

struct __itt_heap_function end

struct HeapFunction
    handle::Ptr{__itt_heap_function}
end
Base.unsafe_convert(::Type{Ptr{__itt_heap_function}}, h::HeapFunction) = h.handle

function HeapFunction(name::String, domain::String)
    isactive() || return HeapFunction(C_NULL)
    HeapFunction(@apicall(:__itt_heap_function_create, Ptr{__itt_heap_function},
                          (Cstring, Cstring), name, domain))
end

function alloc_begin(h::HeapFunction, size::Integer; initialized::Bool=false)
    h.handle == C_NULL && return
    @apicall(:__itt_heap_allocate_begin, Cvoid,
             (Ptr{__itt_heap_function}, Csize_t, Cint),
             f, size, initialized)
end
function alloc_end(h::HeapFunction, ptr::Ptr{Nothing}, size::Integer; initialized::Bool=false)
    h.handle == C_NULL && return
    @apicall(:__itt_heap_allocate_end, Cvoid,
             (Ptr{__itt_heap_function}, Ptr{Ptr{Nothing}}, Csize_t, Cint),
             f, Ref(ptr), size, initialized)
end

"""
    alloc(h::HeapFunction, size::Integer; initialized::Bool=false) do size
        ptr = ...
    end

Mark a block of code as allocating memory. The block should return a pointer the allocated
memory. The `initialized` argument indicates whether the memory is initialized or not.
"""
function alloc(f, h::HeapFunction, size::Integer; initialized::Bool=false)
    alloc_begin(h, size; initialized)
    try
        ptr = f(size)
        alloc_end(h, ptr, size; initialized)
        ptr
    catch err
        alloc_end(h, C_NULL, size; initialized)
        rethrow(err)
    end
end

function free_begin(h::HeapFunction, ptr::Ptr{Nothing})
    h.handle == C_NULL && return
    @apicall(:__itt_heap_free_begin, Cvoid,
             (Ptr{__itt_heap_function}, Ptr{Nothing}),
             h, ptr)
end
function free_end(h::HeapFunction, ptr::Ptr{Nothing})
    h.handle == C_NULL && return
    @apicall(:__itt_heap_free_end, Cvoid,
             (Ptr{__itt_heap_function}, Ptr{Nothing}),
             h, ptr)
end

"""
    free(h::HeapFunction, ptr::Ptr{Nothing}) do ptr
        # ...
    end

Mark a block of code as freeing memory at `ptr`.
"""
function free(f, h::HeapFunction, ptr::Ptr{Nothing})
    free_begin(h, ptr)
    try
        ret = f(ptr)
        free_end(h, ptr)
        ret
    catch err
        free_end(h, C_NULL)
        rethrow(err)
    end
end

function realloc_begin(h::HeapFunction, ptr::Ptr{Nothing}, new_size::Integer;
                       initialized::Bool=false)
    h.handle == C_NULL && return
    @apicall(:__itt_heap_reallocate_begin, Cvoid,
             (Ptr{__itt_heap_function}, Ptr{Nothing}, Csize_t, Cint),
             h, ptr, new_size, initialized)
end
function realloc_end(h::HeapFunction, ptr::Ptr{Nothing}, new_ptr::Ptr{Nothing},
                     new_size::Integer; initialized::Bool=false)
    h.handle == C_NULL && return
    @apicall(:__itt_heap_reallocate_end, Cvoid,
             (Ptr{__itt_heap_function}, Ptr{Nothing}, Ptr{Ptr{Nothing}}, Csize_t, Cint),
             h, ptr, Ref(new_ptr), new_size, initialized)
end

"""
    realloc(h::HeapFunction, ptr::Ptr{Nothing}, new_size::Integer;
            initialized::Bool=false) do ptr, new_size
        new_ptr = ...
    end

Mark a block of code as reallocating memory at `ptr` to `new_size`. The block should return
a pointer to the new memory.
"""
function realloc(f, h::HeapFunction, ptr::Ptr{Nothing}, new_size::Integer;
                 initialized::Bool=false)
    realloc_begin(h, ptr, new_size; initialized)
    try
        new_ptr = f(ptr, new_size)
        realloc_end(h, ptr, new_ptr, new_size; initialized)
        new_ptr
    catch err
        realloc_end(h, ptr, C_NULL, new_size; initialized)
        rethrow(err)
    end
end
