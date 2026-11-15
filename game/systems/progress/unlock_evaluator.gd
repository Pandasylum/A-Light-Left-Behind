class_name UnlockEvaluator
extends RefCounted
## Évaluateur de la chaîne de déverrouillage (GDD §6). SEUL endroit de la règle ; sans état, sans scène.
## Une étape est complète quand toutes ses zones requises sont restaurées. Elle ne dépend que de ses
## zones, jamais des étapes précédentes : l'ordre de pose des verrous n'a aucune importance.
## Une étape sans zone requise n'est jamais complète. Identifiants inconnus et doublons ignorés.


## Résultat : étapes complètes (dans l'ordre de la chaîne) et accès ouverts (sans doublon).
class Result extends RefCounted:
	var completed_steps: Array[StringName] = []
	var open_accesses: Array[StringName] = []


## restored_zones : identifiants des zones dont le verrou « restaurée » est posé.
static func evaluate(chain: UnlockChain, restored_zones: Array) -> Result:
	var result: Result = Result.new()
	if chain == null:
		return result
	var restored: Dictionary = {}
	for zone: Variant in restored_zones:
		restored[StringName(str(zone))] = true
	for step: UnlockStep in chain.steps:
		if step == null or not is_step_complete(step, restored):
			continue
		result.completed_steps.append(step.id)
		for access: StringName in step.opens:
			if not result.open_accesses.has(access):
				result.open_accesses.append(access)
	return result


## restored : Dictionary dont les clés sont les zones restaurées.
static func is_step_complete(step: UnlockStep, restored: Dictionary) -> bool:
	if step.required_zones.is_empty():
		return false
	for zone: StringName in step.required_zones:
		if not restored.has(zone):
			return false
	return true
