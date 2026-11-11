class_name ToolController
extends Node
## Outil tenu par le joueur (enfant de Player). Tant que use_primary est maintenu, tire un rayon
## depuis la caméra (centre de l'écran, ou curseur si la caméra est figée par lock_camera) et
## nettoie les CleanableFace touchées. Inactif sans outil. Texte de debug provisoire (pas d'UI finale).

const WORLD_LAYER: int = 1

## Outil équipé au départ (null = aucun). equip() en change à l'exécution.
@export var tool: ToolData

var state: ToolState ## null sans outil
var last_stroke_usec: int = 0 ## coût du dernier geste (mesure)
var last_cleaned_area: float = 0.0 ## m² nettoyés par le dernier geste

var _stroking: bool = false
var _last_point: Vector3 = Vector3.ZERO
var _label: Label

@onready var _player: Player = get_parent() as Player
@onready var _camera: Camera3D = get_node_or_null(^"../Head/Camera3D") as Camera3D


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ToolDebug"
	add_child(layer)
	_label = Label.new()
	_label.name = "Infos"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.position += Vector2(-16.0, 16.0)
	equip(tool)


## Équipe un outil propre (null = retire l'outil).
func equip(tool_data: ToolData) -> void:
	tool = tool_data
	state = ToolState.new(tool_data) if tool_data != null else null
	_stroking = false
	_refresh_label()


## Rince l'outil tenu. Renvoie false sans outil.
func rinse() -> bool:
	if state == null:
		return false
	state.rinse()
	_refresh_label()
	return true


func _physics_process(delta: float) -> void:
	if state == null or _camera == null or not _is_active():
		_stroking = false
		return
	var from: Vector3 = _camera.global_position
	var direction: Vector3 = -_camera.global_basis.z
	if _player != null and _player.camera_locked:
		var cursor: Vector2 = _camera.get_viewport().get_mouse_position()
		from = _camera.project_ray_origin(cursor)
		direction = _camera.project_ray_normal(cursor)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from, from + direction * tool.reach_m, WORLD_LAYER)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_stroking = false
		return
	var point: Vector3 = hit["position"]
	stroke(_last_point if _stroking else point, point, delta)
	_last_point = point
	_stroking = true


## Applique un geste monde from -> to pendant delta secondes : nettoie les faces à portée du geste
## (y compris à travers les coutures) et salit l'outil de l'aire nettoyée. Renvoie cette aire (m²).
func stroke(from: Vector3, to: Vector3, delta: float) -> float:
	if state == null or delta <= 0.0:
		return 0.0
	var t0: int = Time.get_ticks_usec()
	var amount: float = state.effective_efficiency() * delta
	var reach_box: AABB = AABB(from, Vector3.ZERO).expand(to).grow(tool.radius_m)
	var cleaned: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(CleanableFace.GROUP):
		var face: CleanableFace = node as CleanableFace
		if face == null or face.is_finished() or not reach_box.intersects(face.world_bounds()):
			continue
		# Grille fine avant la mesure : sans elle, l'aire restante n'est qu'une estimation grossière.
		face.ensure_fine_grid()
		var before: float = face.remaining_dirty_area()
		if face.clean_stroke(from, to, tool.radius_m, amount, tool.layers):
			cleaned += maxf(0.0, before - face.remaining_dirty_area())
	state.add_cleaned_area(cleaned)
	last_cleaned_area = cleaned
	last_stroke_usec = Time.get_ticks_usec() - t0
	_refresh_label()
	return cleaned


## Texte de debug : salissure et efficacité effective ("" sans outil).
func debug_text() -> String:
	if state == null:
		return ""
	return "Outil : %s\nSalissure : %d %%\nEfficacité : %.2f (%d %%)\nDernier geste : %.2f ms" % [
		tool.id, roundi(state.soil * 100.0), state.effective_efficiency(),
		roundi(state.efficiency_factor() * 100.0), last_stroke_usec / 1000.0]


func _is_active() -> bool:
	if not Input.is_action_pressed(&"use_primary"):
		return false
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (_player != null and _player.camera_locked)


func _refresh_label() -> void:
	if _label != null:
		_label.text = debug_text()
		_label.visible = state != null
