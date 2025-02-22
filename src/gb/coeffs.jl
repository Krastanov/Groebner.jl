
# CoeffBuffer stores BigInt buffers used to minimize memory allocations
# during coefficient scaling, rational reconstruction and CRT reconstruction
mutable struct CoeffBuffer
    # We don't want the buffers to mix and interfere one with another,
    # so they are aggregated in several groups by purpose

    # buffers that should be used
    # only for coefficient scaling
    scalebuf1::BigInt
    scalebuf2::BigInt

    # buffers that should be used
    # only for coefficient reduction
    reducebuf1::BigInt
    reducebuf2::BigInt
    reducebuf3::BigInt

    # buffers that should be used
    # only for coefficient reconstrction
    reconstructbuf1::BigInt
    reconstructbuf2::BigInt
    reconstructbuf3::BigInt
    reconstructbuf4::BigInt
    reconstructbuf5::BigInt
    reconstructbuf6::BigInt
    reconstructbuf7::BigInt
    reconstructbuf8::BigInt
    reconstructbuf9::BigInt
    reconstructbuf10::BigInt

    function CoeffBuffer()
        new(BigInt(), BigInt(), BigInt(), BigInt(), BigInt(),
            BigInt(), BigInt(), BigInt(), BigInt(), BigInt(), BigInt(),
            BigInt(), BigInt(), BigInt(), BigInt())
    end
end

#------------------------------------------------------------------------------

# CoeffAccum stores accumulated integer coefficients and
# accumulated rational coefficients of a groebner basis
mutable struct CoeffAccum{T1<:CoeffZZ, T2<:CoeffQQ}
    gb_coeffs_zz::Vector{Vector{T1}}
    prev_gb_coeffs_zz::Vector{Vector{T1}}
    gb_coeffs_qq::Vector{Vector{T2}} 

    function CoeffAccum{T1, T2}() where {T1<:CoeffZZ, T2<:CoeffQQ}
        new(Vector{Vector{T1}}(undef, 0),
            Vector{Vector{T1}}(undef, 0),
            Vector{Vector{T2}}(undef, 0))
    end
end

#------------------------------------------------------------------------------

# Computes the gcd of denominators of `coeffs`
function common_denominator(coeffbuff::CoeffBuffer, coeffs::Vector{T}) where {T<:CoeffQQ}
    den = coeffbuff.scalebuf1
    Base.GMP.MPZ.set_si!(den, 1)
    for c in coeffs
        Base.GMP.MPZ.lcm!(den, denominator(c))
    end
    den
end

# Computes the gcd of denominators of `coeffs`
function common_denominator(coeffs::Vector{T}) where {T<:CoeffQQ}
    den = BigInt()
    Base.GMP.MPZ.set_si!(den, 1)
    for c in coeffs
        Base.GMP.MPZ.lcm!(den, denominator(c))
    end
    den
end

# Scales each vector in coeffs_qq by the common denominator
# and writes integer results to coeffs_zz
function scale_denominators!(
            coeffbuff::CoeffBuffer,
            coeffs_qq::Vector{Vector{T1}},
            coeffs_zz::Vector{Vector{T2}}) where {T1<:CoeffQQ, T2<:CoeffZZ}
    @assert length(coeffs_zz) == length(coeffs_qq)

    buf = coeffbuff.scalebuf2
    @inbounds for i in 1:length(coeffs_qq)
        @assert length(coeffs_zz[i]) == length(coeffs_qq[i])
        den = common_denominator(coeffbuff, coeffs_qq[i])
        sz  = Base.GMP.MPZ.sizeinbase(den, 2)
        for j in 1:length(coeffs_qq[i])
            num = numerator(coeffs_qq[i][j])
            Base.GMP.MPZ.tdiv_q!(buf, den, denominator(coeffs_qq[i][j]))
            Base.GMP.MPZ.realloc2!(coeffs_zz[i][j], sz)
            Base.GMP.MPZ.mul!(coeffs_zz[i][j], num, buf)
        end
    end
    coeffs_zz
end

# Scales each vector in coeffs_qq by the common denominator
# and returns the results in a new vector
function scale_denominators(
            coeffbuff::CoeffBuffer,
            coeffs_qq::Vector{Vector{T}}) where {T<:CoeffQQ}
    coeffs_zz = [[BigInt(0) for _ in 1:length(c)] for c in coeffs_qq]
    scale_denominators!(coeffbuff, coeffs_qq, coeffs_zz)
end

