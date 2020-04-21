#------------------------------------------------------------------------------
# I. Periodic Tasks & Global Memory
#------------------------------------------------------------------------------

#----------
#Example 1:
#----------
using Dates
basicHandler(_)= println("tick "*Dates.format(now(), "HH:MM:SS"))
begin
    t=Timer(basicHandler, 0; interval = 5)  #nonblocking
end
close(t)

#----------
#Example 2:
#----------
begin
    i = 0
    cb(timer) = (global i += 1; println(i))
    t = Timer(cb, 2, interval=5)
end
close(t)

#----------
#Example 3:
#----------
function Handler1(_)
    sleep(15)
    println("tickStart "*Dates.format(now(), "HH:MM:SS"))    
end
begin
    t=Timer(Handler1, 0; interval = 5)  #nonblocking
end
close(t)


#------------------------------------------------------------------------------
# II. Functional Reactive Programming
#------------------------------------------------------------------------------

#------------------
#using Pkg
#Pkg.add("Reactive")

#----------
#Example 1:
#----------
using Reactive
switch = Signal(true)
ticks = fpswhen(switch,1)
preserve(map(basicHandler,ticks))
push!(switch, false)

#----------
#Example 2:
#----------
using Reactive
x = Signal(100)
z = map(v -> v + 500, x)
c = foldp((acc, value) -> push!(acc, value), Int[], z)
for i in rand(90:110, 10)
    push!(x, i)
    yield() #Can also use Reactive.run_till_now()
    println(value(z))
end
@show value(c) #20-element Array{Int64,1}:

#----------
#Example 3:
#----------
x = Signal(100)
z = map(x) do v
    result = v + 500
    println(result)
    return result
end
c = foldp(Int[], z) do acc, value
    push!(acc, value)
end
for i in rand(90:110, 10)
    push!(x, i)
end
@show value(c) #10-element Array{Int64,1}:

for i in rand(1:10,10)
    push!(x, i)
end
@show value(c) #10-element Array{Int64,1}:

#----------
#Example 4:
#----------
"""
let timerCount2, timerEventStream = createTimerAndObservable 500
timerEventStream 
|> Observable.scan (fun count _ -> count + 1) 0 
|> Observable.subscribe (fun count -> printfn "timer ticked with count %i" count)
Async.RunSynchronously timerCount2
"""
using Printf
switch = Signal(true)
ticks = fpswhen(switch,1)
t = foldp(+, 0.0, ticks)
preserve(map(x->@printf("timer ticked with count %d \n",x), t))
#@show value(t)
push!(switch, false)

#----------
#Example 5:
#----------
#------------------
#http://juliagizmos.github.io/Reactive.jl/
#Signal{T}. Input{T},Node{T}
#lift,@lift,foldl,foldr,filter,dropif,droprepeats,keepwhen
#sampleon,merge,fps,fpswhen,every,timestamp
x = Signal(0) #1: "input" = 0 Int64
value(x) #0
push!(x, 42)
value(x) #42
xsquared = map(a -> a*a, x) #2: "map(input)" = 1764 Int64
value(xsquared) #1764
push!(x, 3)
value(xsquared) #9
y = map(+, x, xsquared; typ=Float64, init=0) #
value(y) #0.0
push!(x, 4)
value(y) #20.0
preserve(map(println, x))  #foreach(println, x)
push!(x, 25) #25
#--------------
x = Signal(100)
z = map(v -> v + 500, x)
c = foldp((acc, value) -> push!(acc, value), Int[], z)
for i in rand(90:110, 10)
    push!(x, i)
    yield() #Can also use Reactive.run_till_now()
    println(value(z))
end
@show value(c) #10-element Array{Int64,1}:
#--------------
x = Signal(100)
z = map(x) do v
    result = v + 500
    println(result)
    return result
end
c = foldp(Int[], z) do acc, value
    push!(acc, value)
end
for i in rand(90:110, 10)
    push!(x, i)
end
@show value(c) #10-element Array{Int64,1}:
#--------------------------------------
"""
type FizzBuzzEvent = {label:int; time: DateTime}
let areSimultaneous (earlierEvent,laterEvent) =
    let {label=_;time=t1} = earlierEvent
    let {label=_;time=t2} = laterEvent
    t2.Subtract(t1).Milliseconds < 50
let timer3, timerEventStream3 = createTimerAndObservable 300
let timer5, timerEventStream5 = createTimerAndObservable 500
let eventStream3  = 
    timerEventStream3  
    |> Observable.map (fun _ -> {label=3; time=DateTime.Now})
let eventStream5  = 
    timerEventStream5  
    |> Observable.map (fun _ -> {label=5; time=DateTime.Now})
let combinedStream = 
    Observable.merge eventStream3 eventStream5
let pairwiseStream = 
        combinedStream |> Observable.pairwise
let simultaneousStream, nonSimultaneousStream = 
        pairwiseStream |> Observable.partition areSimultaneous
let fizzStream, buzzStream  =
        nonSimultaneousStream  
            |> Observable.map (fun (ev1,_) -> ev1)
            |> Observable.partition (fun {label=id} -> id=3)
combinedStream 
    |> Observable.subscribe (fun {label=id;time=t} -> 
                              printf "[%i] %i.%03i " id t.Second t.Millisecond)
 simultaneousStream 
    |> Observable.subscribe (fun _ -> printfn "FizzBuzz")
fizzStream 
    |> Observable.subscribe (fun _ -> printfn "Fizz")
buzzStream 
    |> Observable.subscribe (fun _ -> printfn "Buzz")
[timer3;timer5]
    |> Async.Parallel
    |> Async.RunSynchronously
"""
using Reactive
using Dates
struct FizzBuzzEvent  
    label::Int64 
    time::DateTime 
