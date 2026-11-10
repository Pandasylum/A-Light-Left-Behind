class_name PlacementController
extends Node
## Enfant de Player. Pose simple d'un objet tenu sur une PlacementSurface : aperçu (vert = valide,
## rouge = refusé), rotation par paliers, vérification du support (PlacementCheck) puis de la collision.
## Actif seulement avec un objet en main et la souris capturée. Aucun empilement ni chute (P1-D2) :
## toute collision ou pose instable est refusée.

const WORLD_MASK: int = 1 ## couche 1 : monde (raycast)
const INTERACTIVE_LAYER_VALUE: int = 4 ## couche 3 : interactifs (valeur de masque)
const QUERY_MASK: int = 1 | 2 | 4 ## couches 1, 2 (joueur) et 3
const SHRINK: float = 0.001 ## m : boîte de requête réduite
const LIFT: float = 0.002 ## m : boîte de requête soulevée (ne touche pas la surface porteuse)
const COLOR_VALID: Color = Color(0.2, 0.9, 0.3, 0.4)
const COLOR_INVALID: Color = Color(0.95, 0.2, 0.2, 0.4)

enum Verdict { NO_SURFACE, UNSTABLE, BLOCKED, OK }

## Nœud de la pièce qui reçoit les objets posés (chemin relatif à ce nœud).
@export var placed_objects_path: NodePath = ^"../../PlacedObjects"

var rules: PlacementRules = PlacementRules.new() ## valeurs provisoires

var _player: Player
var _camera: Camera3D
var _sensor: InteractionSensor
var _carry: CarryController
var _prompt: InteractionPrompt
var _preview: MeshInstance3D
var _material: StandardMaterial3D
var _check: PlacementCheck

var _yaw: float = 0.0 ## lacet monde de l'objet, rad
var _verdict: Verdict = Verdict.NO_SURFACE
var _surface: PlacementSurface = null
var _center: Vector3 = Vector3.ZERO ## centre de pose sur la face supérieure (monde)
var _state_body: Node3D = null ## objet pour lequel l'état ci-dessus a été calculé


func _ready() -> void:
	_player = get_parent() as Player
	_camera = _player.get_node("Head/Camera3D")
	_sensor = _player.get_node("Head/InteractionSensor")
	_carry = _player.get_node("CarryController")
	_prompt = _player.get_node("InteractionPrompt")
	_check = PlacementCheck.new(rules)
	_build_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event.is_action_pressed(&"rotate_left"):
		rotate_by(1)
	elif event.is_action_pressed(&"rotate_right"):
		rotate_by(-1)


func _physics_process(_delta: float) -> void:
	if not _is_active():
		_reset_state()
		return
	_update_target()


## Tourne l'aperçu de `steps` paliers (positif = gauche). Les orientations autorisées de l'ItemData
## (identifiants, sans angle) ne sont pas encore appliquées : voir le rapport P1-D1.
func rotate_by(steps: int) -> void:
	_yaw = wrapf(_yaw + deg_to_rad(rules.rotation_step_degrees) * steps, -PI, PI)


## Pose l'objet tenu si l'aperçu est valide ; sinon message, sans changement d'état.
func place_held() -> void:
	var body: Node3D = _carry.held_body()
	var data: ItemData = _carry.held_data()
	if body == null or data == null:
		return
	if _state_body != body or _surface == null or _verdict == Verdict.NO_SURFACE:
		_prompt.show_message("place.no_surface")
		return
	if _verdict == Verdict.UNSTABLE:
		_prompt.show_message("place.unstable")
		return
	if _verdict == Verdict.BLOCKED:
		_prompt.show_message("place.blocked")
		return
	var surface: PlacementSurface = _surface
	var transform_world: Transform3D = Transform3D(Basis(Vector3.UP, _yaw), _center + Vector3.UP * data.height * 0.5)
	var placed: Node3D = _carry.release_held()
	placed.reparent(_placed_root(), false)
	placed.global_transform = transform_world
	(placed as CollisionObject3D).collision_layer = INTERACTIVE_LAYER_VALUE
	placed.visible = true
	placed.set(&"support_surface", surface)
	_reset_state()


## Vrai si une boîte de l'emprise de l'objet, à ce lacet et centre de pose, touche un corps des couches 1, 2 ou 3
## (hors `exclude`). Boîte réduite et soulevée de quelques mm pour ne pas détecter la surface porteuse.
static func is_blocked(space: PhysicsDirectSpaceState3D, data: ItemData, yaw: float, center: Vector3,
		exclude: Array[RID] = []) -> bool:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(data.footprint.x - SHRINK, data.height - SHRINK, data.footprint.y - SHRINK)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP, yaw), center + Vector3.UP * (data.height * 0.5 + LIFT))
	query.collision_mask = QUERY_MASK
	query.exclude = exclude
	return not space.intersect_shape(query, 1).is_empty()


func _is_active() -> bool:
	return _carry != null and _carry.held_body() != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _update_target() -> void:
	var data: ItemData = _carry.held_data()
	var body: Node3D = _carry.held_body()
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from - _camera.global_transform.basis.z * _sensor.reach
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK))
	var surface: PlacementSurface = PlacementSurface.of_body(hit.get("collider")) if not hit.is_empty() else null
	if surface == null:
		_reset_state()
		return
	var hit_point: Vector3 = hit["position"]
	_surface = surface
	_state_body = body
	_center = Vector3(hit_point.x, surface.top_y(), hit_point.z)
	if _check.evaluate(data, _yaw, _center, surface).status != PlacementCheck.Status.OK:
		_verdict = Verdict.UNSTABLE
	elif is_blocked(space, data, _yaw, _center, [(body as CollisionObject3D).get_rid()]):
		_verdict = Verdict.BLOCKED
	else:
		_verdict = Verdict.OK
	_show_preview(data)


func _reset_state() -> void:
	_verdict = Verdict.NO_SURFACE
	_surface = null
	_state_body = null
	if _preview != null:
		_preview.visible = false


func _show_preview(data: ItemData) -> void:
	(_preview.mesh as BoxMesh).size = Vector3(data.footprint.x, data.height, data.footprint.y)
	_preview.global_transform = Transform3D(Basis(Vector3.UP, _yaw), _center + Vector3.UP * data.height * 0.5)
	_material.albedo_color = COLOR_VALID if _verdict == Verdict.OK else COLOR_INVALID
	_preview.visible = true


func _build_preview() -> void:
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview = MeshInstance3D.new()
	_preview.mesh = BoxMesh.new()
	_preview.material_override = _material
	_preview.top_level = true
	_preview.visible = false
	add_child(_preview)


func _placed_root() -> Node:
	var root: Node = get_node_or_null(placed_objects_path)
	return root if root != null else _player.get_parent()
