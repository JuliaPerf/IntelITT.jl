using IntelITT, Test

@testset "IntelITT" begin

IntelITT.isactive() ||
    @warn "No ITT collector present. For complete test coverage, make sure you have a collector attached to your process, e.g., by running under VTune."
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

thread_name!("test")
thread_ignore()

let d = Domain("test")
    task_begin(d, "test")
    task_end(d)
end

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


end
