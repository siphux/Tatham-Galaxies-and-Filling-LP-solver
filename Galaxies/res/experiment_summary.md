# Synthese des experiences

Derniere execution : 2026-05-08.

## Jeux d'instances

- `data/` : 18 instances utilisees pour le lot genere.
- `data/instanceTest.txt` : instance manuelle `5 x 5`.
- `data/random_unique_*.txt` : 17 instances aleatoires dont l'unicite a ete prouvee avec CPLEX.
- `data/internet_7x7/` : 5 instances `7 x 7` relevees depuis des images internet, avec coordonnees entieres et demi-entieres.
- `data/internet_10x10/` : 5 instances `10 x 10` relevees depuis des images internet, avec coordonnees entieres et demi-entieres.

Les images sources des instances internet sont dans :

```txt
data/internet_10x10/images/
data/internet_7x7/images/
```

## Commandes lancees

Lot genere :

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

Lot internet `10 x 10` :

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

Lot internet `7 x 7` :

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

## Resultats principaux

Lot genere :

- 18 instances.
- CPLEX resout 18/18 instances.
- L'heuristique resout 18/18 instances.
- Les temps sont tres faibles : ces instances sont utiles pour valider le code, mais peu discriminantes.

Lot internet `10 x 10` :

- 5 instances.
- CPLEX resout 5/5 instances.
- L'heuristique resout 1/5 instances.
- Les 5 instances sont prouvees uniques avec `hasUniqueSolution`.

Lot internet `7 x 7` :

- 5 instances.
- CPLEX resout 5/5 instances.
- L'heuristique resout 5/5 instances.
- Les 5 instances sont prouvees uniques avec `hasUniqueSolution`.

Interpretation :

- CPLEX est robuste sur tous les jeux testes.
- L'heuristique marche sur les petites instances generees et sur les instances internet `7 x 7`.
- Elle devient beaucoup moins fiable sur les vraies instances `10 x 10`.
- Les instances internet `10 x 10` sont les plus interessantes pour commenter la difference entre methode exacte et heuristique.

## Fichiers de resultats

- `res/generated/results_table.tex` : tableau du lot genere.
- `res/internet_7x7/results_table.tex` : tableau du lot internet `7 x 7`.
- `res/internet_10x10/results_table.tex` : tableau du lot internet.
- `res/internet_7x7/uniqueness_summary.txt` : verification d'unicite des instances internet `7 x 7`.
- `res/internet_10x10/uniqueness_summary.txt` : verification d'unicite des instances internet.
- `res/final/results_table.tex` : tableau combine des deux lots.
