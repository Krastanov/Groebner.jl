
import AbstractAlgebra

@testset "check parameter order change" begin
    R, (x, y, z) = PolynomialRing(QQ, ["x","y","z"], ordering=:deglex)

    fs = [y^2, x]
    x, y, z = gens(parent(first(Groebner.groebner(fs, ordering=:lex))))
    @test Groebner.groebner(fs, ordering=:lex) == [y^2, x]
    @test AbstractAlgebra.ordering(parent(first(Groebner.groebner(fs, ordering=:lex)))) === :lex

    x, y, z = gens(parent(first(Groebner.groebner(fs, ordering=:degrevlex))))
    @test Groebner.groebner(fs, ordering=:degrevlex) == [x, y^2]
    @test AbstractAlgebra.ordering(parent(first(Groebner.groebner(fs, ordering=:degrevlex)))) === :degrevlex

    x, y, z = gens(parent(first(fs)))
    @test Groebner.groebner(fs, ordering=:deglex) == [x, y^2]
    @test AbstractAlgebra.ordering(parent(first(Groebner.groebner(fs, ordering=:deglex)))) === :deglex

    x, y, z = gens(parent(first(Groebner.groebner(fs, forsolve=true))))
    @test Groebner.groebner(fs, forsolve=true) == [y^2, x]
    @test AbstractAlgebra.ordering(parent(first(Groebner.groebner(fs, forsolve=true)))) === :lex


    noon = Groebner.change_ordering(Groebner.noonn(2), :lex)
    gb = Groebner.groebner(noon, ordering=:lex)
    x1, x2 = gens(parent(first(gb)))
    @test gb == [
            x2^5 - 10//11*x2^4 - 11//5*x2^3 + 2*x2^2 + 331//1100*x2 - 11//10,
            x1 + x2^4 - 10//11*x2^3 - 11//10*x2^2 + x2 - 10//11]

    gb = Groebner.groebner(noon, ordering=:degrevlex)
    x1, x2 = gens(parent(first(gb)))
    @test gb == [
            x1^2 - x2^2 - 10//11*x1 + 10//11*x2,
            x2^3 + 10//11*x1*x2 - 10//11*x2^2 - 11//10*x2 + 1,
            x1*x2^2 - 11//10*x1 + 1]

    gb = Groebner.groebner(noon, ordering=:deglex)
    x1, x2 = gens(parent(first(gb)))
    @test gb == [
            x1^2 - x2^2 - 10//11*x1 + 10//11*x2,
            x2^3 + 10//11*x1*x2 - 10//11*x2^2 - 11//10*x2 + 1,
            x1*x2^2 - 11//10*x1 + 1]

end
