using Random
using Statistics
using Dates


include("generation.jl")

Random.seed!(42)

#tailles plateau
const SIZES_CPLEX = [
    (5, 5),
    (6, 6),
    (7, 7),
    (8, 8),
    (10, 10),
    (12, 12),
    (14, 14)
]

const SIZES_HEURISTIC = [
    (10, 10),
    (12, 12)
]

const EMPTY_PERCENTAGES = [0.50, 0.60, 0.70, 0.80, 0.90]

const N_INSTANCES_PER_CONFIG = 3

const HEURISTIC_TIME_LIMIT = 120.0


const PROJECT_ROOT = dirname(@__DIR__)
const DATA_DIR = joinpath(PROJECT_ROOT, "data", "filling_experiments")
const RES_DIR = joinpath(PROJECT_ROOT, "res", "filling_experiments")
const SOL_DIR = joinpath(RES_DIR, "solutions")

function ensure_dirs()
    for d in [DATA_DIR, RES_DIR, SOL_DIR,
              joinpath(SOL_DIR, "cplex"),
              joinpath(SOL_DIR, "heuristic")]
        if !isdir(d)
            mkpath(d)
        end
    end
end


function size_label(n::Int, m::Int)
    return string(n, "x", m)
end


function pct_label(p::Float64)
    return string(round(Int, 100p))
end


function count_empty(board::Matrix{Int})
    return count(x -> x == -1, board)
end


function real_empty_percentage(board::Matrix{Int})
    n, m = size(board)
    return count_empty(board) / (n * m)
end


function write_instance(path::String, board::Matrix{Int})
    n, m = size(board)
    open(path, "w") do f
        write(f, "$n\n")
        write(f, "$m\n")
        for i in 1:n
            write(f, join(board[i, :], ",") * "\n")
        end
    end
end


function write_solution(path::String, res)
    open(path, "w") do f
        write(f, "solveTime = $(res.time_taken)\n")
        write(f, "isOptimal = $(res.is_optimal)\n")

        if res.solution === nothing
            write(f, "# Pas de solution trouvee\n")
        else
            
            n, m = size(res.solution)
            for i in 1:n
                ligne_str = join(res.solution[i, :], ",")
                    write(f, "# $ligne_str\n")
            end
        end
    end
end


