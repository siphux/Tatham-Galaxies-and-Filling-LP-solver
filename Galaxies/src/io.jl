# Functions for reading, displaying and summarising Galaxies instances.

"""
Read an instance from an input file.

Expected format:

```txt
n m
a1 b1
...
am bm
```

The centers must have integer or half-integer coordinates between 1 and n.
"""
function readInputFile(inputFile::String)
    if !isfile(inputFile)
        error("Input file does not exist: " * inputFile)
    end

    lines = [strip(line) for line in readlines(inputFile) if strip(line) != ""]
    if isempty(lines)
        error("Input file is empty: " * inputFile)
    end

    firstLine = split(lines[1])
    if length(firstLine) != 2
        error("Line 1: expected two integers n m.")
    end

    parsedN = tryparse(Int, firstLine[1])
    parsedM = tryparse(Int, firstLine[2])
    if parsedN === nothing || parsedM === nothing
        error("Line 1: n and m must be integers.")
    end

    n = parsedN
    m = parsedM
    if n <= 0 || m <= 0
        error("Line 1: n and m must be positive.")
    end

    if length(lines) != m + 1
        error("Expected " * string(m) * " center lines, found " * string(length(lines) - 1) * ".")
    end

    centers = Tuple{Float64, Float64}[]
    for lineId in 2:(m + 1)
        centerLine = split(lines[lineId])
        if length(centerLine) != 2
            error("Line " * string(lineId) * ": expected two coordinates.")
        end

        a = tryparse(Float64, centerLine[1])
        b = tryparse(Float64, centerLine[2])
        if a === nothing || b === nothing
            error("Line " * string(lineId) * ": center coordinates must be numbers.")
        end
        if !(1 <= a <= n && 1 <= b <= n)
            error("Line " * string(lineId) * ": center is outside the grid.")
        end
        if !isHalfInteger(a) || !isHalfInteger(b)
            error("Line " * string(lineId) * ": coordinates must be integers or half-integers.")
        end

        push!(centers, (a, b))
    end

    if length(unique(centers)) != length(centers)
        error("Centers must be distinct.")
    end

    return n, m, centers
end

function isHalfInteger(x::Real)
    return abs(2 * x - round(2 * x)) <= 1e-9
end

function checkGridAndCenters(n::Int, m::Int, centers::Vector{Tuple{Float64, Float64}})
    if n <= 0
        error("Grid size must be positive.")
    end
    if m <= 0
        error("Number of centers must be positive.")
    end
    if length(centers) != m
        error("Expected " * string(m) * " centers, found " * string(length(centers)) * ".")
    end
    for (id, (a, b)) in enumerate(centers)
        if !(1 <= a <= n && 1 <= b <= n)
            error("Center " * string(id) * " is outside the grid.")
        end
        if !isHalfInteger(a) || !isHalfInteger(b)
            error("Center " * string(id) * " must have integer or half-integer coordinates.")
        end
    end
end

function checkSolutionSize(n::Int, solution::Vector{Int})
    if n <= 0
        error("Grid size must be positive.")
    end
    if length(solution) != n^2
        error("Expected a solution of length " * string(n^2) * ", found " * string(length(solution)) * ".")
    end
end

function cellId(n::Int, i::Int, j::Int)
    return (i - 1) * n + j
end

function centerText(text, width::Int)
    value = string(text)
    if length(value) >= width
        return value[1:width]
    end

    left = div(width - length(value), 2)
    right = width - length(value) - left
    return repeat(" ", left) * value * repeat(" ", right)
end

function emptyGridTokens(n::Int)
    lines = Vector{Vector{String}}()

    for row in 1:(2 * n + 1)
        current = String[]
        for col in 1:(2 * n + 1)
            if isodd(row) && isodd(col)
                push!(current, "+")
            elseif isodd(row)
                push!(current, "---")
            elseif isodd(col)
                push!(current, "|")
            else
                push!(current, "   ")
            end
        end
        push!(lines, current)
    end

    return lines
