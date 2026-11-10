class_name CarryController
extends Node
## Enfant de Player. Relie CarryInventory au monde : prise (Interactable PICK_UP ciblé), changement
## d'objet (cycle_item), dépôt (drop_object) délégué au PlacementController.

const HAND_OFFSET: Vector3 = Vector3(0.3, -0.25, -0.6)
const LARGE_EXTRA_OFFSET: Vector3 = Vector3(-0.3, 0.05, -0.3) ## LARGE : plus centré

var inventory: CarryInventory = CarryInventory.new() ## recréé dans _ready selon Player.belt_capacity

var _sensor: InteractionSensor
var _prompt: InteractionPrompt
var _anchor: Node3D
var _placement: PlacementController
var _target: Interactable = null


func _ready() -> void:
	var player: Node = get_parent()
	inventory = CarryInventory.new((player as Player).belt_capacity)
	_sensor = player.get_node("Head/InteractionSensor")
	_prompt = player.get_node("InteractionPrompt")
	_anchor = player.get_node("Head/HandAnchor")
	_placement = player.get_node("PlacementController")
	_sensor.target_changed.connect(_on_target_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event.is_action_pressed(&"cycle_item"):
		cycle()
	elif event.is_action_pressed(&"drop_object"):
		drop()


## Prise de l'objet porté par l'Interactable (son parent).
func pick_up(interactable: Interactable) -> void:
	if interactable.action != Interactable.Action.PICK_UP:
		return
	var body: Node3D = interactable.get_parent() as Node3D
	var data: ItemData = body.get("item_data") as ItemData if body != null else null
	if data == null:
		return
	if data.category != ItemData.Category.FIXED and body.has_method(&"has_loads") and body.call(&"has_loads"):
		_prompt.show_message("carry.supports_object") ## un objet qui porte un autre objet ne se prend pas
		return
	var result: CarryInventory.Result = inventory.pick_up(data, body)
	if result != CarryInventory.Result.OK:
		_show_refusal(result)
		return
	if body.has_method(&"on_picked_up"):
		body.call(&"on_picked_up") ## objet repris : plus de surface porteuse, retiré des charges du porteur
	else:
		body.set(&"support_surface", null)
	_refresh_visuals()


func cycle() -> void:
	var result: CarryInventory.Result = inventory.cycle_item()
	if result == CarryInventory.Result.NOTHING_TO_DO:
		return
	if result != CarryInventory.Result.OK:
		_show_refusal(result)
		return
	_refresh_visuals()


## Dépôt : délégué au PlacementController (pose sur la surface visée, ou message de refus).
func drop() -> void:
	if inventory.held() != null:
		_placement.place_held()


## ItemData de l'objet en main (null si la main est vide).
func held_data() -> ItemData:
	return inventory.held()


## Nœud de l'objet en main (null si la main est vide).
func held_body() -> Node3D:
	return inventory.held_ref() as Node3D


## Retire l'objet de la main (pose acceptée) et le renvoie ; l'appelant le replace.
func release_held() -> Node3D:
	var body: Node3D = held_body()
	if body == null or inventory.drop_object() == null:
		return null
	return body


func _on_target_changed(target: Interactable) -> void:
	if _target != null and _target.interacted.is_connected(_on_interacted):
		_target.interacted.disconnect(_on_interacted)
	_target = target
	if _target != null and _target.action == Interactable.Action.PICK_UP:
		_target.interacted.connect(_on_interacted.bind(_target))


func _on_interacted(_player: Node, interactable: Interactable) -> void:
	if _is_active():
		pick_up(interactable)


## Applique la visibilité, la collision et la parenté selon l'état de l'inventaire. Un objet rangé
## automatiquement (main -> ceinture avant une prise) est traité par la boucle de ceinture :
## masqué, collision désactivée.
func _refresh_visuals() -> void:
	var held: Node3D = inventory.held_ref() as Node3D
	if held != null:
		_attach(held)
		held.position = LARGE_EXTRA_OFFSET if inventory.held().category == ItemData.Category.LARGE else Vector3.ZERO
		held.rotation = Vector3.ZERO
		held.visible = true
	for slot: int in inventory.capacity():
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
		CarryInventory.Result.CYCLE_BLOCKED: "carry.cycle_blocked",
	}
	_prompt.show_message(keys[result])


func _is_active() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