function csv_escape(x)
    s = string(x)
    if occursin(",", s) || occursin("\"", s) || occursin("\n", s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    else
        return s
    end
end


function write_csv(path::String, header::Vector{String}, rows::Vector{Vector})
    open(path, "w") do f
        write(f, join(header, ",") * "\n")
        for row in rows
            write(f, join(csv_escape.(row), ",") * "\n")
        end
    end
end

function safe_generate_instance(n::Int, m::Int, empty_pct::Float64; max_tries::Int = 3)
    for attempt in 1:max_tries
        try
            println("  Génération tentative $attempt : $(n)x$(m), $(round(Int, empty_pct*100))% vide")
            board = generateInstance(n, m, empty_pct)

            if board !== nothing && board isa Matrix{Int}
                return board
            end
        catch e
            println("  Erreur pendant la génération : ", e)
        end
    end

    error("Impossible de générer une instance $(n)x$(m) avec $(empty_pct*100)% de cases vides.")
end


function solve_one_instance(board::Matrix{Int}, method::String)
    if method == "cplex"
        result = cplexSolve(board)

        return (
            solution = result.solution,
            time_taken = result.time_taken,
            is_optimal = result.optimality,
        )

    elseif method == "heuristic"
        result = heuristicSolve(board; time_limit = HEURISTIC_TIME_LIMIT)

        return (
            solution = result.solution,
            time_taken = result.time_taken,
            is_optimal = result.optimality,
        )

    else
        error("Méthode inconnue : $method")
    end
end


function run_experiments(method::String = "both")
    ensure_dirs()

    allowed_methods = ["cplex", "heuristic", "both"]

    if !(method in allowed_methods)
        error("Méthode inconnue : $method. Utilise : cplex, heuristic ou both.")
    end

    methods = method == "both" ? ["cplex", "heuristic"] : [method]

    raw_rows = Vector{Vector}()

    total_configs = 0
    for meth in methods
        sizes = meth == "cplex" ? SIZES_CPLEX : SIZES_HEURISTIC
        total_configs += length(sizes) * length(EMPTY_PERCENTAGES) * N_INSTANCES_PER_CONFIG
    end

    current_config = 0

    println("Début des expériences Filling")
    println("Méthode(s) utilisée(s) : $(join(methods, ", "))")
    println("Nombre total d'expériences : $total_configs")
    println()

    for meth in methods
        sizes = meth == "cplex" ? SIZES_CPLEX : SIZES_HEURISTIC

        println("==============================================================")
        println("Méthode courante : $meth")
        println("Tailles testées : $(join([size_label(n, m) for (n, m) in sizes], ", "))")
        println("==============================================================")
        println()

        for (n, m) in sizes
            for empty_pct in EMPTY_PERCENTAGES
                for rep in 1:N_INSTANCES_PER_CONFIG

                    current_config += 1

                    slabel = size_label(n, m)
                    plabel = pct_label(empty_pct)

                    instance_name = "filling_$(slabel)_empty$(plabel)_rep$(rep).txt"
                    instance_path = joinpath(DATA_DIR, instance_name)

                    println("==================================================")
                    println("Expérience $current_config / $total_configs")
                    println("Instance : $instance_name")
                    println("Méthode : $meth")
                    println("==================================================")

                    if isfile(instance_path)
                        println("Instance déjà existante, lecture du fichier.")
                        board = readInputFile(instance_path)
                    else
                        board = safe_generate_instance(n, m, empty_pct)
                        write_instance(instance_path, board)
                    end

                    empty_count = count_empty(board)
                    empty_pct_real = real_empty_percentage(board)
                    total_cells = n * m

                    println("Résolution par $meth...")

                    result = try
                        solve_one_instance(board, meth)
                    catch e
                        println("Erreur pendant la résolution par $meth : ", e)
                        (
                            solution = nothing,
                            time_taken = -1.0,
                            is_optimal = false
                        )
                    end

                    solution_file = replace(instance_name, ".txt" => "_$(meth)_solution.txt")
                    solution_path = joinpath(SOL_DIR, meth, solution_file)
                    write_solution(solution_path, result)

                    push!(raw_rows, [
                        instance_name,
                        n,
                        m,
                        total_cells,
                        slabel,
                        empty_pct,
                        round(100 * empty_pct_real, digits = 2),
                        empty_count,
                        meth,
                        result.time_taken,
                        result.is_optimal,
                        solution_path
                    ])

                    println("  méthode = $meth")
                    println("  temps = $(round(result.time_taken, digits=3)) s")
                    println("  isOptimal = $(result.is_optimal)")
                    println()
                end
            end
        end
    end

    raw_path = joinpath(RES_DIR, "filling_stats_raw_$(method).csv")

    write_csv(
        raw_path,
        [
            "instance",
            "n",
            "m",
            "nb_cases",
            "taille",
            "pourcentage_vide_cible",
            "pourcentage_vide_reel",
            "nb_cases_vides",
            "methode",
            "temps",
            "isOptimal",
            "solution_path"
        ],
        raw_rows
    )

    println("Fichier brut écrit dans : $raw_path")

    write_summary_by_size(raw_rows, method)
    write_summary_by_empty_pct(raw_rows, method)
    write_summary_by_size_and_empty_pct(raw_rows, method)

    println()
    println("Expériences terminées.")
    println("Les CSV sont dans : $RES_DIR")
end



function write_summary_by_size(raw_rows::Vector{Vector}, method_name::String)
    groups = Dict{Tuple{String,String}, Vector{Vector}}()

    for row in raw_rows
        taille = row[5]
        method = row[9]
        key = (taille, method)

        if !haskey(groups, key)
            groups[key] = Vector{Vector}()
        end

        push!(groups[key], row)
    end

    summary_rows = Vector{Vector}()

    for ((taille, method), rows) in sort(collect(groups))
        times = [Float64(r[10]) for r in rows if Float64(r[10]) >= 0]
        solved = [Bool(r[11]) for r in rows]

        nb_instances = length(rows)
        nb_solved = count(solved)
        success_rate = 100 * nb_solved / nb_instances

        avg_time = isempty(times) ? -1.0 : mean(times)
        max_time = isempty(times) ? -1.0 : maximum(times)

        push!(summary_rows, [
            taille,
            method,
            nb_instances,
            nb_solved,
            round(success_rate, digits = 2),
            round(avg_time, digits = 4),
            round(max_time, digits = 4)
        ])
    end

    path = joinpath(RES_DIR, "filling_stats_by_size_$method_name.csv")

    write_csv(
        path,
        [
            "taille",
            "methode",
            "nb_instances",
            "nb_resolues",
            "taux_reussite",
            "temps_moyen",
            "temps_max"
        ],
        summary_rows
    )

    println("Résumé par taille écrit dans : $path")
end


function write_summary_by_empty_pct(raw_rows::Vector{Vector}, method_name::String)
    groups = Dict{Tuple{Float64,String}, Vector{Vector}}()

    for row in raw_rows
        empty_pct = Float64(row[6])
        method = row[9]
        key = (empty_pct, method)

        if !haskey(groups, key)
            groups[key] = Vector{Vector}()
        end

        push!(groups[key], row)
    end

    summary_rows = Vector{Vector}()

    for ((empty_pct, method), rows) in sort(collect(groups))
        times = [Float64(r[10]) for r in rows if Float64(r[10]) >= 0]
        solved = [Bool(r[11]) for r in rows]

        nb_instances = length(rows)
        nb_solved = count(solved)
        success_rate = 100 * nb_solved / nb_instances

        avg_time = isempty(times) ? -1.0 : mean(times)
        max_time = isempty(times) ? -1.0 : maximum(times)

        push!(summary_rows, [
            round(100 * empty_pct, digits = 2),
            method,
            nb_instances,
            nb_solved,
            round(success_rate, digits = 2),
            round(avg_time, digits = 4),
            round(max_time, digits = 4)
        ])
    end

    path = joinpath(RES_DIR, "filling_stats_by_empty_pct_$method_name.csv")

    write_csv(
        path,
        [
            "pourcentage_vide",
            "methode",
            "nb_instances",
            "nb_resolues",
            "taux_reussite",
            "temps_moyen",
            "temps_max"
        ],
        summary_rows
    )

    println("Résumé par pourcentage de cases vides écrit dans : $path")
end


function write_summary_by_size_and_empty_pct(raw_rows::Vector{Vector}, method_name::String)
    groups = Dict{Tuple{String,Float64,String}, Vector{Vector}}()

    for row in raw_rows
        taille = row[5]
        empty_pct = Float64(row[6])
        method = row[9]
        key = (taille, empty_pct, method)

        if !haskey(groups, key)
            groups[key] = Vector{Vector}()
        end

        push!(groups[key], row)
    end

    summary_rows = Vector{Vector}()

    for ((taille, empty_pct, method), rows) in sort(collect(groups))
        times = [Float64(r[10]) for r in rows if Float64(r[10]) >= 0]
        solved = [Bool(r[11]) for r in rows]

        nb_instances = length(rows)
        nb_solved = count(solved)
        success_rate = 100 * nb_solved / nb_instances

        avg_time = isempty(times) ? -1.0 : mean(times)
        max_time = isempty(times) ? -1.0 : maximum(times)

        push!(summary_rows, [
            taille,
            round(100 * empty_pct, digits = 2),
            method,
            nb_instances,
            nb_solved,
            round(success_rate, digits = 2),
            round(avg_time, digits = 4),
            round(max_time, digits = 4)
        ])
    end

    path = joinpath(RES_DIR, "filling_stats_by_size_and_empty_pct_$method_name.csv")

    write_csv(
        path,
        [
            "taille",
            "pourcentage_vide",
            "methode",
            "nb_instances",
            "nb_resolues",
            "taux_reussite",
            "temps_moyen",
            "temps_max"
        ],
        summary_rows
    )

    println("Résumé par taille et pourcentage de cases vides écrit dans : $path")
end

run_experiments("heuristic")