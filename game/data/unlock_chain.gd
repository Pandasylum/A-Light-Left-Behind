class_name UnlockChain
extends Resource
## Les étapes de la chaîne de déverrouillage, dans l'ordre (GDD §6). Données seules.

@export var steps: Array[UnlockStep] = []


## Renvoie la liste des erreurs de validation (vide si valide).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for step: UnlockStep in steps:
		if step == null:
			errors.append("étape nulle")
			continue
		for e: String in step.validate():
			errors.append("%s : %s" % [step.id, e])
		if seen.has(step.id):
			errors.append("id d'étape en double : %s" % step.id)
		seen[step.id] = true
	return errors
