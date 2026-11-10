class_name ZoneData
extends Resource
## Règles d'une zone de rangement (volume Area3D placé dans la scène de pièce).
## Les règles vivent ici ; le volume vit dans la scène.

## Identifiant stable de la zone.
@export var id: StringName = &""
## Catégories d'objets acceptées (FIXED jamais accepté).
@export var accepted_categories: Array[ItemData.Category] = []


## Renvoie la liste des erreurs de validation (vide si valide).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if id == &"":
		errors.append("id vide")
	if accepted_categories.is_empty():
		errors.append("liste de catégories vide")
	if accepted_categories.has(ItemData.Category.FIXED):
		errors.append("la catégorie FIXED ne peut pas être acceptée")
	return errors