end

function centerToken(row::Int, col::Int, current::String)
    if iseven(row) && iseven(col)
        return " o "
    elseif iseven(row)
        return "o"
    elseif iseven(col)
        return occursin("=", current) ? "=o=" : "-o-"
    else
        return "o"
    end
end

function placeCenters!(lines::Vector{Vector{String}}, n::Int, centers::Vector{Tuple{Float64, Float64}})
    for (a, b) in centers
        row = round(Int, 2 * a)
        col = round(Int, 2 * b)
        if 1 <= row <= 2 * n + 1 && 1 <= col <= 2 * n + 1
            lines[row][col] = centerToken(row, col, lines[row][col])
        end
    end
end

function printTokens(lines::Vector{Vector{String}})
    for line in lines
        println(join(line, ""))
    end
end

"""
Print an unresolved Galaxies instance in the terminal.
"""
function displayGrid(n::Int, m::Int, centers::Vector{Tuple{Float64, Float64}}; showCoordinates::Bool = false)
    checkGridAndCenters(n, m, centers)

    println("Instance ", n, "x", n, " with ", m, " centers")
    lines = emptyGridTokens(n)
    placeCenters!(lines, n, centers)
    printTokens(lines)

    if showCoordinates
        printCenterCoordinates(centers)
    end

    return nothing
end

function displayGrid(n::Int, centers::Vector{Tuple{Float64, Float64}}; showCoordinates::Bool = false)
    return displayGrid(n, length(centers), centers; showCoordinates = showCoordinates)
end

function displayGrid(instance; showCoordinates::Bool = false)
    n, m, centers = instance
    return displayGrid(n, m, centers; showCoordinates = showCoordinates)
end

function printCenterCoordinates(centers::Vector{Tuple{Float64, Float64}})
    println("Centers:")
    for (id, center) in enumerate(centers)
        println("  ", id, ": (", center[1], ", ", center[2], ")")
    end
end

function solutionBoundaries(n::Int, solution::Vector{Int})
    horizontal = falses(n + 1, n)
    vertical = falses(n, n + 1)

    for line in 1:(n + 1)
        for j in 1:n
            horizontal[line, j] =
                line == 1 ||
                line == n + 1 ||
                solution[cellId(n, line - 1, j)] != solution[cellId(n, line, j)]
        end
    end

    for i in 1:n
        for line in 1:(n + 1)
            vertical[i, line] =
                line == 1 ||
                line == n + 1 ||
                solution[cellId(n, i, line - 1)] != solution[cellId(n, i, line)]
        end
    end

    return horizontal, vertical
end

function solutionTokens(n::Int, solution::Vector{Int}; showValues::Bool = false)
    checkSolutionSize(n, solution)
    horizontal, vertical = solutionBoundaries(n, solution)
    lines = Vector{Vector{String}}()

    for row in 1:(2 * n + 1)
        current = String[]
        for col in 1:(2 * n + 1)
            if isodd(row) && isodd(col)
                h = div(row + 1, 2)
                v = div(col + 1, 2)
                hasBoundary =
                    (v > 1 && horizontal[h, v - 1]) ||
                    (v <= n && horizontal[h, v]) ||
                    (h > 1 && vertical[h - 1, v]) ||
                    (h <= n && vertical[h, v])
                push!(current, hasBoundary ? "+" : " ")
            elseif isodd(row)
                h = div(row + 1, 2)
                j = div(col, 2)
                push!(current, horizontal[h, j] ? "---" : "   ")
            elseif isodd(col)
                i = div(row, 2)
                v = div(col + 1, 2)
                push!(current, vertical[i, v] ? "|" : " ")
            else
                i = div(row, 2)
                j = div(col, 2)
                value = showValues ? centerText(solution[cellId(n, i, j)], 3) : "   "
                push!(current, value)
            end
        end
        push!(lines, current)
    end

    return lines
