class_name PlacementController
extends Node
## Enfant de Player. Pose d'un objet tenu sur une PlacementSurface (sol, support déclaré ou dessus d'un
## objet posé) : aperçu (vert = stable, orange = va tomber, rouge = refusé), rotation par paliers,
## empilement (PlacementCheck.can_stack), support (PlacementCheck) puis collision. Une pose instable
## déclenche une chute verticale (PlacementLanding). Règles d'empilement et de chute PROVISOIRES (GDD §15 pt 18).
## Actif seulement avec un objet en main et la souris capturée.

const WORLD_MASK: int = 1 ## couche 1 : monde (raycast)
const INTERACTIVE_LAYER_VALUE: int = 4 ## couche 3 : interactifs (valeur de masque)
const AIM_MASK: int = WORLD_MASK | INTERACTIVE_LAYER_VALUE ## raycast d'aperçu : monde + objets posés
const TOP_FACE_DOT: float = 0.95 ## produit scalaire minimal (normale . haut) d'une face visée
const COLOR_VALID: Color = Color(0.2, 0.9, 0.3, 0.4)
const COLOR_FALL: Color = Color(1.0, 0.6, 0.1, 0.4)
const COLOR_INVALID: Color = Color(0.95, 0.2, 0.2, 0.4)

enum Verdict { NO_SURFACE, UNSTABLE, BLOCKED, CANNOT_STACK, OK }

## Nœud de la pièce qui reçoit les objets posés (chemin relatif à ce nœud).
@export var placed_objects_path: NodePath = ^"../../PlacedObjects"

@export var rules: PlacementRules = PlacementRules.new() ## valeurs provisoires

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


## Pose l'objet tenu. Aperçu vert : pose directe. Orange (instable) : l'objet tombe droit (PlacementLanding),
## message place.fell ; aucun atterrissage valide : place.blocked. Autre refus : message, sans changement d'état.
func place_held() -> void:
	var body: Node3D = _carry.held_body()
	var data: ItemData = _carry.held_data()
	if body == null or data == null:
		return
	if _state_body != body or _surface == null or _verdict == Verdict.NO_SURFACE:
		_prompt.show_message("place.no_surface")
		return
	if _verdict == Verdict.CANNOT_STACK:
		_prompt.show_message("place.cannot_stack")
		return
	if _verdict == Verdict.BLOCKED:
		_prompt.show_message("place.blocked")
		return
	var surface: PlacementSurface = _surface
	var center: Vector3 = _center
	var fell: bool = false
	if _verdict == Verdict.UNSTABLE:
		var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
		var origin: RID = (surface.get_parent() as CollisionObject3D).get_rid()
		var landing: PlacementLanding.Landing = PlacementLanding.resolve(space, _check, data, _yaw, center, origin,
				(body as CollisionObject3D).get_rid())
		if not landing.ok:
			_prompt.show_message("place.blocked")
			return
		surface = landing.surface
		center = landing.center
		fell = true
	var placed: Node3D = _carry.release_held()
	placed.reparent(_placed_root(), false)
	placed.global_transform = Transform3D(Basis(Vector3.UP, _yaw), center + Vector3.UP * data.height * 0.5)
	(placed as CollisionObject3D).collision_layer = INTERACTIVE_LAYER_VALUE
	placed.visible = true
	if placed.has_method(&"on_placed"):
		placed.call(&"on_placed", surface) ## surface porteuse, charge du porteur
	else:
		placed.set(&"support_surface", surface)
	_reset_state()
	if fell:
		_prompt.show_message("place.fell")


## Vrai si la normale touchée est celle d'une face supérieure (flanc exclu : aucune surface visée).
static func is_top_face(normal: Vector3) -> bool:
	return normal.dot(Vector3.UP) >= TOP_FACE_DOT


## Voir PlacementLanding.is_blocked (conservé ici pour les appelants existants).
static func is_blocked(space: PhysicsDirectSpaceState3D, data: ItemData, yaw: float, center: Vector3,
		exclude: Array[RID] = []) -> bool:
	return PlacementLanding.is_blocked(space, data, yaw, center, exclude)


func _is_active() -> bool:
	return _carry != null and _carry.held_body() != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _update_target() -> void:
	var data: ItemData = _carry.held_data()
	var body: Node3D = _carry.held_body()
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from - _camera.global_transform.basis.z * _sensor.reach
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, AIM_MASK))
	var surface: PlacementSurface = null
	if not hit.is_empty() and is_top_face(hit["normal"]):
		surface = PlacementSurface.of_body(hit.get("collider")) ## support déclaré ou dessus d'un objet
	if surface == null:
		_reset_state()
		return
	var hit_point: Vector3 = hit["position"]
	_surface = surface
	_state_body = body
	_center = Vector3(hit_point.x, surface.top_y(), hit_point.z)
	var exclude: Array[RID] = [(body as CollisionObject3D).get_rid()]
	match PlacementLanding.evaluate_pose(space, _check, data, _yaw, _center, surface, exclude):
		PlacementLanding.Verdict.OK:
			_verdict = Verdict.OK
		PlacementLanding.Verdict.UNSTABLE:
			_verdict = Verdict.UNSTABLE
		PlacementLanding.Verdict.CANNOT_STACK:
			_verdict = Verdict.CANNOT_STACK
		_:
			_verdict = Verdict.BLOCKED
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
	match _verdict:
		Verdict.OK:
			_material.albedo_color = COLOR_VALID
		Verdict.UNSTABLE:
			_material.albedo_color = COLOR_FALL
		_:
			_material.albedo_color = COLOR_INVALID
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
