
#=
    The file contains implementation of the F4 algorithm,
    described originally by Jean-Charles Faugere in
        "A new efficient algorithm for computing Grobner bases"
=#

#------------------------------------------------------------------------------

# Prepares the given set of polynomials L to be reduced by the ideal G,
# starts the reduction routine,
# and returns reduced polynomials
function reduction!(
            basis::Basis, matrix::MacaulayMatrix,
            ht::MonomialHashtable, symbol_ht::MonomialHashtable;
            linalg::Symbol=:sparse)

     convert_hashes_to_columns!(matrix, symbol_ht)

     sort_matrix_rows_decreasing!(matrix) # for pivots,  AB part
     sort_matrix_rows_increasing!(matrix) # for reduced, CD part

     exact_sparse_linear_algebra!(matrix, basis)

     convert_matrix_rows_to_basis_elements!(matrix, basis, ht, symbol_ht)
end

#------------------------------------------------------------------------------

function filter_redundant!(basis::Basis)
    j = 1
    for i in 1:basis.nlead
        if basis.isred[basis.nonred[i]] == 0
            basis.lead[j] = basis.lead[i]
            basis.nonred[j] = basis.nonred[i]
            #=
            basis.coeffs[j] = basis.coeffs[basis.nonred[i]]
            basis.gens[j] = basis.gens[basis.nonred[i]]
            =#
            j += 1
        end
    end
    basis.nlead = j - 1
    @assert basis.ndone == basis.ntotal
    # basis.ndone = basis.ntotal = basis.nlead
    basis
end

function export_basis_data(basis::Basis, ht::MonomialHashtable)
    exps   = Vector{Vector{Vector{UInt16}}}(undef, basis.nlead)
    coeffs = Vector{Vector{UInt64}}(undef, basis.nlead)

    for i in 1:basis.nlead
        idx = basis.nonred[i]
        poly = basis.gens[idx]
        exps[i] = Vector{Vector{UInt16}}(undef, length(poly))
        for j in 1:length(poly)
            exps[i][j] = ht.exponents[poly[j]]
        end
        coeffs[i] = basis.coeffs[idx]
    end

    exps, coeffs
end

#------------------------------------------------------------------------------

# given input exponent and coefficient vectors hashes exponents into `ht`
# and then constructs hashed polynomial vectors for `basis`
function fill_data!(basis, ht, exponents, coeffs)
    ngens = length(exponents)

    for i in 1:ngens
        while length(exponents[i]) >= ht.size - ht.load
            enlarge_hash_table!(ht)
        end
        # ht.exponents one can be reallocated together with ht,
        # so we need to reset it on each iteration
        etmp = ht.exponents[1]

        nterms = length(coeffs[i])
        basis.coeffs[i] = coeffs[i]
        basis.gens[i] = Vector{Int}(undef, nterms)
        poly = basis.gens[i]
        for j in 1:nterms
            poly[j] = insert_in_hash_table!(ht, exponents[i][j])
        end

        # sort terms (not needed),
        # beautify coefficients (not needed),
        # and all
    end

    # the initial update traverses all elements in
    # basis.ndone+1:basis.ntotal
    # which is 1:ngens
    basis.ntotal = ngens
end

# Initializes Basis and MonomialHashtable structures,
# fills input data from exponents and coeffs
#
# Hashtable initial size is set to tablesize
function initialize_structures(
            ring::PolyRing,
            exponents::Vector{Vector{Vector{UInt16}}},
            coeffs::Vector{Vector{UInt64}},
            rng::Random.AbstractRNG,
            tablesize::Int)

    # basis for storing basis elements,
    # pairset for storing critical pairs of basis elements to assess,
    # hashtable for hashing monomials occuring in the basis
    basis    = initialize_basis(ring, length(exponents))
    basis_ht = initialize_basis_hash_table(ring, rng, initial_size=tablesize)

    # filling the basis and hashtable with the given inputs
    fill_data!(basis, basis_ht, exponents, coeffs)

    # every monomial in hashtable is associated with its divmask
    # to perform divisions faster. Filling those
    fill_divmask!(basis_ht)

    # sort input, smaller leading terms first
    sort_gens_by_lead_increasing!(basis, basis_ht)

    # divide each polynomial by leading coefficient
    normalize_basis!(basis)

    basis, basis_ht
end