end

"""
Print a solved Galaxies instance in the terminal.
"""
function displaySolution(
    n::Int,
    m::Int,
    centers::Vector{Tuple{Float64, Float64}},
    solution::Vector{Int};
    showCoordinates::Bool = false,
    showValues::Bool = false
)
    checkGridAndCenters(n, m, centers)
    checkSolutionSize(n, solution)

    println("Solution ", n, "x", n, " with ", m, " galaxies")
    lines = solutionTokens(n, solution; showValues = showValues)
    placeCenters!(lines, n, centers)
    printTokens(lines)

    if showCoordinates
        printCenterCoordinates(centers)
    end

    return nothing
end

function displaySolution(n::Int, solution::Vector{Int}; showValues::Bool = true)
    checkSolutionSize(n, solution)
    m = isempty(solution) ? 0 : maximum(solution)
    centers = Tuple{Float64, Float64}[]
    println("Solution ", n, "x", n)
    lines = solutionTokens(n, solution; showValues = showValues)
    placeCenters!(lines, n, centers)
    printTokens(lines)
    return nothing
end

function displaySolution(instance, solution::Vector{Int}; showCoordinates::Bool = false, showValues::Bool = false)
    n, m, centers = instance
    return displaySolution(n, m, centers, solution; showCoordinates = showCoordinates, showValues = showValues)
end

function parseResultBool(value::String)
    lowered = lowercase(strip(value))
    if lowered == "true"
        return true
    elseif lowered == "false"
        return false
    end
    error("Expected true or false, found: " * value)
end

"""
Read the useful metadata from a result file produced by `writeResultFile`.
"""
function readResultSummary(resultFile::String)
    if !isfile(resultFile)
        error("Result file does not exist: " * resultFile)
    end

    values = Dict{String, String}()
    for line in readlines(resultFile)
        parts = split(line, "=", limit = 2)
        if length(parts) == 2
            values[strip(parts[1])] = strip(parts[2])
        end
    end

    for key in ["solveTime", "isOptimal", "n", "m"]
        if !haskey(values, key)
            error("Missing " * key * " in result file: " * resultFile)
        end
    end

    return (
        solveTime = parse(Float64, values["solveTime"]),
        isOptimal = parseResultBool(values["isOptimal"]),
        n = parse(Int, values["n"]),
        m = parse(Int, values["m"])
    )
end

function resultMethodFolders(resultFolder::String)
    if !isdir(resultFolder)
        error("Result folder does not exist: " * resultFolder)
    end

    methods = String[]
    for name in sort(readdir(resultFolder))
        path = joinpath(resultFolder, name)
        if isdir(path) && any(endswith(file, ".txt") for file in readdir(path))
            push!(methods, name)
        end
    end

    return methods
end

function resolveResultFolder(resultFolder::String)
    methods = resultMethodFolders(resultFolder)
    if isempty(methods) && isdir(joinpath(resultFolder, "final"))
        resultFolder = joinpath(resultFolder, "final")
        methods = resultMethodFolders(resultFolder)
    end
    if isempty(methods)
        error("No result method folder found in: " * resultFolder)
    end
    return resultFolder, methods
end

function latexEscape(text::String)
    return replace(text, "_" => "\\_")
end

function formatResultTime(time::Real)
    return string(round(Float64(time); digits = 3))
end

function latexStatus(isSolved::Bool)
    return isSolved ? "Oui" : "Non"
end

