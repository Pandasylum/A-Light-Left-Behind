class_name CarryInventory
extends RefCounted
## Logique pure du port d'objets : une main et une ceinture (SMALL seulement) de capacité
## paramétrable, 1 à 5 (règles de prise validées, Direction 2026-11-10). Aucune dépendance aux
## scènes : chaque objet est un ItemData accompagné d'une référence opaque (ref), p. ex. le nœud du monde.

enum Result { OK, FIXED, HANDS_FULL, BELT_FULL, NOT_STOWABLE, CYCLE_BLOCKED, NOTHING_TO_DO }

const BELT_MIN: int = 1
const BELT_MAX: int = 5

signal held_changed(item: ItemData)
signal belt_changed(slot: int, item: ItemData)

var _held: ItemData = null
var _held_ref: Object = null
var _belt: Array[ItemData] = []
var _belt_refs: Array[Object] = []
var _capacity: int = BELT_MIN
var _cursor: int = 0 ## prochain emplacement examiné par cycle_item


## capacity : capacité de la ceinture, bornée entre BELT_MIN et BELT_MAX.
func _init(capacity: int = BELT_MIN) -> void:
	_capacity = clampi(capacity, BELT_MIN, BELT_MAX)
	_belt.resize(_capacity)
	_belt_refs.resize(_capacity)


func capacity() -> int:
	return _capacity


func held() -> ItemData:
	return _held


func held_ref() -> Object:
	return _held_ref


func belt_item(slot: int) -> ItemData:
	return _belt[slot]


func belt_ref(slot: int) -> Object:
	return _belt_refs[slot]


func belt_count() -> int:
	var n: int = 0
	for it: ItemData in _belt:
		if it != null:
			n += 1
	return n


## Tente de prendre un objet.
## SMALL : main si libre, sinon ceinture, sinon refusé. MEDIUM/LARGE : un SMALL en main est rangé
## automatiquement en ceinture (refus BELT_FULL si pleine, rien ne change). Main occupée par un
## MEDIUM/LARGE : tout est refusé (HANDS_FULL), SMALL compris.
func pick_up(item: ItemData, ref: Object = null) -> Result:
	if item.category == ItemData.Category.FIXED:
		return Result.FIXED
	if _held != null and _held.category != ItemData.Category.SMALL:
		return Result.HANDS_FULL
	if item.category == ItemData.Category.SMALL:
		if _held == null:
			_set_held(item, ref)
			return Result.OK
		return add_to_belt(item, ref)
	# MEDIUM / LARGE (un LARGE prend les deux mains).
	if _held != null:
		var slot: int = _free_slot()
		if slot == -1:
			return Result.BELT_FULL
		_set_belt(slot, _held, _held_ref) # rangement automatique avant la prise
	_set_held(item, ref)
	return Result.OK


## Place un objet directement à la ceinture (SMALL seulement, emplacement libre le plus bas).
func add_to_belt(item: ItemData, ref: Object = null) -> Result:
	if item.category == ItemData.Category.FIXED:
		return Result.FIXED
	if item.category != ItemData.Category.SMALL:
		return Result.NOT_STOWABLE
	var slot: int = _free_slot()
	if slot == -1:
		return Result.BELT_FULL
	_set_belt(slot, item, ref)
	return Result.OK


## Échange la main avec le prochain emplacement occupé (main vide : prend simplement l'objet).
## MEDIUM/LARGE en main : CYCLE_BLOCKED. Aucun emplacement occupé : NOTHING_TO_DO.
func cycle_item() -> Result:
	if _held != null and _held.category != ItemData.Category.SMALL:
		return Result.CYCLE_BLOCKED
	for step: int in _capacity:
		var slot: int = (_cursor + step) % _capacity
		if _belt[slot] == null:
			continue
		var taken: ItemData = _belt[slot]
		var taken_ref: Object = _belt_refs[slot]
		var old: ItemData = _held
		var old_ref: Object = _held_ref
		_set_belt(slot, old, old_ref)
		_set_held(taken, taken_ref)
		_cursor = (slot + 1) % _capacity
		return Result.OK
	return Result.NOTHING_TO_DO


## Retire l'objet de la main et le renvoie (null si la main est vide).
func drop_object() -> ItemData:
	var dropped: ItemData = _held
	if dropped != null:
		_set_held(null, null)
	return dropped


## Image du portage (sauvegarde) : objet en main et ceinture par emplacement, dans l'ordre exact,
## avec les références (null = vide). Clés : held, held_ref, belt, belt_refs.
func export_state() -> Dictionary:
	return {"held": _held, "held_ref": _held_ref, "belt": _belt.duplicate(), "belt_refs": _belt_refs.duplicate()}


## Chargement : remet l'inventaire dans l'état d'une image d'export_state(), aux mêmes emplacements.
## Mêmes règles que la prise : jamais de FIXED, ceinture de SMALL seulement, dans la capacité.
## État refusé = rien ne change (false). held_changed / belt_changed sont émis pour chaque
## emplacement modifié ; cycle_item repart du premier emplacement.
func import_state(state: Dictionary) -> bool:
	var held: ItemData = state.get("held") as ItemData
	var belt: Array = state.get("belt", [])
	var belt_refs: Array = state.get("belt_refs", [])
	if held != null and held.category == ItemData.Category.FIXED:
		return false
	for slot: int in belt.size():
		var item: ItemData = belt[slot] as ItemData
		if item != null and (slot >= _capacity or item.category != ItemData.Category.SMALL):
			return false
	for slot: int in _capacity:
		var item: ItemData = belt[slot] as ItemData if slot < belt.size() else null
		var ref: Object = belt_refs[slot] as Object if item != null and slot < belt_refs.size() else null
		if item != _belt[slot] or ref != _belt_refs[slot]:
			_set_belt(slot, item, ref)
	var held_ref: Object = state.get("held_ref") as Object if held != null else null
	if held != _held or held_ref != _held_ref:
		_set_held(held, held_ref)
	_cursor = 0
	return true


func _set_held(item: ItemData, ref: Object) -> void:
	_held = item
	_held_ref = ref
	held_changed.emit(item)


func _set_belt(slot: int, item: ItemData, ref: Object) -> void:
	_belt[slot] = item
	_belt_refs[slot] = ref
	belt_changed.emit(slot, item)


func _free_slot() -> int:
	for i: int in _capacity:
		if _belt[i] == null:
			return i
	return -1
