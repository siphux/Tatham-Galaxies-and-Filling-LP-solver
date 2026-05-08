# This file contains methods to solve an instance (heuristically or with CPLEX)
using JuMP
using CPLEX
using Random

include("generation.jl")

TOL = 0.00001

"""
Solve an instance with CPLEX
"""
function cplexSolve(
    n::Int,
    m::Int,
    centers::Vector{Tuple{Float64, Float64}};
    useCallback::Bool = true,
    verboseCallback::Bool = false,
    excludedSolutions::Vector{Vector{Int}} = Vector{Vector{Int}}(),
    silent::Bool = true,
    timeLimit::Union{Nothing, Real} = nothing
)

    K = 1:n^2
    R = 1:m

    coord(k) = (div(k-1,n)+1, mod(k-1,n)+1)
    cellId(i,j) = (i-1)*n + j

    sym = zeros(Int, n^2, m)

    for k in K
        i,j = coord(k)
        for r in R
            a,b = centers[r]

            isym = round(Int, 2*a - i)
            jsym = round(Int, 2*b - j)

            if 1 <= isym <= n && 1 <= jsym <= n
                # The symmetric cell exists.
                sym[k, r] = cellId(isym, jsym)
            else
                # The symmetric cell is outside the grid.
                sym[k, r] = 0
            end
        end
    end

    # Create the model
    mModel = Model(CPLEX.Optimizer)
    if silent
        set_silent(mModel)
    end
    if timeLimit !== nothing
        if timeLimit <= 0
            error("timeLimit must be positive.")
        end
        set_time_limit_sec(mModel, Float64(timeLimit))
    end

    @variable(mModel, y[K, R], Bin)

    for k in K
        @constraint(mModel, sum(y[k, r] for r in R) == 1)
        for r in R
            if sym[k, r] == 0
                @constraint(mModel, y[k, r] == 0)
            else
                @constraint(mModel, y[k, r] == y[sym[k, r], r])
            end
        end
    end

    centerCellsByGalaxy = [centerCells(n, centers[r]) for r in R]
    for r in R
        for k in centerCellsByGalaxy[r]
            @constraint(mModel, y[k, r] == 1)
        end
    end

    for excludedSolution in excludedSolutions
        checkSolutionForModel(n, m, excludedSolution)
        @constraint(mModel, sum(y[k, excludedSolution[k]] for k in K) <= n^2 - 1)
    end

    @objective(mModel, Min, 0)

    if useCallback
        set_attribute(mModel, JuMP.MOI.NumberOfThreads(), 1)

        function connectivityCallback(cb_data)
            status = callback_node_status(cb_data, mModel)
            if status != JuMP.MOI.CALLBACK_NODE_STATUS_INTEGER
                return
            end

            candidateSolution = extractCallbackSolution(cb_data, y, n, m)
            problem = firstDisconnectedGalaxy(n, m, candidateSolution)
            if problem === nothing
                return
            end

            r, components = problem
            centerSet = Set(centerCellsByGalaxy[r])
            cutsAdded = 0

            for component in components
                if !isempty(intersect(Set(component), centerSet))
                    continue
                end

                border = componentBorder(n, component)
                con = @build_constraint(
                    sum(y[k, r] for k in component) -
                    sum(y[k, r] for k in border) <= length(component) - 1
                )
                JuMP.MOI.submit(mModel, JuMP.MOI.LazyConstraint(cb_data), con)
                cutsAdded += 1
            end

            if verboseCallback && cutsAdded > 0
                println(
                    "Callback: added ",
                    cutsAdded,
                    " connectivity cut(s) for galaxy ",
                    r,
                    "."
                )
            end
        end

        set_attribute(mModel, JuMP.MOI.LazyConstraintCallback(), connectivityCallback)
    end

    # Start a chronometer
    start = time()

    # Solve the model
    optimize!(mModel)

    solveTime = time() - start
    isOptimal = termination_status(mModel) == JuMP.MOI.OPTIMAL

    solution = zeros(Int, n^2)
    if isOptimal
        for k in K
            for r in R
                if value(y[k, r]) > 0.5
                    solution[k] = r
                end
            end
        end
    end

    # Return:
    # 1 - true if an optimum is found
    # 2 - the resolution time
    # 3 - the solution: solution[k] is the galaxy assigned to cell k
    return isOptimal, solveTime, solution
    
