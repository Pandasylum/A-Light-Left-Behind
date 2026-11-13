class_name ProgressSave
extends RefCounted
## Section « progression » d'une sauvegarde (clé SAVE_KEY des données du SaveService, à côté de
## « nettoyage », « outils » et « disposition ») : verrou « restaurée » par pièce, {id de pièce :
## restaurée}. Les compteurs ne sont jamais sauvegardés : ils sont recalculés. Logique pure.
## Section absente ({}) = aucune pièce restaurée. Le fichier n'est pas fiable : section illisible ou
## version inconnue = rejetée en entier (aucune pièce restaurée).

const SAVE_KEY: String = "progression"
const SAVE_VERSION: int = 1
const ROOMS_KEY: String = "pieces"


## Résultat de la lecture d'une section.
class Plan extends RefCounted:
	## Faux = toute la section est ignorée (voir error).
	var accepted: bool = true
	var error: String = ""
	## Ids des pièces restaurées (valeur toujours true).
	var restored: Dictionary = {}


## Écrit la section : restored_rooms = {id de pièce : bool} ; seules les pièces restaurées sont écrites.
static func make_section(restored_rooms: Dictionary) -> Dictionary:
	var rooms: Dictionary = {}
	for id: Variant in restored_rooms:
		if restored_rooms[id] == true:
			rooms[String(id)] = true
	return {"version": SAVE_VERSION, ROOMS_KEY: rooms}


## Lit une section (Variant : le fichier n'est pas fiable). {} = absente = rien de restauré.
static func parse(section: Variant) -> Plan:
	var plan: Plan = Plan.new()
	if not (section is Dictionary):
		return _reject(plan, "section illisible")
	var content: Dictionary = section
	if content.is_empty():
		return plan
	var version: Variant = content.get("version")
	if not (version is int or version is float) or is_nan(float(version)) or float(version) != floorf(float(version)):
		return _reject(plan, "version absente ou illisible")
	if int(version) < 1 or int(version) > SAVE_VERSION:
		return _reject(plan, "version %d inconnue" % int(version))
	if not (content.get(ROOMS_KEY) is Dictionary):
		return _reject(plan, "liste « %s » absente ou illisible" % ROOMS_KEY)
	var rooms: Dictionary = content[ROOMS_KEY]
	for id: Variant in rooms:
		if not (id is String) or (id as String).is_empty() or not (rooms[id] is bool):
			return _reject(plan, "entrée de pièce illisible")
		if rooms[id] == true:
			plan.restored[id] = true
	return plan


static func _reject(plan: Plan, error: String) -> Plan:
	plan.accepted = false
	plan.error = error
	plan.restored.clear()
	return plan
