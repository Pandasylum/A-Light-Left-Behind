class_name LayoutState
extends RefCounted
## Section « disposition » d'une sauvegarde (clé SAVE_KEY des données du SaveService, à côté de
## « nettoyage » et « outils ») : objets libres posés dans la pièce. Logique pure, sans scène :
## la pièce est décrite par deux dictionnaires (objets connus, supports connus).
## Le fichier n'est pas fiable : une entrée douteuse est ignorée seule (l'objet garde sa place
## initiale), une section illisible est rejetée en entier (disposition initiale, portage vide).

const SAVE_KEY: String = "disposition"
const SAVE_VERSION: int = 1
const OBJECTS_KEY: String = "objets"
const CARRY_KEY: String = "portage"
const HELD_KEY: String = "main"
const BELT_KEY: String = "ceinture"
## Support d'un objet posé sur le sol de la pièce (les autres supports : identifiant de la surface).
const FLOOR_ID: String = "sol"
## Seule posture tant que le lot de posture n'existe pas ; le champ est écrit et relu.
const POSTURE_FLAT: String = "a_plat"


## Résultat de la lecture d'une section : ce qu'il faut restaurer.
class Plan extends RefCounted:
	## Faux = toute la section est ignorée (voir error) : disposition initiale, portage vide.
	var accepted: bool = true
	var error: String = ""
	## Une ligne par entrée ignorée seule.
	var warnings: Array[String] = []
	## Objets à replacer, dans l'ordre sauvegardé (ordre des charges de chaque porteur) :
	## id, position (Vector3), angle, posture, support, furniture.
	var placements: Array[Dictionary] = []

	## Ordre de mise en place : meubles libres d'abord, puis les autres objets.
	func positioning_order() -> Array[Dictionary]:
		var furniture: Array[Dictionary] = []
		var others: Array[Dictionary] = []
		for placement: Dictionary in placements:
			if placement["furniture"]:
				furniture.append(placement)
			else:
				others.append(placement)
		return furniture + others


## Description d'un objet de la pièce pour parse() : meuble libre (provides_support) et catégorie.
static func describe_item(furniture: bool, category: int) -> Dictionary:
	return {"furniture": furniture, "category": category}


## Entrée d'un objet posé : position absolue dans la pièce, angle autour de la verticale (rad).
static func make_entry(id: String, position: Vector3, angle: float, support: String,
		posture: String = POSTURE_FLAT) -> Dictionary:
	return {"id": id, "position": [position.x, position.y, position.z], "angle": angle,
			"posture": posture, "support": support}


## Section complète à partir des entrées des objets posés.
static func make_section(objects: Array[Dictionary]) -> Dictionary:
	return {"version": SAVE_VERSION, OBJECTS_KEY: objects, CARRY_KEY: {HELD_KEY: "", BELT_KEY: []}}


## Lit une section. items : identifiant -> describe_item() des objets libres de la pièce.
## supports : identifiant de support -> identifiant de l'objet qui le porte ("" = support fixe ou sol).
## {} (ancien format, section absente) = rien à restaurer, sans avertissement.
static func parse(section: Variant, items: Dictionary, supports: Dictionary) -> Plan:
	var plan: Plan = Plan.new()
	if not (section is Dictionary):
		return _reject(plan, "section illisible")
	var content: Dictionary = section
	if content.is_empty():
		return plan
	var error: String = _read(content, items, supports, plan)
	return plan if error.is_empty() else _reject(plan, error)


static func _reject(plan: Plan, error: String) -> Plan:
	plan.accepted = false
	plan.error = error
	plan.warnings.clear()
	plan.placements.clear()
	return plan


## Remplit le plan ; renvoie le motif de rejet de toute la section ("" = acceptée).
static func _read(content: Dictionary, items: Dictionary, supports: Dictionary, plan: Plan) -> String:
	if not _is_number(content.get("version")):
		return "version absente ou illisible"
	var version: int = int(content["version"]) # les nombres reviennent en flottants du JSON
	if version < 1 or version > SAVE_VERSION:
		return "version %d inconnue" % version
	if not (content.get(OBJECTS_KEY) is Array):
		return "liste « %s » absente ou illisible" % OBJECTS_KEY
	var seen: Dictionary = {}
	var candidates: Array[Dictionary] = []
	for raw: Variant in content[OBJECTS_KEY]:
		if not (raw is Dictionary) or not (raw.get("id") is String) or (raw["id"] as String).is_empty():
			return "entrée sans identifiant"
		var id: String = raw["id"]
		if seen.has(id):
			return "identifiant « %s » en double" % id
		seen[id] = true
		var problem: String = _entry_problem(raw, items, supports)
		if not problem.is_empty():
			plan.warnings.append("objet « %s » ignoré (%s)" % [id, problem])
			continue
		var position: Array = raw["position"]
		candidates.append({"id": id, "position": Vector3(position[0], position[1], position[2]),
				"angle": float(raw["angle"]), "posture": raw["posture"], "support": raw["support"],
				"furniture": bool((items[id] as Dictionary).get("furniture", false))})
	plan.placements = _grounded(candidates, supports, plan.warnings)
	return ""


## Motif pour ignorer cette entrée seule ("" = entrée valable).
static func _entry_problem(raw: Dictionary, items: Dictionary, supports: Dictionary) -> String:
	if not items.has(raw["id"]):
		return "objet inconnu dans la pièce"
	var position: Variant = raw.get("position")
	if not (position is Array) or (position as Array).size() != 3:
		return "position illisible"
	for value: Variant in position:
		if not _is_number(value) or not is_finite(value):
			return "position non finie"
	if not _is_number(raw.get("angle")) or not is_finite(raw["angle"]):
		return "angle non fini"
	if not (raw.get("posture") is String):
		return "posture illisible"
	if not (raw.get("support") is String) or not supports.has(raw["support"]):
		return "support introuvable"
	return ""


## Garde les objets dont le support est réellement en place : support fixe ou sol, ou dessus d'un
## objet lui-même gardé. Écarte ainsi l'objet posé sur un objet ignoré, et toute boucle de supports.
static func _grounded(candidates: Array[Dictionary], supports: Dictionary, warnings: Array[String]) -> Array[Dictionary]:
	var grounded: Dictionary = {}
	var progress: bool = true
	while progress:
		progress = false
		for candidate: Dictionary in candidates:
			if grounded.has(candidate["id"]):
				continue
			var carrier: String = supports[candidate["support"]]
			if carrier.is_empty() or grounded.has(carrier):
				grounded[candidate["id"]] = true
				progress = true
	var kept: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		if grounded.has(candidate["id"]):
			kept.append(candidate)
		else:
			warnings.append("objet « %s » ignoré (support introuvable : son porteur n'est pas en place)" % candidate["id"])
	return kept


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
