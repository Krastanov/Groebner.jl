# Backend for `groebner`

# Proxy function dedicated to handling errors.
function _groebner(polynomials, kws::Keywords)
    # We try to guess efficient internal polynomial representation, i.e., a
    # suitable representation of monomials and coefficients. Some polynomial
    # representations are considered unsafe, implying that the computation may
    # fail. 
    #
    # The backend is wrapped in a try/catch to catch exceptions that one can
    # hope to recover from (and, perhaps, restart the computation with safer
    # parameters).
    unsafe_representation =
        guess_exponent_vector_representation(polynomials, kws, UnsafeRepresentation())
    try
        return _groebner(polynomials, kws, unsafe_representation)
    catch err
        if isa(err, ExponentOverflow)
            # Exponent vector overflow happened. Restart the computation with at
            # least 64 bits per exponent.
            safe_representation = default_safe_representation(kws)
            return _groebner(polynomials, kws, safe_representation)
        elseif isa(err, UnluckyCoefficientCancellation)
            # Unlucky cancellation of some coefficient happened.

        else
            # Something bad happened.
            rethrow(err)
        end
    end
end

function _groebner(polynomials, kws::Keywords, r::Representation)
    stats = Statistics()
    # Extract ring information, exponents, and coefficients from input polynomials.
    # This copies the input, so that `polynomials` itself is not modified.
    ring, exps, coeffs = convert_to_internal(representation, polynomials, kws)
    # Check and set algorithm parameters
    params = Parameters(ring, kws)
    # TODO: move to input-output.jl ?
    iszerox = remove_zeros_from_input!(ring, exps, coeffs)
    iszerox && (return convert_to_output(ring, polynomials, exps, coeffs, metainfo))

    # NOTE(alex)
    # Change input ordering if needed
    newring = assure_ordering!(ring, exps, coeffs, params)
    # Compute a groebner basis
    bexps, bcoeffs = _groebner(newring, exps, coeffs, params)
    # Convert result back to the representation of input
    convert_to_output(newring, polynomials, bexps, bcoeffs, params)
end

function _groebner(
    ring::PolyRing,
    monoms::Vector{Vector{M}},
    coeffs::Vector{Vector{C}},
    params::Parameters
) where {M <: Monom, C <: CoeffFF}
    # TODO(alex): exponents --> monoms

    # initialize basis and hashtable structures
    basis, ht = initialize_structures(ring, exps, coeffs, params)

    f4!(ring, basis, ht, reduced, meta.linalg, meta.rng, maxpairs=maxpairs)

    # extract exponents from hashtable
    gbexps = hash_to_exponents(basis, ht)

    gbexps, basis.coeffs
end

#------------------------------------------------------------------------------
# Rational numbers groebner

# groebner over rationals is implemented roughly in the following way:
#
# k = 1
# while !(correctly reconstructed)
#   k = k*2
#   select a batch of small prime numbers p1..pk
#   compute a batch of finite field groebner bases gb1..gbk
#   reconstruct gb1..gbk to gb_zz modulo prod(p1..pk) with CRT
#   reconstruct gb_zz to gb_qq with rational reconstruction
#   if the basis gb_qq is correct, then break
# end
# return gb_qq
#

initial_batchsize() = 1
initial_gaps() = (1, 1, 1, 1, 1)
batchsize_multiplier() = 2