# Initializes Basis with the given hashtable,
# fills input data from exponents and coeffs
function initialize_structures(
            ring::PolyRing,
            exponents::Vector{Vector{Vector{UInt16}}},
            coeffs::Vector{Vector{UInt64}},
            rng::Random.AbstractRNG,
            tablesize::Int,
            present_ht::MonomialHashtable)

    # basis for storing basis elements,
    # pairset for storing critical pairs of basis elements to assess,
    # hashtable for hashing monomials occuring in the basis
    basis    = initialize_basis(ring, length(exponents))

    # filling the basis and hashtable with the given inputs
    fill_data!(basis, present_ht, exponents, coeffs)

    # sort input, smaller leading terms first
    sort_gens_by_lead_increasing!(basis, present_ht)

    # divide each polynomial by leading coefficient
    # We do not need normalization for normal forms
    # normalize_basis!(basis)

    basis, present_ht
end

#------------------------------------------------------------------------------

function reducegb_f4!(
            basis::Basis, matrix::MacaulayMatrix,
            ht::MonomialHashtable, symbol_ht::MonomialHashtable)

    etmp  = ht.exponents[1]
    etmp .= UInt16(0)
    # etmp is now set to zero, and has a zero hash

    reinitialize_matrix!(matrix, basis.nlead)
    uprows = matrix.uprows

    #=
    @warn "entering reduce"
    dump(basis, maxdepth=5)
    @warn "ht"
    println(ht.exponents[1:10])
    @warn "symbol"
    println(symbol_ht.exponents[1:10])
    println("NONRED ", basis.nonred)
    =#

    # add all non redundant elements from basis
    # as matrix upper rows
    for i in 1:basis.nlead
        matrix.nrows += 1
        uprows[matrix.nrows] = multiplied_poly_to_matrix_row!(
                                    symbol_ht, ht, UInt32(0), etmp,
                                    basis.gens[basis.nonred[i]])

        matrix.up2coef[matrix.nrows] = basis.nonred[i]
        # set lead index as 1
        symbol_ht.hashdata[uprows[matrix.nrows][1]].idx = 1
    end

    # needed for correct counting in symbol
    matrix.ncols = matrix.nrows
    matrix.nup = matrix.nrows

    #=
    @warn "after multiplied_poly_to_matrix_row"
    dump(basis, maxdepth=5)
    @warn "matrix"
    dump(matrix, maxdepth=5)
    @warn "ht"
    println(ht.exponents[1:10])
    =#

    symbolic_preprocessing!(basis, matrix, ht, symbol_ht)
    # all pivots are unknown
    for i in symbol_ht.offset:symbol_ht.load
        symbol_ht.hashdata[i].idx = 1
    end

    #=
    @warn "after symbolic"
    dump(basis, maxdepth=5)
    @warn "matrix"
    dump(matrix, maxdepth=5)
    @warn "ht"
    println(ht.exponents[1:10])
    =#

    # x1*x2^6 + 413612941*x1*x2^3
    #  x1^2*x2^3 + 174101409*x1*x2^5
    convert_hashes_to_columns!(matrix, symbol_ht)
    matrix.ncols = matrix.nleft + matrix.nright

    #=
    @warn "after convert"
    dump(matrix, maxdepth=5)
    =#

    sort_matrix_rows_decreasing!(matrix)

    interreduce_matrix_rows!(matrix, basis)

    #=
    @warn "after interreduce"
    dump(matrix, maxdepth=5)
    =#

    convert_matrix_rows_to_basis_elements_use_symbol!(matrix, basis)

    # no longer need in two hashtables
    ht = symbol_ht

    basis.ntotal = matrix.npivots + basis.ndone
    basis.ndone = matrix.npivots

    #=
    @warn "basis"
    dump(basis, maxdepth=5)
    =#

    #= we may have added some multiples of reduced basis polynomials
    * from the matrix, so we get rid of them. =#
    k = 0
    i = 1
    @label Letsgo
    while i <= basis.ndone
        for j in 1:k
            if is_monom_divisible(
                    basis.gens[basis.ntotal - i + 1][1],
                    basis.gens[basis.nonred[j]][1],
                    ht)

                i += 1
                @goto Letsgo
            end
        end
        k += 1
        basis.nonred[k] = basis.ntotal - i + 1
        # xd
        basis.lead[k] = ht.hashdata[basis.gens[basis.ntotal - i + 1][1]].divmask
        i += 1
    end
    basis.nlead = k

    # TODO
    sort_gens_by_lead_increasing_in_reduce!(basis, ht)
end

#------------------------------------------------------------------------------