end

"""
Return whether an instance is feasible and whether its solution is unique.

The uniqueness test solves the instance once, then solves it a second time with
a constraint excluding the first solution.
"""
function hasUniqueSolution(
    n::Int,
    m::Int,
    centers::Vector{Tuple{Float64, Float64}};
    useCallback::Bool = true,
    timeLimit::Union{Nothing, Real} = nothing
)

    isFeasible, firstTime, solution = cplexSolve(
        n,
        m,
        centers;
        useCallback = useCallback,
        timeLimit = timeLimit
    )
    if !isFeasible
        return false, false, firstTime, solution
    end

    hasSecondSolution, secondTime, _ = cplexSolve(
        n,
        m,
        centers;
        useCallback = useCallback,
        excludedSolutions = [solution],
        timeLimit = timeLimit
    )

    return true, !hasSecondSolution, firstTime + secondTime, solution
end

"""
Return the cells that contain part of a Galaxies center.
"""
function centerCells(n::Int, center::Tuple{Float64, Float64})

    a, b = center
    cells = Int[]

    for i in 1:n
        for j in 1:n
            if abs(i - a) <= 0.5 && abs(j - b) <= 0.5
                push!(cells, (i - 1) * n + j)
            end
        end
    end

    return cells
end

"""
Extract the integer candidate solution from a CPLEX/JuMP callback.
"""
function extractCallbackSolution(cb_data, y, n::Int, m::Int)

    solution = zeros(Int, n^2)

    for k in 1:n^2
        for r in 1:m
            if callback_value(cb_data, y[k, r]) > 0.5
                solution[k] = r
                break
            end
        end
    end

    return solution
end

"""
Return the 4-neighbors of a cell in an n x n grid.

Cells are indexed from 1 to n^2, row by row.
"""
function cellNeighbors(n::Int, k::Int)

    if n <= 0
        error("Grid size must be positive.")
    end

    if k < 1 || k > n^2
        error("Cell index is outside the grid.")
    end

    i = div(k - 1, n) + 1
    j = mod(k - 1, n) + 1

    neighbors = Int[]

    if i > 1
        push!(neighbors, (i - 2) * n + j)
    end
    if i < n
        push!(neighbors, i * n + j)
    end
    if j > 1
        push!(neighbors, (i - 1) * n + j - 1)
    end
    if j < n
        push!(neighbors, (i - 1) * n + j + 1)
    end

    return neighbors
end

"""
Return cells outside a component that touch it by an edge.
"""
function componentBorder(n::Int, component::Vector{Int})

    componentSet = Set(component)
    border = Set{Int}()

    for k in component
        for neighbor in cellNeighbors(n, k)
            if !(neighbor in componentSet)
                push!(border, neighbor)
            end
        end
    end

    return sort(collect(border))
end

"""
Return all connected components of galaxy r in a solution.

Each component is a vector of cell indices.
"""
function getConnectedComponents(n::Int, solution::Vector{Int}, r::Int)

    checkSolutionForConnectivity(n, solution)

    unvisited = Set{Int}()
    for k in 1:n^2
        if solution[k] == r
            push!(unvisited, k)
        end
    end

    components = Vector{Vector{Int}}()

    while !isempty(unvisited)
        start = first(unvisited)
        stack = [start]
        component = Int[]
        delete!(unvisited, start)

        while !isempty(stack)
            k = pop!(stack)
            push!(component, k)

            for neighbor in cellNeighbors(n, k)
                if neighbor in unvisited
                    delete!(unvisited, neighbor)
                    push!(stack, neighbor)
                end
            end
        end

        push!(components, sort(component))
    end

    return components
