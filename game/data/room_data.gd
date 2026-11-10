class_name RoomData
extends Resource
## Définition d'une pièce : identité, ordre de progression, axes actifs.

## Axes de progression possibles d'une pièce.
enum Axis { CLEANING, REPAIR, STORING }

@export var id: StringName = &""
## Clé de traduction du nom affiché.
@export var name_key: String = ""
## Id de la pièce précédente (vide pour la première).
@export var previous_room_id: StringName = &""
## Axes actifs dans cette pièce.
@export var active_axes: Array[Axis] = []


## Renvoie la liste des erreurs de validation (vide si valide).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if id == &"":
		errors.append("id vide")
	if active_axes.is_empty():
		errors.append("aucun axe actif")
	return errors
