class_name ToolData
extends Resource
## Définition statique d'un outil de nettoyage. Aucune logique de jeu ici.
## L'état d'usage (salissure) vit dans ToolState, jamais dans cette ressource.
## TOUTES les valeurs sont PROVISOIRES, à régler en playtest.

const LAYER_DIRT: int = 0b01 ## couche saleté (R du masque d'état)
const LAYER_MOSS: int = 0b10 ## couche mousse (G du masque d'état)
const ALL_LAYERS: int = LAYER_DIRT | LAYER_MOSS
## Borne de max_efficiency_loss : garantit le plancher de 10 % d'efficacité.
const MAX_LOSS_LIMIT: float = 0.9

@export var id: StringName = &""
@export var name_key: String = ""
## Couches nettoyées (masque de bits transmis tel quel à CleanableFace.clean_stroke).
@export_flags("Saleté:1", "Mousse:2") var layers: int = ALL_LAYERS
## Rayon du geste, en mètres.
@export var radius_m: float = 0.08
## Efficacité de base : dose de nettoyage par seconde, outil propre.
@export var base_efficiency: float = 4.0
## Perte d'efficacité maximale, outil entièrement sale, dans [0, MAX_LOSS_LIMIT].
@export_range(0.0, 0.9, 0.01) var max_efficiency_loss: float = 0.9
## Salissure gagnée (0..1) par m² nettoyé.
@export var soil_per_m2: float = 0.5
## Portée du geste depuis la caméra, en mètres.
@export var reach_m: float = 2.0


## Renvoie la liste des erreurs de cohérence (vide si la ressource est valide).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if id == &"":
		errors.append("id vide")
	if layers == 0 or (layers & ~ALL_LAYERS) != 0:
		errors.append("couches nettoyées : au moins une, parmi saleté et mousse")
	if radius_m <= 0.0:
		errors.append("rayon du geste non strictement positif")
	if base_efficiency <= 0.0:
		errors.append("efficacité de base non strictement positive")
	if max_efficiency_loss < 0.0 or max_efficiency_loss > MAX_LOSS_LIMIT:
		errors.append("perte d'efficacité maximale hors de [0, %.1f]" % MAX_LOSS_LIMIT)
	if soil_per_m2 < 0.0:
		errors.append("vitesse de salissure négative")
	if reach_m <= 0.0:
		errors.append("portée non strictement positive")
	return errors
