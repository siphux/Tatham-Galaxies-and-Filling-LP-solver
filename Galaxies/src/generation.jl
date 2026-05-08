# This file contains methods to generate Galaxies instances.
using Random

include("io.jl")

"""
Return all possible center positions for an n x n Galaxies grid.

Coordinates are integers or half-integers from 1 to n.
"""
function possibleCenterPositions(n::Int)
    if n <= 0
        error("Grid size must be positive.")
    end

    coordinates = [x / 2 for x in 2:2 * n]
    return [(a, b) for a in coordinates for b in coordinates]
end

"""
Generate a random Galaxies instance.

Arguments:
- n: size of the n x n grid
- m: number of centers

Keyword arguments:
- feasibleOnly: keep only an instance solved by CPLEX
- uniqueOnly: keep only an instance with a unique CPLEX solution
- maxTries: maximal number of random candidates
"""
function generateInstance(
    n::Int,
    m::Int;
    feasibleOnly::Bool = false,
    uniqueOnly::Bool = false,
    maxTries::Int = 100,
    rng::AbstractRNG = Random.default_rng(),
    useCallback::Bool = true,
    cplexTimeLimit::Union{Nothing, Real} = nothing
)

    positions = possibleCenterPositions(n)
    if m <= 0
        error("The number of centers must be positive.")
    end
    if m > length(positions)
        error("Too many centers for this grid size.")
    end

    if uniqueOnly
        feasibleOnly = true
    end

    for _ in 1:maxTries
        centers = sort(shuffle(rng, positions)[1:m])

        if !feasibleOnly
            return n, m, centers
        end

        if !isdefined(@__MODULE__, :cplexSolve)
            error("Feasible or unique generation requires include(\"./src/resolution.jl\").")
        end

        if uniqueOnly
            isFeasible, isUnique, _, _ = hasUniqueSolution(
                n,
                m,
                centers;
                useCallback = useCallback,
                timeLimit = cplexTimeLimit
            )
            if isFeasible && isUnique
                return n, m, centers
            end
        else
            isOptimal, _, _ = cplexSolve(
                n,
                m,
                centers;
                useCallback = useCallback,
                timeLimit = cplexTimeLimit
            )
            if isOptimal
                return n, m, centers
            end
        end
    end

    error("Unable to generate a matching instance after " * string(maxTries) * " tries.")
end

"""
Compatibility method with the original template.

The density is interpreted as the approximate ratio m / n^2.
"""
function generateInstance(n::Int, density::Float64; kwargs...)
    if density <= 0 || density > 1
        error("Density must be in ]0, 1].")
    end

    m = max(1, min(n^2, round(Int, density * n^2)))
    return generateInstance(n, m; kwargs...)
end

"""
Write an instance to a text file.
"""
function writeInstanceFile(outputFile::String, n::Int, m::Int, centers::Vector{Tuple{Float64, Float64}})
    folder = dirname(outputFile)
    if !isempty(folder)
        mkpath(folder)
    end

    open(outputFile, "w") do fout
        println(fout, n, " ", m)
        for center in centers
            println(fout, center[1], " ", center[2])
        end
    end
end

"""
Generate a data set of Galaxies instances.

Files are generated only if they do not already exist, unless overwrite=true.
"""
function generateDataSet(;
    dataFolder::String = joinpath(@__DIR__, "..", "data"),
    sizes::Vector{Tuple{Int, Int}} = [(4, 4), (5, 5), (6, 6)],
    instancesPerSize::Int = 2,
    feasibleOnly::Bool = true,
    uniqueOnly::Bool = false,
    maxTries::Int = 100,
    cplexTimeLimit::Union{Nothing, Real} = nothing,
    overwrite::Bool = false,
    rng::AbstractRNG = Random.default_rng()
)

    mkpath(dataFolder)
    generatedFiles = String[]

    for (n, m) in sizes
        for id in 1:instancesPerSize
            file = joinpath(dataFolder, "galaxies_n$(n)_m$(m)_$(id).txt")

            if isfile(file) && !overwrite
                push!(generatedFiles, file)
                continue
            end

            nGenerated, mGenerated, centers = generateInstance(
                n,
                m;
                feasibleOnly = feasibleOnly,
                uniqueOnly = uniqueOnly,
                maxTries = maxTries,
                cplexTimeLimit = cplexTimeLimit,
                rng = rng
            )
            writeInstanceFile(file, nGenerated, mGenerated, centers)
            push!(generatedFiles, file)
        end
    end

    return generatedFiles
end

nothing
