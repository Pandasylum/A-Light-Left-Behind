class_name ToolSlots
extends RefCounted
## Emplacements dédiés des outils du joueur (logique pure, hors ItemData et hors ceinture) : un
## emplacement par outil, au plus un outil en main, aucun par défaut. L'état d'usage (salissure)
## reste attaché à l'emplacement quand l'outil est rangé.

## Émis quand l'outil en main change (sorti ou rangé).
signal held_changed

const NONE: int = -1
## Clé de la section des outils dans les données d'une sauvegarde (à côté de « nettoyage »).
const SAVE_KEY: String = "outils"
## Version du format de la section « outils ».
const SAVE_VERSION: int = 1

## Emplacement de l'outil en main (NONE = aucun) ; lecture seule hors de cette classe.
var held_index: int = NONE
## Emplacement sorti par toggle(). La sélection parmi plusieurs outils n'est pas implémentée :
## elle reviendra à changer cet index.
var selected_index: int = 0

var _slots: Array[ToolState] = []


## Ajoute un emplacement pour cet outil (rangé, propre) et renvoie son index. Un outil déjà
## présent garde son emplacement. NONE si tool_data est null.
func add_tool(tool_data: ToolData) -> int:
	if tool_data == null:
		return NONE
	for index: int in _slots.size():
		if _slots[index].data == tool_data:
			return index
	_slots.append(ToolState.new(tool_data))
	return _slots.size() - 1


func count() -> int:
	return _slots.size()


## État de l'outil de l'emplacement (null hors bornes).
func state_at(index: int) -> ToolState:
	return _slots[index] if index >= 0 and index < _slots.size() else null


## État de l'outil en main (null si aucun).
func held() -> ToolState:
	return state_at(held_index)


## Sort l'outil de l'emplacement et le place en main (l'outil déjà en main retourne dans le sien).
## Renvoie false si l'emplacement n'existe pas.
func take_out(index: int) -> bool:
	if state_at(index) == null:
		return false
	if index != held_index:
		held_index = index
		held_changed.emit()
	return true


## Range l'outil en main dans son emplacement. Renvoie false si aucun outil n'était en main.
func stow() -> bool:
	if held_index == NONE:
		return false
	held_index = NONE
	held_changed.emit()
	return true


## Bascule : range l'outil en main, sinon sort l'outil sélectionné. Renvoie false sans effet.
func toggle() -> bool:
	return stow() if held_index != NONE else take_out(selected_index)


## Retire tous les emplacements (outil en main rangé d'abord).
func clear() -> void:
	stow()
	_slots.clear()


# --- Sauvegarde ---

## Section « outils » pour le SaveService : version du format + une entrée par emplacement
## (identifiant ToolData, emplacement, salissure, en main ou rangé). Lecture seule.
func export_state() -> Dictionary:
	var entries: Array[Dictionary] = []
	for index: int in _slots.size():
		entries.append({
			"id": String(_slots[index].data.id),
			"emplacement": index,
			"salissure": _slots[index].soil,
			"en_main": index == held_index,
		})
	return {"version": SAVE_VERSION, "emplacements": entries}


## Restaure les emplacements à l'identique, sans rinçage ni salissure. catalog = outils connus,
## pour retrouver un ToolData par son identifiant. {} (section absente, ancien format) = aucun
## outil. Le fichier n'est pas fiable : toute incohérence = aucun outil + push_warning (false).
func import_state(section: Dictionary, catalog: Array[ToolData]) -> bool:
	var was_held: bool = held_index != NONE
	held_index = NONE
	_slots.clear()
	var error: String = "" if section.is_empty() else _restore(section, catalog)
	if error != "":
		held_index = NONE
		_slots.clear()
		push_warning("ToolSlots : section « %s » rejetée (%s), aucun outil" % [SAVE_KEY, error])
	if was_held or held_index != NONE:
		held_changed.emit()
	return error == ""


## Remplit _slots et held_index depuis la section ; renvoie "" ou le motif du rejet.
func _restore(section: Dictionary, catalog: Array[ToolData]) -> String:
	var version: int = _as_index(section.get("version"))
	if version < 1 or version > SAVE_VERSION:
		return "version de format inconnue"
	if not section.get("emplacements") is Array:
		return "liste des emplacements absente"
	var entries: Array = section["emplacements"]
	var known: Dictionary = {}
	for tool_data: ToolData in catalog:
		if tool_data != null:
			known[String(tool_data.id)] = tool_data
	_slots.resize(entries.size())
	for item: Variant in entries:
		if not item is Dictionary:
			return "entrée invalide"
		var entry: Dictionary = item
		var index: int = _as_index(entry.get("emplacement"))
		var soil: Variant = entry.get("salissure")
		if not entry.get("id") is String or not (soil is float or soil is int) or not entry.get("en_main") is bool:
			return "entrée incomplète"
		if index == NONE or index >= _slots.size() or _slots[index] != null:
			return "emplacement hors bornes ou en double"
		if not known.has(entry["id"]):
			return "outil inconnu ou en double « %s »" % entry["id"]
		if is_nan(float(soil)) or float(soil) < 0.0 or float(soil) > 1.0:
			return "salissure hors de [0, 1]"
		var state: ToolState = ToolState.new(known[entry["id"]] as ToolData)
		known.erase(entry["id"]) # un seul emplacement par outil
		state.restore_soil(float(soil))
		_slots[index] = state
		if entry["en_main"]:
			if held_index != NONE:
				return "plusieurs outils en main"
			held_index = index
	return ""


## Entier positif ou nul porté par un nombre JSON (toujours flottant après lecture) ; NONE sinon.
static func _as_index(value: Variant) -> int:
	if not (value is float or value is int):
		return NONE
	var number: float = value
	return int(number) if number >= 0.0 and number <= 1.0e6 and number == floorf(number) else NONE