"""
Create a LaTeX table comparing all result folders in `resultFolder`.

By default, `resultFolder` is the folder containing `outputFile`. If this folder
only contains grouped experiment folders, the function automatically uses
`resultFolder/final`.
"""
function resultsArray(outputFile::String; resultFolder::String = dirname(outputFile))
    resultFolder, methods = resolveResultFolder(resultFolder)

    instances = Set{String}()
    for method in methods
        for file in readdir(joinpath(resultFolder, method))
            if endswith(file, ".txt")
                push!(instances, file)
            end
        end
    end
    orderedInstances = sort(collect(instances))

    outputFolder = dirname(outputFile)
    if !isempty(outputFolder)
        mkpath(outputFolder)
    end

    open(outputFile, "w") do fout
        println(fout, "\\documentclass{article}")
        println(fout, "\\usepackage[utf8]{inputenc}")
        println(fout, "\\usepackage[french]{babel}")
        println(fout, "\\begin{document}")
        println(fout, "\\begin{center}")
        println(fout, "\\renewcommand{\\arraystretch}{1.3}")
        println(fout, "\\begin{tabular}{l", repeat("rr", length(methods)), "}")
        println(fout, "\\hline")

        firstHeader = "\\textbf{Instance}"
        for method in methods
            firstHeader *= " & \\multicolumn{2}{c}{\\textbf{" * latexEscape(method) * "}}"
        end
        println(fout, firstHeader, "\\\\")

        secondHeader = ""
        for _ in methods
            secondHeader *= " & \\textbf{Temps (s)} & \\textbf{Resolue ?}"
        end
        println(fout, secondHeader, "\\\\ \\hline")

        for instance in orderedInstances
            row = latexEscape(instance)
            for method in methods
                resultFile = joinpath(resultFolder, method, instance)
                if isfile(resultFile)
                    summary = readResultSummary(resultFile)
                    row *= " & " * formatResultTime(summary.solveTime) * " & " * latexStatus(summary.isOptimal)
                else
                    row *= " & -- & --"
                end
            end
            println(fout, row, "\\\\")
        end

        println(fout, "\\hline")
        println(fout, "\\end{tabular}")
        println(fout, "\\end{center}")
        println(fout, "\\end{document}")
    end

    return outputFile
end

"""
Create a performance diagram from the result files.

This function requires the optional package `Plots`.
"""
function performanceDiagram(outputFile::String; resultFolder::String = dirname(outputFile))
    resultFolder, methods = resolveResultFolder(resultFolder)

    instanceSets = [
        Set(file for file in readdir(joinpath(resultFolder, method)) if endswith(file, ".txt"))
        for method in methods
    ]
    instances = sort(collect(reduce(intersect, instanceSets)))

    if isempty(instances)
        error("No common result files found.")
    end

    timesByMethod = Dict{String, Vector{Float64}}()
    for method in methods
        ratios = Float64[]
        timesByMethod[method] = ratios
    end

    for instance in instances
        summaries = Dict(
            method => readResultSummary(joinpath(resultFolder, method, instance))
            for method in methods
        )
        solvedTimes = [
            summary.solveTime
            for summary in values(summaries)
            if summary.isOptimal && summary.solveTime >= 0
        ]

        if isempty(solvedTimes)
            continue
        end

        bestTime = max(minimum(solvedTimes), 1e-9)
        for method in methods
            summary = summaries[method]
            ratio = summary.isOptimal ? summary.solveTime / bestTime : Inf
            push!(timesByMethod[method], ratio)
        end
    end

    try
        @eval using Plots
    catch
        error("Package Plots is required for performanceDiagram. Run: import Pkg; Pkg.add(\"Plots\")")
    end

    plotObject = plot(
        xlabel = "Performance ratio",
        ylabel = "Proportion solved",
        title = "Galaxies performance profile",
        legend = :bottomright
    )

    xValues = range(1.0, 5.0, length = 100)
    for method in methods
        ratios = timesByMethod[method]
        yValues = [isempty(ratios) ? 0.0 : count(ratio -> ratio <= x, ratios) / length(ratios) for x in xValues]
        plot!(plotObject, xValues, yValues, label = method, linewidth = 2)
    end

    savefig(plotObject, outputFile)
    return outputFile
end

nothing