end

"""
Return true if galaxy r is connected in a solution.
"""
function isConnectedGalaxy(n::Int, solution::Vector{Int}, r::Int)
    return length(getConnectedComponents(n, solution, r)) == 1
end

"""
Alias kept for project wording: a galaxy is a connected component candidate.
"""
function isConnectedComponent(n::Int, solution::Vector{Int}, r::Int)
    return isConnectedGalaxy(n, solution, r)
end

"""
Return true if every galaxy from 1 to m is connected.
"""
function isConnectedSolution(n::Int, m::Int, solution::Vector{Int})
    for r in 1:m
        if !isConnectedGalaxy(n, solution, r)
            return false
        end
    end

    return true
end

"""
Return the first disconnected galaxy and its components, or nothing.
"""
function firstDisconnectedGalaxy(n::Int, m::Int, solution::Vector{Int})
    for r in 1:m
        components = getConnectedComponents(n, solution, r)
        if length(components) != 1
            return r, components
        end
    end

    return nothing
end

function checkSolutionForConnectivity(n::Int, solution::Vector{Int})
    if n <= 0
        error("Grid size must be positive.")
    end

    if length(solution) != n^2
        error("Solution length must be n^2.")
    end
end

function checkSolutionForModel(n::Int, m::Int, solution::Vector{Int})
    checkSolutionForConnectivity(n, solution)

    for value in solution
        if value < 1 || value > m
            error("Solution contains a galaxy id outside 1:m.")
        end
    end
end

"""
Heuristically solve an instance
"""
function heuristicSolve(
    n::Int,
    m::Int,
    centers::Vector{Tuple{Float64, Float64}};
    maxTries::Int = 1000,
    timeLimit::Float64 = 100.0,
    rng::AbstractRNG = Random.default_rng()
)

    start = time()
    sym = symmetryTable(n, m, centers)

    for _ in 1:maxTries
        if time() - start >= timeLimit
            break
        end

        solution = zeros(Int, n^2)
        isValidStart = true

        for r in 1:m
            for k in centerCells(n, centers[r])
                if !assignSymmetricPair!(solution, sym, k, r)
                    isValidStart = false
                    break
                end
            end
            if !isValidStart
                break
            end
        end

        if !isValidStart
            continue
        end

        while any(==(0), solution)
            progress = false

            for k in shuffle(rng, findall(==(0), solution))
                candidates = Int[]
                for r in 1:m
                    s = sym[k, r]
                    if s != 0 && canAssignPair(solution, k, s, r) && touchesGalaxy(n, solution, [k, s], r)
                        push!(candidates, r)
                    end
                end

                if !isempty(candidates)
                    r = rand(rng, candidates)
                    assignSymmetricPair!(solution, sym, k, r)
                    progress = true
                end
            end

            if !progress
                break
            end
        end

        if isCompleteValidSolution(n, m, centers, solution)
            return true, time() - start, solution
        end
    end

    return false, time() - start, zeros(Int, n^2)
end 

function symmetryTable(n::Int, m::Int, centers::Vector{Tuple{Float64, Float64}})
    sym = zeros(Int, n^2, m)

    for k in 1:n^2
        i = div(k - 1, n) + 1
        j = mod(k - 1, n) + 1

        for r in 1:m
            a, b = centers[r]
            isym = round(Int, 2 * a - i)
            jsym = round(Int, 2 * b - j)

            if 1 <= isym <= n && 1 <= jsym <= n
                sym[k, r] = (isym - 1) * n + jsym
            end
        end
    end

    return sym
end

function canAssignPair(solution::Vector{Int}, k::Int, s::Int, r::Int)
    return (solution[k] == 0 || solution[k] == r) && (solution[s] == 0 || solution[s] == r)
