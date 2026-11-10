class_name ItemData
extends Resource
## Définition d'un type d'objet du jeu (données seules, aucune logique de jeu).

## Catégorie de taille/rôle. FIXED : objet immobile (jamais rangeable).
enum Category { SMALL, MEDIUM, LARGE, FIXED }

## Identifiant stable de l'objet.
@export var id: StringName = &""
## Clé de traduction du nom affiché.
@export var name_key: String = ""
@export var category: Category = Category.SMALL
## Emprise au sol rectangulaire : largeur (x) et profondeur (y), en mètres.
@export var footprint: Vector2 = Vector2(0.3, 0.3)
## Hauteur de l'objet, en mètres (> 0).
@export var height: float = 0.3
## Orientations autorisées (identifiants). Vide = orientation unique.
@export var allowed_orientations: Array[StringName] = []
## Axes de progression suivis pour cet objet.
@export var tracks_cleaning: bool = false
@export var tracks_repair: bool = false
@export var tracks_storing: bool = false
## Meuble libre : l'objet porte une surface de pose déclarée (MEDIUM ou LARGE uniquement).
@export var provides_support: bool = false


## Renvoie la liste des erreurs de validation (vide si valide).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if id == &"":
		errors.append("id vide")
	if footprint.x <= 0.0 or footprint.y <= 0.0:
		errors.append("emprise non strictement positive")
	if height <= 0.0:
		errors.append("hauteur non strictement positive")
	if category == Category.FIXED and tracks_storing:
		errors.append("un objet FIXED ne suit pas l'axe rangement")
	if provides_support and category != Category.MEDIUM and category != Category.LARGE:
		errors.append("provides_support exige une catégorie MEDIUM ou LARGE")
	return errors
