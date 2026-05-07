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
	else
        print("Chemin introuvable\n")
        return -1
    end
	
end




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










"""
Create a latex file which contains an array with the results of the ./res folder.
Each subfolder of the ./res folder contains the results of a resolution method.

Arguments
- outputFile: path of the output file

Prerequisites:
- Each subfolder must contain text files
- Each text file correspond to the resolution of one instance
- Each text file contains a variable "solveTime" and a variable "isOptimal"
"""
function resultsArray(outputFile::String)
    
    resultFolder = "./res/"
    dataFolder = "./data/"
    
    # Maximal number of files in a subfolder
    maxSize = 0

    # Number of subfolders
    subfolderCount = 0

    # Open the latex output file
    fout = open(outputFile, "w")

    # Print the latex file output
    println(fout, raw"""\documentclass{article}

\usepackage[french]{babel}
\usepackage [utf8] {inputenc} % utf-8 / latin1 
\usepackage{multicol}

\setlength{\hoffset}{-18pt}
\setlength{\oddsidemargin}{0pt} % Marge gauche sur pages impaires
\setlength{\evensidemargin}{9pt} % Marge gauche sur pages paires
\setlength{\marginparwidth}{54pt} % Largeur de note dans la marge
\setlength{\textwidth}{481pt} % Largeur de la zone de texte (17cm)
\setlength{\voffset}{-18pt} % Bon pour DOS
\setlength{\marginparsep}{7pt} % Séparation de la marge
\setlength{\topmargin}{0pt} % Pas de marge en haut
\setlength{\headheight}{13pt} % Haut de page
\setlength{\headsep}{10pt} % Entre le haut de page et le texte
\setlength{\footskip}{27pt} % Bas de page + séparation
\setlength{\textheight}{668pt} % Hauteur de la zone de texte (25cm)

\begin{document}""")

    header = raw"""
\begin{center}
\renewcommand{\arraystretch}{1.4} 
 \begin{tabular}{l"""

    # Name of the subfolder of the result folder (i.e, the resolution methods used)
    folderName = Array{String, 1}()

    # List of all the instances solved by at least one resolution method
    solvedInstances = Array{String, 1}()

    # For each file in the result folder
    for file in readdir(resultFolder)

        path = resultFolder * file
        
        # If it is a subfolder
        if isdir(path)

            # Add its name to the folder list
            folderName = vcat(folderName, file)
             
            subfolderCount += 1
            folderSize = size(readdir(path), 1)

            # Add all its files in the solvedInstances array
            for file2 in filter(x->occursin(".txt", x), readdir(path))
                solvedInstances = vcat(solvedInstances, file2)
            end 

            if maxSize < folderSize
                maxSize = folderSize
            end
        end
    end

    # Only keep one string for each instance solved
    unique!(solvedInstances)

    # For each resolution method, add two columns in the array
    for folder in folderName
        header *= "rr"
    end

    header *= "}\n\t\\hline\n"

    # Create the header line which contains the methods name
    for folder in folderName
        header *= " & \\multicolumn{2}{c}{\\textbf{" * folder * "}}"
    end

    header *= "\\\\\n\\textbf{Instance} "

    # Create the second header line with the content of the result columns
    for folder in folderName
        header *= " & \\textbf{Temps (s)} & \\textbf{Optimal ?} "
    end

    header *= "\\\\\\hline\n"

    footer = raw"""\hline\end{tabular}
\end{center}

"""
    println(fout, header)

    # On each page an array will contain at most maxInstancePerPage lines with results
    maxInstancePerPage = 30
    id = 1

    # For each solved files
    for solvedInstance in solvedInstances

        # If we do not start a new array on a new page
        if rem(id, maxInstancePerPage) == 0
            println(fout, footer, "\\newpage")
            println(fout, header)
        end 

        # Replace the potential underscores '_' in file names
        print(fout, replace(solvedInstance, "_" => "\\_"))

        # For each resolution method
        for method in folderName

            path = resultFolder * method * "/" * solvedInstance

            # If the instance has been solved by this method
            if isfile(path)

                include(path)

                println(fout, " & ", round(Main.solveTime, digits=2), " & ")

                if Main.isOptimal
                    println(fout, "\$\\times\$")
                end 
                
            # If the instance has not been solved by this method
            else
                println(fout, " & - & - ")
            end
        end

        println(fout, "\\\\")

        id += 1
    end

    # Print the end of the latex file
    println(fout, footer)

    println(fout, "\\end{document}")

    close(fout)
    
end