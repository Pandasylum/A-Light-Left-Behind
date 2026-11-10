class_name PlacementRules
extends Resource
## Règles générales de placement des objets.
## Les valeurs par défaut sont PROVISOIRES.

## Pas de rotation en degrés. Valeur de conception ouverte, ne pas figer.
@export var rotation_step_degrees: float = 15.0
## Marge au bord du support, en mètres. Valeur de conception ouverte, ne pas figer.
@export var edge_margin: float = 0.02
## Couverture minimale du support, dans ]0, 1]. Valeur de conception ouverte, ne pas figer.
@export var min_support_coverage: float = 0.6


## Renvoie la liste des erreurs de validation (vide si valide).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if rotation_step_degrees <= 0.0 or not is_zero_approx(fposmod(360.0, rotation_step_degrees)):
		errors.append("le pas de rotation doit être positif et diviser 360")
	if edge_margin < 0.0:
		errors.append("marge au bord négative")
	if min_support_coverage <= 0.0 or min_support_coverage > 1.0:
		errors.append("couverture minimale hors de ]0, 1]")
	return errors