# Scales each vector in coeffs_qq by the common denominator
# and returns the results in a new vector
function scale_denominators(coeffs_qq::Vector{Vector{T}}) where {T<:CoeffQQ}
    coeffs_zz = [[BigInt(0) for _ in 1:length(c)] for c in coeffs_qq]
    buf = BigInt()
    @inbounds  for i in 1:length(coeffs_qq)
        @assert length(coeffs_zz[i]) == length(coeffs_qq[i])
        den = common_denominator(coeffs_qq[i])
        for j in 1:length(coeffs_qq[i])
            num = numerator(coeffs_qq[i][j])
            Base.GMP.MPZ.tdiv_q!(buf, den, denominator(coeffs_qq[i][j]))
            Base.GMP.MPZ.mul!(coeffs_zz[i][j], num, buf)
        end
    end
    coeffs_zz
end

function scale_denominators(coeffs_qq::Vector{T}) where {T<:CoeffQQ}
    coeffs_zz = [BigInt(0) for _ in 1:length(coeffs_qq)]
    buf = BigInt()
    den = common_denominator(coeffs_qq)
    @inbounds for i in 1:length(coeffs_qq)
        num = numerator(coeffs_qq[i])
        Base.GMP.MPZ.tdiv_q!(buf, den, denominator(coeffs_qq[i]))
        Base.GMP.MPZ.mul!(coeffs_zz[i], num, buf)
    end
    coeffs_zz
end

#------------------------------------------------------------------------------

# Coerces each integer coefficient from `coeffs_zz`
# into the field of integers modulo `prime`
# and writes result to `coeffs_ff`
function reduce_modulo!(
        coeffbuff::CoeffBuffer,
        coeffs_zz::Vector{Vector{T1}},
        coeffs_ff::Vector{Vector{T2}},
        prime::T2) where {T1<:CoeffZZ, T2<:CoeffFF}

    p   = coeffbuff.reducebuf1
    buf = coeffbuff.reducebuf2
    c   = coeffbuff.reducebuf3
    Base.GMP.MPZ.set_ui!(p, prime)

    for i in 1:length(coeffs_zz)
        cfs_zz_i = coeffs_zz[i]
        for j in 1:length(cfs_zz_i)
            Base.GMP.MPZ.set!(c, cfs_zz_i[j])
            if Base.GMP.MPZ.cmp_ui(c, 0) < 0
                Base.GMP.MPZ.fdiv_q!(buf, c, p)
                Base.GMP.MPZ.neg!(buf)
                Base.GMP.MPZ.mul_ui!(buf, prime)
                Base.GMP.MPZ.add!(c, buf)
            end
            Base.GMP.MPZ.tdiv_r!(buf, c, p)
            coeffs_ff[i][j] = CoeffModular(buf)
        end
    end
end

function reduce_modulo(
        coeffbuff::CoeffBuffer,
        coeffs_zz::Vector{Vector{T1}},
        prime::T2) where {T1<:CoeffZZ, T2<:CoeffFF}
    coeffs_ff =  [Vector{CoeffModular}(undef, length(c)) for c in coeffs_zz]
    reduce_modulo!(coeffbuff, coeffs_zz, coeffs_ff, prime)
    coeffs_ff
end

#------------------------------------------------------------------------------

# Resizes coeffaccum so that it has enough space to store gb_coeffs 
function resize_accum!(coeffaccum::CoeffAccum, gb_coeffs::Vector{Vector{T}}) where {T}
    resize!(coeffaccum.gb_coeffs_zz, length(gb_coeffs))
    resize!(coeffaccum.prev_gb_coeffs_zz, length(gb_coeffs))
    resize!(coeffaccum.gb_coeffs_qq, length(gb_coeffs))
    @inbounds for i in 1:length(gb_coeffs)
        coeffaccum.gb_coeffs_zz[i] = [BigInt(0) for _ in 1:length(gb_coeffs[i])]
        coeffaccum.prev_gb_coeffs_zz[i] = [BigInt(0) for _ in 1:length(gb_coeffs[i])]
        coeffaccum.gb_coeffs_qq[i] = [Rational{BigInt}(1) for _ in 1:length(gb_coeffs[i])]
    end
end

# Check that the groebner basis modulo a prime has the same structure
# as the groebner basis over rationals
function assure_structure(coeffaccum, gb_coeffs_ff)
    if length(coeffaccum.gb_coeffs_zz) != gb_coeffs_ff
        return false
    end
    @inbounds for i in 1:length(gb_coeffs_ff)
        if length(coeffaccum.gb_coeffs_zz[i]) != gb_coeffs_ff[i]
            return false
        end
    end
    return true
