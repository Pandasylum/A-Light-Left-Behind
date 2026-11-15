class_name UnlockStep
extends Resource
## Une étape de la chaîne de déverrouillage (GDD §6). Données seules : la règle vit dans UnlockEvaluator.

## Identifiant stable de l'étape.
@export var id: StringName = &""
## Identifiants des zones requises (= identifiants de RoomData ; la tour et « archives + bureau » sont une zone chacune).
@export var required_zones: Array[StringName] = []
## Identifiants des verrous d'accès que l'étape ouvre (🟡 provisoires, sauf ceux qui sont l'identifiant d'une zone).
@export var opens: Array[StringName] = []


## Renvoie la liste des erreurs de validation (vide si valide).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if id == &"":
		errors.append("id vide")
	if required_zones.is_empty():
		errors.append("aucune zone requise")
	if opens.is_empty():
		errors.append("aucun accès ouvert")
	return errors
