class_name CarryInventory
extends RefCounted
## Logique pure du port d'objets : une main et une ceinture de 5 emplacements (SMALL seulement).
## Règles de prise provisoires. Aucune dépendance aux scènes : chaque objet est un ItemData
## accompagné d'une référence opaque (ref), p. ex. le nœud du monde.

enum Result { OK, FIXED, HANDS_FULL, BELT_FULL, NOT_STOWABLE }

const BELT_SIZE: int = 5

signal held_changed(item: ItemData)
signal belt_changed(slot: int, item: ItemData)

var _held: ItemData = null
var _held_ref: Object = null
var _belt: Array[ItemData] = []
var _belt_refs: Array[Object] = []
var _cursor: int = 0 ## prochain emplacement examiné par cycle_item


func _init() -> void:
	_belt.resize(BELT_SIZE)
	_belt_refs.resize(BELT_SIZE)


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


## Tente de prendre un objet (règles a à d).
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
	# MEDIUM / LARGE : main vide exigée (un LARGE prend les deux mains).
	if _held != null:
		return Result.HANDS_FULL
	_set_held(item, ref)
	return Result.OK


## Place un objet directement à la ceinture (SMALL seulement, emplacement libre le plus bas).
func add_to_belt(item: ItemData, ref: Object = null) -> Result:
	if item.category == ItemData.Category.FIXED:
		return Result.FIXED
	if item.category != ItemData.Category.SMALL:
		return Result.NOT_STOWABLE
	for i: int in BELT_SIZE:
		if _belt[i] == null:
			_set_belt(i, item, ref)
			return Result.OK
	return Result.BELT_FULL


## Échange la main avec le prochain emplacement occupé (main vide : prend simplement l'objet).
## Sans objet à la ceinture : aucun effet, OK. Main tenant un MEDIUM/LARGE : HANDS_FULL.
func cycle_item() -> Result:
	if _held != null and _held.category != ItemData.Category.SMALL:
		return Result.HANDS_FULL
	for step: int in BELT_SIZE:
		var slot: int = (_cursor + step) % BELT_SIZE
		if _belt[slot] == null:
			continue
		var taken: ItemData = _belt[slot]
		var taken_ref: Object = _belt_refs[slot]
		var old: ItemData = _held
		var old_ref: Object = _held_ref
		_set_belt(slot, old, old_ref)
		_set_held(taken, taken_ref)
		_cursor = (slot + 1) % BELT_SIZE
		return Result.OK
	return Result.OK


## Retire l'objet de la main et le renvoie (null si la main est vide).
func drop_object() -> ItemData:
	var dropped: ItemData = _held
	if dropped != null:
		_set_held(null, null)
	return dropped


func _set_held(item: ItemData, ref: Object) -> void:
	_held = item
	_held_ref = ref
	held_changed.emit(item)


func _set_belt(slot: int, item: ItemData, ref: Object) -> void:
	_belt[slot] = item
	_belt_refs[slot] = ref
	belt_changed.emit(slot, item)
