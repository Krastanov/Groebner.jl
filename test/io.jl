
using AbstractAlgebra
using Random

@testset "Input-output AbstractAlgebra" begin

    rng = Random.MersenneTwister(42)

    R, (x, y) = PolynomialRing(GF(2^31 - 1), ["x", "y"], ordering=:lex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :lex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(GF(2^31 - 1), ["x", "y"], ordering=:degrevlex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :degrevlex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(GF(2^31 - 1), ["x", "y"], ordering=:degrevlex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y, x*y - y^2, x*y - x^2]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :degrevlex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(GF(2^31 - 1), ["x", "y"], ordering=:degrevlex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y, x*y - y^2, x*y - x^2]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :degrevlex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(GF(2^31 - 1), ["x", "y"], ordering=:deglex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y, x*y - y^2, x*y - x^2]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :deglex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(GF(2^31 - 1), ["x", "y"], ordering=:deglex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y, x*y - y^2, x*y - x^2]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :deglex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(QQ, ["x", "y"], ordering=:degrevlex)
    fs = [x^2*y + 3//4, (2^31 - 5)*x - (2^31 - 4)*y]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :degrevlex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(QQ, ["x", "y"], ordering=:lex)
    fs = [x^2*y + 3//4, (2^31 - 5)*x - (2^31 - 4)*y]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :lex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(QQ, ["x", "y"], ordering=:degrevlex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y, x*y - y^2, x*y - x^2]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :degrevlex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(QQ, ["x", "y"], ordering=:degrevlex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y, x*y - y^2, x*y - x^2]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :degrevlex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(QQ, ["x", "y"], ordering=:deglex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y, x*y - y^2, x*y - x^2]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :deglex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(QQ, ["x", "y"], ordering=:deglex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y, x*y - y^2, x*y - x^2]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    meta = Groebner.set_metaparameters(ring, :deglex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs
end

@testset "Input-output generic :hasparent" begin

    @test Groebner.determinechartype(2) == UInt8
    @test Groebner.determinechartype(2^5) == UInt16
    @test Groebner.determinechartype(2^10) == UInt32
    @test Groebner.determinechartype(2^31-1) == UInt64
    @test Groebner.determinechartype(2^60) == UInt128

    rng = Random.MersenneTwister(42)

    R, (x, y) = PolynomialRing(GF(2^31 - 1), ["x", "y"], ordering=:lex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    ring.origring = :hasparent
    meta = Groebner.set_metaparameters(ring, :lex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(GF(2^31 - 1), ["x", "y"], ordering=:degrevlex)
    fs = [x^2*y + 3, (2^31 - 5)*x - (2^31 - 4)*y]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    ring.origring = :hasparent
    meta = Groebner.set_metaparameters(ring, :degrevlex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(QQ, ["x", "y"], ordering=:degrevlex)
    fs = [x^2*y + 3//4, (2^31 - 5)*x - (2^31 - 4)*y]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    ring.origring = :hasparent
    meta = Groebner.set_metaparameters(ring, :degrevlex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs

    R, (x, y) = PolynomialRing(QQ, ["x", "y"], ordering=:lex)
    fs = [x^2*y + 3//4, (2^31 - 5)*x - (2^31 - 4)*y]
    ring, exps, cfs = Groebner.convert_to_internal(fs, :input)
    ring.origring = :hasparent
    meta = Groebner.set_metaparameters(ring, :lex, false, false, :exact, rng)
    fsfs = Groebner.convert_to_output(ring, fs, exps, cfs, meta)
    @test fsfs == fs
end