end

function assignSymmetricPair!(solution::Vector{Int}, sym, k::Int, r::Int)
    s = sym[k, r]
    if s == 0 || !canAssignPair(solution, k, s, r)
        return false
    end

    solution[k] = r
    solution[s] = r
    return true
end

function touchesGalaxy(n::Int, solution::Vector{Int}, cells::Vector{Int}, r::Int)
    for k in cells
        if solution[k] == r
            return true
        end

        for neighbor in cellNeighbors(n, k)
            if solution[neighbor] == r
                return true
            end
        end
    end

    return false
end

function isCompleteValidSolution(
    n::Int,
    m::Int,
    centers::Vector{Tuple{Float64, Float64}},
    solution::Vector{Int}
)

    if any(==(0), solution)
        return false
    end

    if !isConnectedSolution(n, m, solution)
        return false
    end

    sym = symmetryTable(n, m, centers)
    for k in 1:n^2
        r = solution[k]
        if sym[k, r] == 0 || solution[sym[k, r]] != r
            return false
        end
    end

    for r in 1:m
        for k in centerCells(n, centers[r])
            if solution[k] != r
                return false
            end
        end
    end

    return true
end

"""
Solve all `.txt` instances in `dataFolder`.

The results are written in one subfolder per method inside `resFolder`.
By default, already existing result files are kept unless `overwrite = true`.
"""
function solveDataSet(;
    dataFolder::String = joinpath(@__DIR__, "..", "data"),
    resFolder::String = joinpath(@__DIR__, "..", "res"),
    resolutionMethods::Vector{String} = ["cplex"],
    overwrite::Bool = false,
    cplexCallback::Bool = true,
    cplexTimeLimit::Union{Nothing, Real} = nothing,
    heuristicTimeLimit::Float64 = 100.0
)

    for method in resolutionMethods
        mkpath(joinpath(resFolder, method))
    end

    resultFiles = String[]

    for file in sort(filter(x -> endswith(x, ".txt"), readdir(dataFolder)))
        inputFile = joinpath(dataFolder, file)
        n, m, centers = readInputFile(inputFile)

        println("-- Resolution of ", file)

        for method in resolutionMethods
            outputFile = joinpath(resFolder, method, file)

            if isfile(outputFile) && !overwrite
                println(method, ": already solved")
                push!(resultFiles, outputFile)
                continue
            end

            isOptimal = false
            solveTime = -1.0
            solution = zeros(Int, n^2)

            if method == "cplex"
                isOptimal, solveTime, solution = cplexSolve(
                    n,
                    m,
                    centers;
                    useCallback = cplexCallback,
                    timeLimit = cplexTimeLimit
                )
            elseif method == "heuristic"
                isOptimal, solveTime, solution = heuristicSolve(
                    n,
                    m,
                    centers;
                    timeLimit = heuristicTimeLimit
                )
            else
                error("Unknown resolution method: " * method)
            end

            writeResultFile(outputFile, n, m, centers, isOptimal, solveTime, solution)
            println(method, " optimal: ", isOptimal)
            println(method, " time: ", round(solveTime, sigdigits = 3), "s")
            push!(resultFiles, outputFile)
        end

        println()
    end

    return resultFiles
end

function writeResultFile(
    outputFile::String,
    n::Int,
    m::Int,
    centers::Vector{Tuple{Float64, Float64}},
    isOptimal::Bool,
    solveTime::Float64,
    solution::Vector{Int}
)

    mkpath(dirname(outputFile))

    open(outputFile, "w") do fout
        println(fout, "solveTime = ", solveTime)
        println(fout, "isOptimal = ", isOptimal)
        println(fout, "n = ", n)
        println(fout, "m = ", m)
        println(fout, "centers = ", repr(centers))
        println(fout, "solution = ", repr(solution))
    end
end

nothing
