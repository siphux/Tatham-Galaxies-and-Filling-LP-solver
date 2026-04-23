function readInputFile(path::String)
	if isfile(path)
		myFile = open(path)
		data = readlines(myFile)
		n, m = parse(Int, data[1]), parse(Int, data[2])
		res = Matrix{Int}(undef, n, m)
		i = 1
		for line in data[3:end]
			t = parse.(Int, split(line, ","))
			res[i, :] = t
			i += 1
		end
		close(myFile)
		return res
	end
	return -1
end





# function displayGrid(grid::Matrix{Int})
# 	n, m = size(grid)
# 	for i in 1:n
# 		for j in 1:m
			


# end


function displayGrid(board::Matrix{Int})
    n, m = size(board)
    println("Problème initial :")
    
    println("+" * "---+" ^ m)

    for i in 1:n
        print("|")
        for j in 1:m
            val = board[i, j]
            print(val == -1 ? " . " : rpad(" $(val)", 3))
            if j < m
                if board[i, j] != -1 && board[i, j+1] != -1 && board[i, j] != board[i, j+1]
                    print("|")
                else
                    print(" ")
                end
            end
        end
        println("|")
        if i < n
            print("|")
            for j in 1:m
                if board[i, j] != -1 && board[i+1, j] != -1 && board[i, j] != board[i+1, j]
                    print("---")
                else
                    print("   ")
                end
                if j < m
                    v_connu = (board[i,j] != -1 && board[i,j+1] != -1 && board[i,j] != board[i,j+1]) ||
                              (board[i+1,j] != -1 && board[i+1,j+1] != -1 && board[i+1,j] != board[i+1,j+1])
                    h_connu = (board[i,j] != -1 && board[i+1,j] != -1 && board[i,j] != board[i+1,j]) ||
                              (board[i,j+1] != -1 && board[i+1,j+1] != -1 && board[i,j+1] != board[i+1,j+1])
                    
                    print((v_connu || h_connu) ? "+" : " ")
                end
            end
            println("|")
        end
    end
    println("+" * "---+" ^ m)
end


function displaySolution(solution::Matrix{Int})
    n, m = size(solution)
    println("Solution trouvée par CPlex :")
    println("+" * "---+" ^ m)

    for i in 1:n
        print("|")
        for j in 1:m
            print(rpad(" $(solution[i,j])", 3))
            if j < m
                print(solution[i, j] != solution[i, j+1] ? "|" : " ")
            end
        end
        println("|")

        if i < n
            print("|")
            for j in 1:m
                print(solution[i, j] != solution[i+1, j] ? "---" : "   ")
                if j < m
                    h1 = solution[i, j] != solution[i+1, j]
                    h2 = solution[i, j+1] != solution[i+1, j+1]
                    v1 = solution[i, j] != solution[i, j+1]
                    v2 = solution[i+1, j] != solution[i+1, j+1]
                    print((h1 || h2 || v1 || v2) ? "+" : " ")
                end
            end
            println("|")
        end
    end
    println("+" * "---+" ^ m)
end