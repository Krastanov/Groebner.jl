
# import Singular
import AbstractAlgebra

using Base.Threads

using BenchmarkTools
include("../src/Groebner.jl")

using Logging
global_logger(ConsoleLogger(stderr, Logging.Error))

function benchmark_system_my(system)
    system = Groebner.change_ordering(system, :degrevlex)
    Groebner.groebner([system[1]])

    gb = Groebner.groebner(system)

    bench = @benchmarkable Groebner.groebner($system, linalg=:prob) samples=3
    println(median(run(bench)))
end

function benchmark_system_singular(system)
    R = AbstractAlgebra.parent(system[1])
    n = AbstractAlgebra.nvars(R)
    ground_s = Singular.QQ
    R_s, _ = Singular.PolynomialRing(ground_s, ["x$i" for i in 1:n], ordering=:degrevlex)

    system_s = map(
        f -> AbstractAlgebra.change_base_ring(
                    ground_s,
                    AbstractAlgebra.map_coefficients(c -> ground_s(numerator(c), denominator(c)), f),
                    parent=R_s),
        system)

    ideal_s = Singular.Ideal(R_s, system_s)

    Singular.std(Singular.Ideal(R_s, [system_s[1]]))

    bench = @benchmarkable  Singular.std($ideal_s) samples=3
    println(median(run(bench)))
end

function handle_system_my(name, system)
    println("---------------\n$name")
    println("my")
    benchmark_system_my(system)
    Groebner.printall()
    println("---------------")
end

function handle_system_singular(name, system)
    println("---------------\n$name")
    println("singular")
    benchmark_system_singular(system)
    println("---------------")
end

function run_f4_ff_degrevlex_benchmarks(ground)
    systems = [
    # ("cyclic 13", Groebner.rootn(13, ground=ground)), # 0.19 vs 0.03
    # ("cyclic 14", Groebner.rootn(14, ground=ground)), # 0.60 vs 0.9
    ("katsura 9",Groebner.katsuran(9, ground=ground)), # 1.35 vs 71.121
    ("katsura 10",Groebner.katsuran(10, ground=ground)), # 9.68 vs 775
    ("eco 11",Groebner.eco11(ground=ground)),         # 0.41  vs 31.7
    ("eco 12",Groebner.eco12(ground=ground)),         # 2.5   vs 341
    ("noon 7"    ,Groebner.noonn(7, ground=ground)),  # 0.19  vs 0.36
    ("noon 8"    ,Groebner.noonn(8, ground=ground)),  # 1.8   vs 3.2
    ("henrion 5"    ,Groebner.henrion5(ground=ground)),  # 0.19  vs 0.36
    ("henrion 6"    ,Groebner.henrion6(ground=ground))  # 1.8   vs 3.2
    ]

    for (name, system) in systems
        task1 = @spawn handle_system_my(name, system)
        # task2 = @spawn handle_system_singular(name, system)
        wait(task1)
        # wait(task2)
    end
end

ground = AbstractAlgebra.QQ
run_f4_ff_degrevlex_benchmarks(ground)
