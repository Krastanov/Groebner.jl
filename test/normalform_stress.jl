

import Random
using AbstractAlgebra

function test_params_nf(rng, nvariables, exps, nterms,
                        npolys, grounds, coeffssize, orderings)

    for n in nvariables
        for e in exps
            for nt in nterms
                for np in npolys
                    for gr in grounds
                        for ord in orderings
                            for csz in coeffssize
                                set = Groebner.generate_set(
                                    n, e, nt, np, csz, rng, gr, ord
                                )
                                isempty(set) && continue
                                gb = Groebner.groebner(set)
                                f = rand(set)

                                mynf = Groebner.normalform(gb, f, check=false)
                                # TODO : add more tests
                                @test mynf == 0
                                if mynf != 0
                                    @error "Beda!" n e nt np gr ord
                                    println("Rng ", rng)
                                    println("Set ", set)
                                    println("Gb ", gb)
                                    error("exit tests")
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end


@testset "normalform random stress tests" begin

    rng = Random.MersenneTwister(42)

    # :degrevlex finite case tests
    nvariables = [2, 3, 4]
    exps       = [1:2, 2:4, 4:5]
    nterms     = [1:1, 1:2, 4:5]
    npolys     = [1:1, 1:3, 4:5]
    grounds    = [GF(1031), GF(2^31 - 1)]
    coeffssize = [3, 1000, 2^31 - 1]
    orderings  = [:degrevlex]
    p = prod(map(length, (nvariables, exps, nterms, npolys, grounds, orderings, coeffssize)))
    @info "producing $p $(orderings[1]) tests for normal form"
    test_params_nf(rng, nvariables, exps, nterms, npolys, grounds, coeffssize, orderings)

    # :lex finite case tests
    nvariables = [2, 3, 4]
    exps       = [1:2, 2:4, 2:3]
    nterms     = [1:1, 1:2, 2:3]
    npolys     = [1:1, 1:3, 2:3]
    grounds    = [GF(1031), GF(2^31 - 1)]
    coeffssize = [3, 1000, 2^31 - 1]
    orderings  = [:lex]
    p = prod(map(length, (nvariables, exps, nterms, npolys, grounds, orderings, coeffssize)))
    @info "producing $p $(orderings[1]) tests for normal form"
    test_params_nf(rng, nvariables, exps, nterms, npolys, grounds, coeffssize, orderings)

    # :deglex finite case tests
    nvariables = [2, 3, 4]
    exps       = [1:2, 2:4, 2:3]
    nterms     = [1:1, 1:2, 2:3]
    npolys     = [1:1, 1:3, 2:3]
    grounds    = [GF(1031), GF(2^31 - 1)]
    coeffssize = [3, 1000, 2^31 - 1]
    orderings  = [:deglex]
    p = prod(map(length, (nvariables, exps, nterms, npolys, grounds, orderings, coeffssize)))
    @info "producing $p $(orderings[1]) tests for normal form"
    test_params_nf(rng, nvariables, exps, nterms, npolys, grounds, coeffssize, orderings)

    # all other test cases
    nvariables = [2, 3, 4]
    exps       = [1:2, 2:4, 2:3]
    nterms     = [1:1, 1:2, 2:3]
    npolys     = [1:1, 1:3, 2:3]
    grounds    = [QQ]
    coeffssize = [3, 1000, 2^31 - 1]
    orderings  = [:deglex, :lex, :degrevlex]
    p = prod(map(length, (nvariables, exps, nterms, npolys, grounds, orderings, coeffssize)))
    @info "producing $p $(orderings[1]) tests for normal form"
    test_params_nf(rng, nvariables, exps, nterms, npolys, grounds, coeffssize, orderings)

end
