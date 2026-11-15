class_name WallZoneRules
extends Resource
## Réglages de découpe des zones murales « accroché » (Direction 2026-11-15, option A, provisoire).
## Les valeurs par défaut sont PROVISOIRES (voir TECHNICAL.md) : aucune n'est lue ailleurs qu'ici.

## Plage de hauteur de la zone, en mètres au-dessus du sol (bas, haut).
@export var height_min: float = 0.90
@export var height_max: float = 2.00
## Marge autour de chaque retrait (étagère murale, porte, ouverture, face à nettoyer), en mètres, de chaque côté.
@export var cut_margin: float = 0.05
## Demi-largeur du retrait d'une porte (±0,60 m autour de son repère), en mètres.
@export var door_half_width: float = 0.60
## Un retrait ou une face à nettoyer se rattache à un mur s'il en est à cette distance ou moins (le long de la normale), en mètres.
@export var cut_reach: float = 0.30
## Épaisseur du volume d'une zone, centré sur le plan du mur (même convention que l'ancienne zone du tableau), en mètres.
@export var thickness: float = 0.10


## Hauteur de la zone (plan), en mètres.
func height_span() -> float:
	return height_max - height_min


## Renvoie la liste des erreurs de validation (vide si valide).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if height_min < 0.0:
		errors.append("hauteur minimale négative")
	if height_max <= height_min:
		errors.append("hauteur maximale pas au-dessus de la hauteur minimale")
	if cut_margin < 0.0:
		errors.append("marge de retrait négative")
	if door_half_width <= 0.0:
		errors.append("demi-largeur de porte non strictement positive")
	if cut_reach < 0.0:
		errors.append("portée de rattachement négative")
	if thickness <= 0.0:
		errors.append("épaisseur de zone non strictement positive")
	return errors