end

function reconstruct_trivial_crt!(coeffbuff::CoeffBuffer,
                                    coeffaccum::CoeffAccum,
                                    gb_coeffs_ff::Vector{Vector{T1}}) where {T1<:CoeffFF}
    gb_coeffs_zz = coeffaccum.gb_coeffs_zz
    @inbounds for i in 1:length(gb_coeffs_ff)
        for j in 1:length(gb_coeffs_ff[i])
            Base.GMP.MPZ.set_ui!(gb_coeffs_zz[i][j], gb_coeffs_ff[i][j])
        end
    end
end

# G == coeffaccum   mod P1*P2*...*Pk
# G == gb_coeffs_ff mod P
#
# Finds G using CRT and writes it to coeffaccum
function reconstruct_crt!(
        coeffbuff::CoeffBuffer,
        coeffaccum::CoeffAccum,
        primetracker::PrimeTracker,
        gb_coeffs_ff::Vector{Vector{T1}},
        ch::UInt64) where {T1<:CoeffFF}

    if isempty(coeffaccum.gb_coeffs_zz)
        # if first time reconstruction
        resize_accum!(coeffaccum, gb_coeffs_ff)
        reconstruct_trivial_crt!(coeffbuff, coeffaccum, gb_coeffs_ff)
    else
        gb_coeffs_zz = coeffaccum.gb_coeffs_zz
        prev_gb_coeffs_zz = coeffaccum.prev_gb_coeffs_zz

        # copy to previous gb coeffs
        @inbounds for i in 1:length(gb_coeffs_zz)
            for j in 1:length(gb_coeffs_zz[i])
                Base.GMP.MPZ.set!(prev_gb_coeffs_zz[i][j], gb_coeffs_zz[i][j])
            end
        end

        buf = coeffbuff.reconstructbuf1
        n1, n2 = coeffbuff.reconstructbuf2, coeffbuff.reconstructbuf3
        M = coeffbuff.reconstructbuf4
        bigch = coeffbuff.reconstructbuf5
        invm1, invm2 = coeffbuff.reconstructbuf6, coeffbuff.reconstructbuf7

        Base.GMP.MPZ.set_ui!(bigch, ch)
        Base.GMP.MPZ.mul_ui!(M, primetracker.modulo, ch)
        Base.GMP.MPZ.gcdext!(buf, invm1, invm2, primetracker.modulo, bigch)

        @inbounds for i in 1:length(gb_coeffs_ff)
            for j in 1:length(gb_coeffs_ff[i])
                ca = gb_coeffs_zz[i][j]
                cf = gb_coeffs_ff[i][j]
                CRT!(M, buf, n1, n2, ca, invm1, cf, invm2, primetracker.modulo, bigch)
                Base.GMP.MPZ.set!(gb_coeffs_zz[i][j], buf)
            end
        end
    end
    updatemodulo!(primetracker)
end

#------------------------------------------------------------------------------

# N//D == coeffaccum (mod primetracker.modulo)
# Finds N and D using rational reconstruction
# and writes it to coeffaccum
function reconstruct_modulo!(
        coeffbuff::CoeffBuffer,
        coeffaccum::CoeffAccum,
        primetracker::PrimeTracker)

    modulo = primetracker.modulo

    bnd = rational_reconstruction_bound(modulo)
    buf, buf1  = coeffbuff.reconstructbuf1, coeffbuff.reconstructbuf2
    buf2, buf3 = coeffbuff.reconstructbuf3, coeffbuff.reconstructbuf4
    u1, u2     = coeffbuff.reconstructbuf5, coeffbuff.reconstructbuf6
    u3, v1     = coeffbuff.reconstructbuf7, coeffbuff.reconstructbuf8
    v2, v3     = coeffbuff.reconstructbuf9, coeffbuff.reconstructbuf10

    gb_coeffs_zz = coeffaccum.gb_coeffs_zz
    gb_coeffs_qq = coeffaccum.gb_coeffs_qq

    @inbounds for i in 1:length(gb_coeffs_zz)
        for j in 2:length(gb_coeffs_zz[i])
            cz = gb_coeffs_zz[i][j]
            cq = gb_coeffs_qq[i][j]
            num, den = numerator(cq), denominator(cq)
            success = rational_reconstruction!(num, den, bnd, buf,
                                        buf1, buf2, buf3,
                                        u1, u2, u3, v1, v2, v3,
                                        cz, modulo)
            if !success
                return false
            end
        end
    end

    return true
end
