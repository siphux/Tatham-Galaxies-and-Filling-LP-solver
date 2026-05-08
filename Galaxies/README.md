# Projet Galaxies

Projet RO03 sur le jeu Galaxies.

Le but est de decouper une grille `n x n` en galaxies. Chaque galaxie doit :

- contenir exactement un centre ;
- etre symetrique par rapport a ce centre ;
- etre connexe avec les voisins haut, bas, gauche et droite.

## Etat du projet

Le projet est implemente pour les etapes principales du sujet :

- lecture robuste d'une instance ;
- affichage console d'une instance non resolue et resolue ;
- modele CPLEX avec contraintes d'affectation, de centre et de symetrie ;
- callback CPLEX avec contraintes lazy pour imposer la connexite ;
- verification de connexite hors modele ;
- test d'unicite d'une solution ;
- generation aleatoire d'instances, avec option `uniqueOnly = true` ;
- heuristique constructive ;
- resolution automatique du dossier `data` ;
- generation d'un tableau LaTeX de resultats ;
- generation optionnelle d'un diagramme de performance avec `Plots`.

Les jeux d'instances finaux, les tableaux de resultats et la partie Galaxies du
rapport sont prets. Le fichier `main.pdf` compile correctement.

## Fichiers importants

- `data/instanceTest.txt` : instance manuelle de test en `5 x 5`.
- `src/io.jl` : lecture, affichage, tableaux de resultats, diagrammes.
- `src/generation.jl` : generation d'instances.
- `src/resolution.jl` : solveur CPLEX, callback, connexite, heuristique,
  resolution de dossier.
- `res/generated/` : resultats finaux du lot genere.
- `res/internet_7x7/` : resultats finaux du lot internet `7 x 7`.
- `res/internet_10x10/` : resultats finaux du lot internet `10 x 10`.
- `res/final/results_table.tex` : tableau combine pret pour le rapport.

## Format d'une instance

```txt
n m
a1 b1
a2 b2
...
am bm
```

Exemple :

```txt
5 5
1.5 3.5
2 5
3 1.5
4 1
4 4
```

Les coordonnees des centres peuvent etre entieres ou demi-entieres.

## Charger le projet

Depuis la racine du projet :

```julia
include("./src/resolution.jl")
```

Ce fichier inclut aussi `generation.jl`, qui inclut lui-meme `io.jl`.

## Lire et afficher une instance

```julia
instance = readInputFile("./data/instanceTest.txt")
displayGrid(instance)
```

Avec les coordonnees des centres :

```julia
displayGrid(instance; showCoordinates = true)
```

## Resoudre avec CPLEX

```julia
instance = readInputFile("./data/instanceTest.txt")
n, m, centers = instance

isOptimal, solveTime, solution = cplexSolve(n, m, centers)

println(isOptimal)
println(solveTime)
displaySolution(instance, solution)
```

Le callback de connexite est active par defaut. Pour le desactiver :

```julia
cplexSolve(n, m, centers; useCallback = false)
```

Pour voir les coupes ajoutees par le callback :

```julia
cplexSolve(n, m, centers; verboseCallback = true)
```

## Verifier une solution

```julia
isConnectedSolution(n, m, solution)
firstDisconnectedGalaxy(n, m, solution)
isCompleteValidSolution(n, m, centers, solution)
```

`firstDisconnectedGalaxy` retourne `nothing` si toutes les galaxies sont
connexes.

## Tester l'unicite

```julia
isFeasible, isUnique, totalTime, solution = hasUniqueSolution(n, m, centers)
```

La fonction resout une premiere fois, puis relance CPLEX avec une contrainte qui
interdit la premiere solution. S'il n'existe pas de deuxieme solution, l'instance
est unique.

## Generer une instance

Instance aleatoire quelconque :

```julia
n, m, centers = generateInstance(5, 5)
```

Instance faisable :

```julia
n, m, centers = generateInstance(5, 5; feasibleOnly = true, maxTries = 100)
```

Instance avec solution unique, exemple rapide :

```julia
rng = Random.MersenneTwister(1)
n, m, centers = generateInstance(3, 2; uniqueOnly = true, maxTries = 100, rng = rng)
writeInstanceFile("./data/unique_3x3.txt", n, m, centers)
```

`uniqueOnly = true` est plus intelligent pour creer de vraies instances de jeu,
mais c'est plus lent car CPLEX doit prouver l'unicite. Sur des grilles plus
grandes, il faut souvent augmenter `maxTries`.

## Generer un dataset

```julia
generateDataSet(
    sizes = [(3, 2), (4, 3), (5, 4)],
    instancesPerSize = 2,
    uniqueOnly = true,
    maxTries = 300,
    cplexTimeLimit = 2.0
)
```

Chaque couple `(n, m)` signifie : grille `n x n` avec `m` centres.