end
function areSimultaneous(earlierEvent::FizzBuzzEvent,laterEvent::FizzBuzzEvent) 
    t1=earlierEvent.time
    t2=laterEvent.time
    #FizzBuzzEvent(_,t1) = earlierEvent #CA: unpack not available
    #FizzBuzzEvent(_,t2) = laterEvent
    t2-t1 < Millisecond(50)
end
switch = Signal(false)
timer3 = fpswhen(switch,2)
timer5 = fpswhen(switch,1)
eventStream3=map(_->FizzBuzzEvent(3,now()) ,timer3)
eventStream5=map(_->FizzBuzzEvent(5,now()) ,timer5)
combinedStream = merge(eventStream3,eventStream5)
pairwiseStream = (previous(combinedStream),combinedStream)
initialPair=(FizzBuzzEvent(0,now()),FizzBuzzEvent(0,now())) 
nonSimultaneousStream = Reactive.filter(!areSimultaneous,initialPair,pairwiseStream) 
simultaneousStream = Reactive.filter(areSimultaneous,initialPair,pairwiseStream) 
fizzStream=map(x->x[1].label=3,nonSimultaneousStream) 
buzzStream=map(x->x[1].label=5,nonSimultaneousStream)
preserve(map(x->@printf("[%d] %d.%03d \n",x.label,second(x.time),millisecond(x.time))),combinedStream)
preserve(map(x->println("FizzBuzz",simultaneousStream)))
preserve(map(x->println("Fizz",fizzStream)))
preserve(map(x->println("Buzz",buzzStream)))



push!(switch, true)
push!(switch, false)


#--------------------------------------    
#Reactive, Basic
number() = round(Int, rand()*1000)
a = Signal(number(); name="a")
b = map(x -> x*x, a; name="b")
#(typeof(b)) == (Reactive.Lift{Int}) #CA:fail
push!(a, 1.0)
value(a) #1
#step() #CA:fail
value(b) #1

push!(a, number())
value(b) #
push!(a, -number())
value(b)

d = Signal(number())
c = map(+, a, b, d, typ=Int)
value(c) #
push!(a, number())
value(c) #
push!(d, number())
value(c) #

d = Signal(number(); name="d")
e = merge(b, d, a; name="e")
(value(e)) == (value(d)) #true
push!(a, number())
(value(e)) == (value(b))
c = map(identity, a) #true
f = merge(d, c, b)
push!(a, number())
(value(f)) == (value(c)) #true

push!(a, 0)
value(a) #0
f = foldp(+, 0, a)
nums = round.([Int], rand(100)*1000) #100-element Array{Int64,1}:
map(x -> push!(a, x), nums)
value(f)
(sum(nums)) == (value(f)) #true

g = Signal(0)
pred = x -> x % 2 != 0
h = filter(pred, 1, g)
j = filter(x -> x % 2 == 0, 1, g)

value(h) #1
value(j) #0

push!(g, 2)
value(h) #1

push!(g, 3)
value(h)#3

g = Signal(0)
pred = x -> x % 2 != 0
h = filter(pred, g)
push!(g, 2)
value(h)#0
push!(g, 3)
value(h)#3

a = Signal(1; name="a")
b = Signal(2; name="b")
c = filter(value(a), a; name="c") do aval; aval > 1 end
d = map(*,b,c)
count = foldp((x, y) -> x+1, 0, d)
value(count)#0
push!(a, 0)
value(count)#0