function f4!(ring::PolyRing,
             basis,
             ht,
             reduced)

     # matrix storing coefficients in rows
     # wrt columns representing the current monomial basis
     matrix = initialize_matrix(ring)

     # initialize hash tables for update and symbolic preprocessing steps
     update_ht  = initialize_secondary_hash_table(ht)
     symbol_ht  = initialize_secondary_hash_table(ht)

     # a set to store critical pairs of polynomials to be reduced
     pairset = initialize_pairset()

     # makes basis fields valid,
     # does not copy,
     # checks for redundancy of new elems
     update!(pairset, basis, ht, update_ht)

     #=
     @warn "initial update"
     dump(basis, maxdepth = 5)
     =#

     d = 0
     # while there are pairs to be reduced
     while !isempty(pairset)
         d += 1
         @debug "F4 ITER $d"
         @debug "Available $(pairset.load) pairs"

         #=
         @warn "start of $d"
         dump(basis, maxdepth = 5)
         println(ht.exponents[1:10])
         =#

         # selects pairs for reduction from pairset following normal strategy
         # (minimal lcm degrees are selected),
         # and puts these into the matrix rows
         select_normal!(pairset, basis, matrix, ht, symbol_ht)
         @debug "Selected $(divexact(matrix.nrows, 2)) pairs"

         #=
         @warn "noxd $d"
         dump(basis, maxdepth = 5)
         dump(matrix, maxdepth = 5)
         println(ht.exponents[1:10])
         println(symbol_ht.exponents[1:10])
         =#

         symbolic_preprocessing!(basis, matrix, ht, symbol_ht)
         @debug "Matrix of size $((matrix.nrows, matrix.ncols)), density TODO"

         #=
         @warn "xd $d"
         dump(basis, maxdepth = 5)
         dump(matrix, maxdepth = 5)
         println(ht.exponents[1:10])
         println(symbol_ht.exponents[1:10])
         =#

         # reduces polys and obtains new potential basis elements
         reduction!(basis, matrix, ht, symbol_ht)
         @debug "Matrix reduced, density TODO"


         #@warn "after reduction"
         #dump(matrix, maxdepth = 5)

         #=
         printstyled("nice basis\n", color=:red)
         for (_, cfs, poly) in zip(1:basis.ntotal, basis.coeffs, basis.gens)
             for i in 1:length(poly)
                 c = cfs[i]
                 e = ht.exponents[poly[i]]
                 print("$c*$e + ")
             end
             println("")
         end
         println(basis.nonred)
         =#


         # update the current basis with polynomials produced from reduction,
         # does not copy,
         # checks for redundancy
         update!(pairset, basis, ht, update_ht)

         #=
         @warn "after update"
         printstyled("nice basis\n", color=:red)
         for (_, cfs, poly) in zip(1:basis.ntotal, basis.coeffs, basis.gens)
             for i in 1:length(poly)
                 c = cfs[i]
                 e = ht.exponents[poly[i]]
                 print("$c*$e + ")
             end
             println("")
         end
         println(basis.nonred)
         =#

         # TODO: is this okay hm ?
         # to be changed
         matrix    = initialize_matrix(ring)
         symbol_ht = initialize_secondary_hash_table(ht)
         # clear symbolic hashtable
         # clear matrix

         if d > 1000
             @error "Something is probably wrong in f4.."
             break
         end
     end

     # remove redundant elements
     filter_redundant!(basis)

     #=
     @warn "after filter red"
     printstyled("nice basis\n", color=:red)
     for (_, cfs, poly) in zip(1:basis.ntotal, basis.coeffs, basis.gens)
         for i in 1:length(poly)
             c = cfs[i]
             e = ht.exponents[poly[i]]
             print("$c*$e + ")
         end
         println("")
     end
     println("NONRED ", basis.nonred)
     println(basis.isred)
     println(basis.nlead)
     =#

     if reduced
         reducegb_f4!(basis, matrix, ht, symbol_ht)
         ht = symbol_ht
     end

     #=
     @warn "after reduce"
     printstyled("nice basis\n", color=:red)
     for (_, cfs, poly) in zip(1:basis.ntotal, basis.coeffs, basis.gens)
         for i in 1:length(poly)
             c = cfs[i]
             e = ht.exponents[poly[i]]
             print("$c*$e + ")
         end
         println("")
     end
     println(basis.nonred)
     =#

     basis, ht
end

#=
Main function to calculate the Groebner basis of the given polynomial ideal
in degrevlex ordering and finite fields coefficients.

Parameters
.

=#
function f4(ring::PolyRing,
            exponents::Vector{Vector{Vector{UInt16}}},
            coeffs::Vector{Vector{UInt64}},
            rng::Rng,
            reduced::Bool;
            tablesize::Int=2^16
            ) where {Rng<:Random.AbstractRNG}

    # initialize basis and hashtable with input polynomials,
    # fields are not meaningful yet and will be set during update! step
    basis, ht = initialize_structures(
                        ring, exponents, coeffs, rng, tablesize)

    # TODO
    basis, ht = f4!(ring, basis, ht, reduced)

    export_basis_data(basis, ht)
end