## Heuristique

```julia
isSolved, solveTime, solution = heuristicSolve(n, m, centers; timeLimit = 5.0)
```

L'heuristique essaie de construire des galaxies connexes en ajoutant des paires
de cases symetriques. Elle n'est pas garantie, mais elle fonctionne sur
`instanceTest.txt`.

## Resoudre tout le dossier data

```julia
solveDataSet(
    resolutionMethods = ["cplex", "heuristic"],
    overwrite = true,
    cplexTimeLimit = 2.0,
    heuristicTimeLimit = 1.0
)
```

Les fichiers de resultats sont ecrits dans :

- `resFolder/cplex/`
- `resFolder/heuristic/`

Chaque fichier contient `solveTime`, `isOptimal`, l'instance et la solution.

Pour des experiences propres, on peut lancer une petite resolution avant le
dataset afin de reduire le cout de compilation Julia/CPLEX dans les temps
mesures :

```julia
warm = readInputFile("./data/random_unique_n3_m2_s01.txt")
cplexSolve(warm...; timeLimit = 2.0)
heuristicSolve(warm...; timeLimit = 1.0)
```

## Tableau de resultats

```julia
resultsArray("./res/results_table.tex"; resultFolder = "./res/final")
```

Cela cree un tableau LaTeX comparant les methodes presentes dans `res/final`.

## Diagramme de performance

Cette fonction necessite `Plots`.

Installation si besoin :

```julia
import Pkg
Pkg.add("Plots")
```

Puis :

```julia
performanceDiagram("./res/performance.pdf")
```

## Test rapide complet

```julia
include("./src/resolution.jl")

instance = readInputFile("./data/instanceTest.txt")
n, m, centers = instance

displayGrid(instance)

isOptimal, solveTime, solution = cplexSolve(n, m, centers)
println(isOptimal)
println(isConnectedSolution(n, m, solution))
println(isCompleteValidSolution(n, m, centers, solution))

displaySolution(instance, solution)

println(hasUniqueSolution(n, m, centers))

solveDataSet(
    resolutionMethods = ["cplex", "heuristic"],
    overwrite = true,
    cplexTimeLimit = 2.0,
    heuristicTimeLimit = 1.0
)
resultsArray("./res/results_table.tex"; resultFolder = "./res/final")
```

## Lot experimental actuel

Le dossier `data` contient actuellement :

- une instance manuelle `5 x 5` : `instanceTest.txt` ;
- 17 instances aleatoires dont l'unicite a ete prouvee avec CPLEX :
  `random_unique_*`, de `3 x 3` a `5 x 5`.
- 5 instances internet `7 x 7` dans `data/internet_7x7/`, relevees depuis
  images et verifiees faisables avec CPLEX.
- 5 instances internet `10 x 10` dans `data/internet_10x10/`, relevees depuis
  images et verifiees faisables avec CPLEX.

On a volontairement abandonne les instances construites par rectangles : elles
sont faisables par construction, mais moins naturelles pour un vrai jeu.

Les resultats du lot genere ont ete produits avec :

```julia
solveDataSet(
    dataFolder = "./data",
    resFolder = "./res/generated",
    resolutionMethods = ["cplex", "heuristic"],
    overwrite = true,
    cplexTimeLimit = 10.0,
    heuristicTimeLimit = 2.0
)

resultsArray("./res/generated/results_table.tex"; resultFolder = "./res/generated")
```

Les resultats du lot internet `10 x 10` ont ete produits avec :

```julia
solveDataSet(
    dataFolder = "./data/internet_10x10",
    resFolder = "./res/internet_10x10",
    resolutionMethods = ["cplex", "heuristic"],
    overwrite = true,
    cplexTimeLimit = 30.0,
    heuristicTimeLimit = 5.0
)

resultsArray("./res/internet_10x10/results_table.tex"; resultFolder = "./res/internet_10x10")
```

Les resultats du lot internet `7 x 7` ont ete produits avec :

```julia
solveDataSet(
    dataFolder = "./data/internet_7x7",
    resFolder = "./res/internet_7x7",
    resolutionMethods = ["cplex", "heuristic"],
    overwrite = true,
    cplexTimeLimit = 30.0,
    heuristicTimeLimit = 5.0
)

resultsArray("./res/internet_7x7/results_table.tex"; resultFolder = "./res/internet_7x7")
```

Les instances en `6 x 6` avec solution unique sont beaucoup plus rares avec la
generation aleatoire simple. Pour en trouver, il faut augmenter `maxTries`, le
nombre de graines testees, ou la limite de temps CPLEX par candidat.

Synthese des experiences :

```txt
res/experiment_summary.md
```

## Dependances

Necessaires :

- Julia ;
- JuMP ;
- CPLEX.

Optionnelle :

- Plots, uniquement pour `performanceDiagram`.