function _groebner(
    ring::PolyRing,
    exps::Vector{Vector{M}},
    coeffs::Vector{Vector{C}},
    params::Parameters
) where {M <: Monom, C <: CoeffQQ}

    # we can mutate coeffs and exps here

    # select hashtable size
    tablesize = select_tablesize(ring, exps)
    @info "Selected tablesize $tablesize"

    # initialize hashtable and finite field basis structs
    gens_temp_ff, ht = initialize_structures_ff(ring, exps, coeffs, meta.rng, tablesize)
    gens_ff = deepcopy_basis(gens_temp_ff)

    # now hashtable is filled correctly,
    # and gens_temp_ff exponents are correct and in correct order.
    # gens_temp_ff coefficients are filled with random stuff and
    # gens_temp_ff.ch is 0

    # to store integer and rational coefficients of groebner basis
    coeffaccum = CoeffAccum{BigInt, Rational{BigInt}}()
    # to store BigInt buffers and reduce overall memory usage
    coeffbuffer = CoeffBuffer()

    # scale coefficients of input to integers
    coeffs_zz = scale_denominators(coeffbuffer, coeffs)

    # keeps track of used prime numbers
    primetracker = PrimeTracker(coeffs_zz)

    # exps, coeffs and coeffs_zz **must be not changed** during whole computation
    i = 1

    # copy basis so that we initial exponents dont get lost
    gens_ff = deepcopy_basis(gens_temp_ff)

    prime = nextluckyprime!(primetracker)
    @info "$i: selected lucky prime $prime"

    # perform reduction and store result in gens_ff
    reduce_modulo!(coeffbuffer, coeffs_zz, gens_ff.coeffs, prime)

    # do some things to ensure generators are correct
    cleanup_basis!(ring, gens_ff, prime)

    # compute groebner basis in finite field.
    # Need to make sure input invariants in f4! are satisfied, see f4/f4.jl for details

    tracer = Tracer()
    pairset = initialize_pairset(powertype(M))

    f4!(ring, gens_ff, tracer, pairset, ht, reduced, meta.linalg, meta.rng, maxpairs)

    # reconstruct into integers
    @info "CRT modulo ($(primetracker.modulo), $(prime))"

    reconstruct_crt!(coeffbuffer, coeffaccum, primetracker, gens_ff.coeffs, prime)

    # reconstruct into rationals
    @info "Reconstructing modulo $(primetracker.modulo)"
    reconstruct_modulo!(coeffbuffer, coeffaccum, primetracker)

    correct = false
    if correctness_check!(
        coeffaccum,
        coeffbuffer,
        primetracker,
        meta,
        ring,
        exps,
        coeffs,
        coeffs_zz,
        gens_temp_ff,
        gens_ff,
        ht
    )
        @info "Reconstructed successfuly"
        correct = true
    end

    # initial batch size
    batchsize = initial_batchsize()
    gaps = initial_gaps()
    # multiplier for the size of the batch of prime numbers
    multiplier = batchsize_multiplier()
    # if first prime was not successfull
    while !correct
        if i <= length(gaps)
            batchsize = gaps[i]
        else
            batchsize = batchsize * multiplier
        end

        for j in 1:batchsize
            i += 1

            # copy basis so that initial exponents dont get lost
            gens_ff = deepcopy_basis(gens_temp_ff)
            prime = nextluckyprime!(primetracker)
            @info "$i: selected lucky prime $prime"
            # perform reduction and store result in gens_ff
            reduce_modulo!(coeffbuffer, coeffs_zz, gens_ff.coeffs, prime)
            # do some things to ensure generators are correct
            cleanup_basis!(ring, gens_ff, prime)
            # compute groebner basis in finite field
            # Need to make sure input invariants in f4! are satisfied, see f4/f4.jl for details

            f4!(
                ring,
                gens_ff,
                tracer,
                pairset,
                ht,
                reduced,
                meta.linalg,
                meta.rng,
                maxpairs
            )
            # reconstruct to integers
            @info "CRT modulo ($(primetracker.modulo), $(prime))"

            batchsize > 1 && basis_shape_control(coeffaccum.gb_coeffs_qq, gens_ff.coeffs)

            reconstruct_crt!(coeffbuffer, coeffaccum, primetracker, gens_ff.coeffs, prime)
        end

        # reconstruct to rationals
        @info "Reconstructing modulo $(primetracker.modulo)"
        success = reconstruct_modulo!(coeffbuffer, coeffaccum, primetracker)
        !success && continue

        if correctness_check!(
            coeffaccum,
            coeffbuffer,
            primetracker,
            meta,
            ring,
            exps,
            coeffs,
            coeffs_zz,
            gens_temp_ff,
            gens_ff,
            ht
        )
            @info "Success!"
            correct = true
        end

        # i > 2^10 && basis_coeff_control(primetracker, coeffaccum)
    end

    #=
    # TODO
    if meta.usefglm
        fglm_f4!(ring, gens_ff, ht)
    end
    =#

    gb_exps = hash_to_exponents(gens_ff, ht)
    gb_exps, coeffaccum.gb_coeffs_qq
end

function _groebner(
    ring::PolyRing,
    monoms::Vector{Vector{M}},
    coeffs::Vector{Vector{C}},
    params
) where {M <: Monom, C <: CoeffParam} end
