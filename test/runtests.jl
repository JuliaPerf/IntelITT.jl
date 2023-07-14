using IntelITT, Test

@testset "IntelITT" begin

# some tests don't work without an active collector
inactive = !IntelITT.isactive()

let d = Domain("test")
    @test name(d) == "test" skip=inactive

    enable!(d, true)
    @test isenabled(d) skip=inactive

    enable!(d, false)
    @test !isenabled(d)
end

let str = StringHandle("test")
    @test String(str) == "test" skip=inactive
end

resume()
pause()
IntelITT.@collect begin end

thread_name!("test")
thread_ignore()

let d = Domain("test")
    t = IntelITT.Task(d, "test")
    start(t)
    stop(t)
    IntelITT.@task domain=d "test" begin end
end
IntelITT.@task "test" begin end

let ev = Event("test")
    start(ev)
    stop(ev)
end

let ctr = Counter{UInt64}("test", "test")
    ctr[] = 0
    increment!(ctr)
    increment!(ctr, 2)
    decrement!(ctr)
    decrement!(ctr, 2)
end

let ctr = Counter{Float64}("test", "test")
    ctr[] = 0.0
    @test_throws MethodError increment!(ctr)
    @test_throws MethodError increment!(ctr, 2.0)
    @test_throws MethodError decrement!(ctr)
    @test_throws MethodError decrement!(ctr, 2.0)
end

let h = HeapFunction("test", "test")
    alloc_begin(h, 0)
    alloc_end(h, C_NULL, 0)

    alloc(h, 0) do size
        @test size == 0
        C_NULL
    end

    free_begin(h, C_NULL)
    free_end(h, C_NULL)

    free(h, C_NULL) do ptr
        @test ptr == C_NULL
        nothing
    end

    realloc_begin(h, C_NULL, 0)
    realloc_end(h, C_NULL, C_NULL, 0)

    realloc(h, C_NULL, 0) do ptr, new_size
        @test ptr == C_NULL
        @test new_size == 0
        C_NULL
    end
end

end
