include("resolution.jl")

using Random

function generateInstance(nb_lignes::Int, nb_colonnes::Int, pourcentage_vide::Float64)
    grille_initiale = fill(-1, nb_lignes, nb_colonnes)
    
    nb_graines = max(1, round(Int, (nb_lignes * nb_colonnes) * 0.05))
    cases_dispo = randperm(nb_lignes * nb_colonnes)
    
    graines_placees = 0
    for idx in cases_dispo
        if graines_placees >= nb_graines
            break
        end
        
        i = (idx - 1) % nb_lignes + 1
        j = (idx - 1) ÷ nb_lignes + 1
        
        safe = true
        for (di, dj) in ((1, 0), (-1, 0), (0, 1), (0, -1))
            ni, nj = i + di, j + dj
            if 1 <= ni <= nb_lignes && 1 <= nj <= nb_colonnes
                if grille_initiale[ni, nj] == 1
                    safe = false
                    break
                end
            end
        end
        
        if safe
            grille_initiale[i, j] = 1
            graines_placees += 1
        end
    end

    resultat = cplexSolve(grille_initiale)
    if resultat.solution === nothing
        println("Graines bloquantes, fallback sur une grille vide.")
        grille_initiale = fill(-1, nb_lignes, nb_colonnes)
        resultat = cplexSolve(grille_initiale)
    end
    
    grille_resolue = resultat.solution
    instance_generee = copy(grille_resolue)

    nb_cases_a_vider = round(Int, nb_lignes * nb_colonnes * pourcentage_vide)
    indices_a_vider = randperm(nb_lignes * nb_colonnes)[1:nb_cases_a_vider]
    
    for idx in indices_a_vider
        instance_generee[idx] = -1
    end
    
    return instance_generee
end


function generateDataSet(nb_instances::Int)
    dossier = "./data"
    
    if !isdir(dossier)
        mkdir(dossier)
    end
    
    for i in 1:nb_instances
        lignes = rand(5:12)
        colonnes = rand(5:12)
        pct_vide = rand(0.5:0.9)
        
        println("Génération de l'instance $i ($lignes x $colonnes, $(round(pct_vide*100))% vide)...")
        grille = generateInstance(lignes, colonnes, pct_vide)
        chemin_fichier = joinpath(dossier, "instance_$i.txt")
        open(chemin_fichier, "w") do f
            write(f, "$lignes\n")
            write(f, "$colonnes\n")
            
            for l in 1:lignes
                ligne_str = join(grille[l, :], ",")
                write(f, "$ligne_str\n")
            end
        end
    end
    
    println("Génération terminée. Il y a $nb_instances fichiers créés dans $dossier.")
end