#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Under Construction after this point
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
"""
@testset "Timing functions" begin

    @testset "fpswhen" begin
        b = Signal(false)
        t = fpswhen(b, 2)
        acc = foldp((x, y) -> x+1, 0, t)
        sleep(0.75)

        @test (queue_size()) == (0)
        push!(b, true)

        step() # processing the push to b will start the fpswhen's timer
        # then we fetch for two pushes from the timer, which should take ~ 1sec
        dt = @elapsed Reactive.run(2)
        push!(b, false)
        Reactive.run(1) # setting b to false should stop the timer

        sleep(0.75) # no more updates
        @test (queue_size()) == (0)

        @show dt
        @test isapprox(dt, 1, atol = 0.3) # mac OSX needs a lot of tolerence here)
        @test (value(acc)) == (2)

    end

    @testset "every" begin
        num_steps = 4
        dt = 0.5
        # gets pushed the `time()` every `dt` seconds
        t = every(dt)

        # append the `time()` to the Float64[] array, once every dt secs
        acc = foldp(push!, Float64[], t)

        # process num_steps pushes (should take num_steps*dt secs)
        Reactive.run(num_steps)
        end_t = time() # should be equal to the last time in acc
        # close(t) to avoid `acc` getting pushed to again
        close(t)

        accval = value(acc)
        @show end_t end_t .- accval
        @test isapprox(accval[end], end_t, atol=0.01)

        Reactive.run_till_now()

        @test isapprox([0.5, 0.5, 0.5], diff(accval), atol=0.1)

        sleep(0.75)
        # make sure the `close(t)` above actually also closed the timer
        @test (queue_size()) == (0)
    end

    @testset "throttle" begin
        GC.gc()
        x = Signal(0; name="x")
        ydt = 0.5
        y′dt = 1.1
        y = throttle(ydt, x; name="y", leading=false)
        y′ = throttle(y′dt, x, push!, Int[], x->Int[]; name="y′", leading=false) # collect intermediate updates
        z = foldp((acc, x) -> begin
            println("z got ", x)
            acc+1
        end, 0, y)
        z′ = foldp((acc, x) -> begin
            println("z′ got ", x)
            acc+1
        end, 0, y′)
        y′prev = previous(y′)

        i = 0
        sleep_time = 0.15
        t0 = typemax(Float64)
        # push and sleep for a bit, y and y′ should only update every ydt and
        # y′dt seconds respectively
        while time() - t0 <= 2.2
            i += 1
            push!(x, i)

            Reactive.run_till_now()
            t0 == typemax(Float64) && (t0 = time()) # start timer here to match signals
            sleep(sleep_time)
        end
        dt = time() - t0
        sleep(max(ydt,y′dt) + 0.1) # sleep for the trailing-edge pushes of the throttles
        Reactive.run_till_now()

        zcount = ceil(dt / ydt) # throttle should have pushed every ydt seconds
        z′count = ceil(dt / y′dt) # throttle should have pushed every y′dt seconds

        @show i dt ydt y′dt zcount z′count value(y) value(y′) value(z) value(z′)

        @test (value(y)) == (i)
        @test isapprox(value(z), zcount, atol=1)
        @test (value(y′)) == ([y′prev.value[end]+1 : i;])
        @test (length(value(y′))) < ((i/(z′count-1)))
        @test isapprox(value(z′), z′count, atol=1)

        # type safety
        s1 = Signal(3)
        s2 = Signal(rand(2,2))
        m = merge(s1, s2)
        t = throttle(1/5, m; typ=Any)
        r = rand(3,3)
        push!(s2, r)
        Reactive.run(1)
        sleep(0.5)
        # Reactive.run(1)
        Reactive.run_till_now()
        @test (value(t)) == (r)
    end

    @testset "debounce" begin
        x = Signal(0)
        y = debounce(0.5, x)
        y′ = debounce(1, x, push!, Int[], x->Int[]) # collect intermediate updates
        z = foldp((acc, x) -> acc+1, 0, y)
        z′ = foldp((acc, x) -> acc+1, 0, y′)

        push!(x, 1)
        step()

        push!(x, 2)
        step()

        push!(x, 3)
        t0=time()
        step()

        @test (value(y)) == (0)
        @test (value(z)) == (0)
        @test (queue_size()) == (0)

        sleep(0.55)

        @test (queue_size()) == (1) # y should have been pushed to by now)
        step() # run the push to y
        @test (value(y)) == (3)
        @test (value(z)) == (1)
        @test (value(z′)) == (0)
        sleep(0.5)

        @test (queue_size()) == (1) # y′ should have pushed by now)
        step() # run the push to y′
        @test (value(z′)) == (1)
        @test (value(y′)) == (Int[1,2,3])

        push!(x, 3)
        step()

        push!(x, 2)
        step()

        push!(x, 1)
        step()
        sleep(1.1)

        @test (queue_size()) == (2) #both y and y′ should have pushed)
        step()
        step()
        @test (value(y)) == (1)
        @test (value(z′)) == (2)
        @test (value(y′)) == (Int[3,2,1])

        # type safety
        s1 = Signal(3)
        s2 = Signal(rand(2,2))
        m = merge(s1, s2)
        t = debounce(1/5, m; typ=Any)
        r = rand(3,3)
        push!(s2, r)
        Reactive.run(1)
        sleep(0.5)
        Reactive.run(1)
        @test (value(t)) == (r)
    end
end
"""