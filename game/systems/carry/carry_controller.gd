class_name CarryController
extends Node
## Enfant de Player. Relie CarryInventory au monde : prise (Interactable PICK_UP ciblé), changement
## d'objet (cycle_item), dépôt (drop_object). Dépôt PROVISOIRE : retour à l'origine mémorisée
## à la prise ; sera remplacé par le placement (P1-D).

const HAND_OFFSET: Vector3 = Vector3(0.3, -0.25, -0.6)
const LARGE_EXTRA_OFFSET: Vector3 = Vector3(-0.3, 0.05, -0.3) ## LARGE : plus centré

var inventory: CarryInventory = CarryInventory.new()

var _sensor: InteractionSensor
var _prompt: InteractionPrompt
var _anchor: Node3D
var _target: Interactable = null
var _origins: Dictionary = {} ## Node3D -> {parent, transform, layer}
var _debug_label: Label


func _ready() -> void:
	var player: Node = get_parent()
	_sensor = player.get_node("Head/InteractionSensor")
	_prompt = player.get_node("InteractionPrompt")
	_anchor = player.get_node("Head/HandAnchor")
	_sensor.target_changed.connect(_on_target_changed)
	inventory.held_changed.connect(func(_i: ItemData) -> void: _update_label())
	inventory.belt_changed.connect(func(_s: int, _i: ItemData) -> void: _update_label())
	_build_debug_label()
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event.is_action_pressed(&"cycle_item"):
		cycle()
	elif event.is_action_pressed(&"drop_object"):
		drop()


## Prise de l'objet porté par l'Interactable (son parent).
func pick_up(interactable: Interactable) -> void:
	if not _is_active() or interactable.action != Interactable.Action.PICK_UP:
		return
	var body: Node3D = interactable.get_parent() as Node3D
	var data: ItemData = body.get("item_data") as ItemData if body != null else null
	if data == null:
		return
	var origin: Dictionary = {"parent": body.get_parent(), "transform": body.global_transform,
			"layer": (body as CollisionObject3D).collision_layer}
	var result: CarryInventory.Result = inventory.pick_up(data, body)
	if result != CarryInventory.Result.OK:
		_show_refusal(result)
		return
	_origins[body] = origin
	_refresh_visuals()


func cycle() -> void:
	var result: CarryInventory.Result = inventory.cycle_item()
	if result != CarryInventory.Result.OK:
		_show_refusal(result)
		return
	_refresh_visuals()


## Dépôt provisoire : l'objet retrouve sa position et son orientation d'origine.
func drop() -> void:
	var body: Node3D = inventory.held_ref() as Node3D
	if inventory.drop_object() == null or body == null:
		return
	var origin: Dictionary = _origins.get(body, {})
	_origins.erase(body)
	if origin.is_empty():
		return
	body.reparent(origin["parent"], false)
	body.global_transform = origin["transform"]
	(body as CollisionObject3D).collision_layer = origin["layer"]
	body.visible = true


func _on_target_changed(target: Interactable) -> void:
	if _target != null and _target.interacted.is_connected(_on_interacted):
		_target.interacted.disconnect(_on_interacted)
	_target = target
	if _target != null and _target.action == Interactable.Action.PICK_UP:
		_target.interacted.connect(_on_interacted.bind(_target))


func _on_interacted(_player: Node, interactable: Interactable) -> void:
	pick_up(interactable)


## Applique la visibilité, la collision et la parenté selon l'état de l'inventaire.
func _refresh_visuals() -> void:
	var held: Node3D = inventory.held_ref() as Node3D
	if held != null:
		_attach(held)
		held.position = LARGE_EXTRA_OFFSET if inventory.held().category == ItemData.Category.LARGE else Vector3.ZERO
		held.rotation = Vector3.ZERO
		held.visible = true
	for slot: int in CarryInventory.BELT_SIZE:
		var stowed: Node3D = inventory.belt_ref(slot) as Node3D
		if stowed != null:
			_attach(stowed)
			stowed.visible = false


func _attach(body: Node3D) -> void:
	(body as CollisionObject3D).collision_layer = 0
	if body.get_parent() != _anchor:
		body.reparent(_anchor, false)


func _show_refusal(result: CarryInventory.Result) -> void:
	var keys: Dictionary = {
		CarryInventory.Result.FIXED: "carry.fixed",
		CarryInventory.Result.HANDS_FULL: "carry.hands_full",
		CarryInventory.Result.BELT_FULL: "carry.belt_full",
		CarryInventory.Result.NOT_STOWABLE: "carry.not_stowable",
	}
	_prompt.show_message(keys[result])


func _is_active() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _build_debug_label() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	_debug_label = Label.new()
	_debug_label.position = Vector2(12, 8)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_debug_label)
	add_child(layer)


## Provisoire (remplacé en P1-E).
func _update_label() -> void:
	var held: ItemData = inventory.held()
	var held_name: String = tr(held.name_key) if held != null else "-"
	_debug_label.text = "Main : %s / Ceinture : %d/%d" % [held_name, inventory.belt_count(), CarryInventory.BELT_SIZE]
