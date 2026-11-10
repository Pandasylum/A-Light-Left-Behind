class_name InteractionSensor
extends Node
## Enfant de Head, à côté de la Camera3D. Raycast depuis le centre de la caméra (couches 1 et 3).

signal target_changed(interactable: Interactable)

const WORLD_AND_INTERACTIVE_MASK: int = 1 | 4 ## couche 1 (monde) + couche 3 (interactifs)

@export var reach: float = 2.0 ## m (provisoire)

var target: Interactable = null
var _camera: Camera3D = null


func _ready() -> void:
	_camera = get_parent().get_node_or_null("Camera3D")


func _physics_process(_delta: float) -> void:
	if not _is_active():
		set_target(null)
		return
	set_target(resolve_target(_cast()))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		trigger_interact()


## Appelle interact() sur la cible courante. Sans effet si la souris n'est pas capturée.
func trigger_interact() -> void:
	if not _is_active() or target == null:
		return
	target.interact(owner if owner != null else get_parent())


## Interactable enfant du corps, ou null (corps nul, sans Interactable).
func resolve_target(body: Object) -> Interactable:
	var node: Node = body as Node
	if node == null:
		return null
	for child: Node in node.get_children():
		if child is Interactable:
			return child
	return null


## Change la cible ; n'émet que si elle change.
func set_target(new_target: Interactable) -> void:
	if new_target == target:
		return
	target = new_target
	target_changed.emit(target)


func _is_active() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _cast() -> Object:
	if _camera == null or not _camera.is_inside_tree():
		return null
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from - _camera.global_transform.basis.z * reach
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_AND_INTERACTIVE_MASK)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") if not hit.is_empty() else null
