using JuMP
using CPLEX


function cplexSolve(board::Matrix)
	Ti = time()
	model = Model(CPLEX.Optimizer)
	n, m = size(board)
	K = 9

	@variable(model, x[1:n, 1:m, 1:K], Bin)
	
	for i in 1:n
		for j in 1:m
			if board[i, j] != -1
				@constraint(model, x[i, j, board[i,j]] == 1)
			end
		end
	end

	@constraint(model, [i in 1:n, j in 1:m], sum(x[i, j, k] for k in 1:K) == 1)
	
	@objective(model, Min, 42)
	

	### on va parcourir le graphe, remplir chaque composante connexe. Dès que la composante connexe est complète on fait un test de taille et on applique une condition
	### si |C| < k: Alors il faut que somme des elements de la composante connexe - somme des elements valant k du bord soit <= à |C| - 1 (i.e. un element du bord doit être égal à k)
	### si |C| > k: Alors il faut juste interdire le fait que la somme des elements de la composante connexe soit plus grande ou égale à |C|, i.e. il faut que ce soit <= |C| - 1.
	function callback_fillomino(cb_data::CPLEX.CallbackContext, context_id::Clong) 
		if isIntegerPoint(cb_data, context_id)
			CPLEX.load_callback_variable_primal(cb_data, context_id)
			V = zeros(Int, n, m)
			for i in 1:n
                for j in 1:m
                    max_val = -1.0
                    best_k = 1
                    for k in 1:K
                        val = callback_value(cb_data, x[i, j, k])
                        if val > max_val
                            max_val = val
                            best_k = k
                        end
                    end
                    V[i, j] = best_k
                end
            end
			visited = falses(n, m)
			for i in 1:n
				for j in 1:m
					if !visited[i, j]
						k = V[i, j]
						C = Tuple{Int, Int}[]
						Q = [(i, j)]
						visited[i, j] = true

						while !isempty(Q)
							curr = popfirst!(Q)
							push!(C, curr)
							for (du, dv) in ((1, 0), (0, 1), (-1, 0), (0, -1))
								nu, nv = curr[1] + du, curr[2] + dv
								if 1 <= nu <= n && 1 <= nv <= m && !visited[nu, nv] && V[nu, nv] == k
									visited[nu, nv] = true
									push!(Q, (nu, nv))
								end
							end
						end
						
						size_C = length(C)

						if size_C > k
							cstr = @build_constraint(sum(x[u, v, k] for (u, v) in C) <= size_C - 1)
							MOI.submit(model, MOI.LazyConstraint(cb_data), cstr)
						elseif size_C < k
							B = Set{Tuple{Int,Int}}()
							for (u, v) in C
								for (du, dv) in ((1, 0), (0, 1), (-1, 0), (0, -1))
									nu, nv = u + du, v + dv
									if 1 <= nu <= n && 1 <= nv <= m && V[nu, nv] != k
										push!(B, (nu, nv))
									end
								end
							end

							cstr = @build_constraint(sum(x[u, v, k] for (u, v) in C) - sum(x[u, v, k] for (u, v) in B) <= size_C - 1)
							MOI.submit(model, MOI.LazyConstraint(cb_data), cstr)
						end
					end
				end
			end
		end
	end


	MOI.set(model, CPLEX.CallbackFunction(), callback_fillomino)
	MOI.set(model, MOI.NumberOfThreads(), 1)


	set_time_limit_sec(model, 60.0)
	optimize!(model)
	isOptimal = termination_status(model) == MOI.OPTIMAL
	solutionFound = primal_status(model) == MOI.FEASIBLE_POINT
	Tf = time() - Ti

	if solutionFound
		res = Matrix{Int}(undef, n, m)
        	for i in 1:n, j in 1:m, k in 1:K
            		if value(x[i,j,k]) > 0.5
                		res[i,j] = k
			end
		end
		return (solution = res, time_taken = Tf, sol_var = x, optimality = isOptimal)
	else
		println("solution not found")
		return (solution = nothing, time_taken = Tf, sol_var = x, optimality = false)
	end
end


function isIntegerPoint(cb_data::CPLEX.CallbackContext, context_id::Clong)

    # context_id  == CPX_CALLBACKCONTEXT_CANDIDATE si le  callback est
    # appelé dans un des deux cas suivants :
    # cas 1 - une solution entière a été obtenue; ou
    # cas 2 - une relaxation non bornée a été obtenue
    if context_id != CPX_CALLBACKCONTEXT_CANDIDATE
        return false
    end

    # Pour déterminer si on est dans le cas 1 ou 2, on essaie de récupérer la
    # solution entière courante
    ispoint_p = Ref{Cint}()
    ret = CPXcallbackcandidateispoint(cb_data, ispoint_p)

    # S'il n'y a pas de solution entière
    if ret != 0 || ispoint_p[] == 0
        return false
    else
        return true
    end
end


include("./io.jl")

function solveDataSet(data_paths::Vector{String})
	dossier = "./res"
	i = 1
	for path in data_paths
		board = readInputFile(path)
		res = cplexSolve(board)
    
		if !isdir(dossier)
			mkdir(dossier)
		end
		
		chemin_fichier = joinpath(dossier, "resolution_$i.txt")
		open(chemin_fichier, "w") do f
			write(f, "Solved instance path : $path\n")
            write(f, "solveTime : $(res.time_taken)\n")
            write(f, "isOptimal : $(res.optimality)\n")

			for l in 1:size(res.solution)[1]
                ligne_str = join(res.solution[l, :], ",")
                write(f, "$ligne_str\n")
			end

		end
		
		i = i + 1

	end

	println("Résolution du dataset termine")
end