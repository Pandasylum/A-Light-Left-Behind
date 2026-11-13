extends Node3D
## Scène de vérification NON OFFICIELLE de la progression de pièce : mini-pièce (3 surfaces du
## cleaning_spike en configuration réduite : 2 marches et le mur droit), 2 étagères avec chacune une
## StorageZone de test, 3 objets suivis (axe rangement) + le seau (aucun axe suivi), Autosave,
## RoomProgress et indicateur. Touche locale F8 : termine d'un coup la prochaine surface.
## « Continuer » : nettoyage, outils, puis disposition et portage ; la section « progression » est
## lue par RoomProgress lui-même.

const FLOOR_SIZE: Vector2 = Vector2(10.0, 10.0) ## emprise du sol du spike
const FLOOR_TOP_Y: float = 0.1 ## face supérieure, dans le repère du corps Floor
const FINISH_KEY: Key = KEY_F8
const SWEEP_RADIUS: float = 0.15
const SWEEP_STEP: float = 0.1
const SWEEP_SEGMENTS: int = 8

@export var tool: ToolData

@onready var _spike: Node3D = $Spike


func _ready() -> void:
	_spike.set_physics_process(false) # pinceau de test du spike coupé (comme sponge_test)
	var surface: PlacementSurface = PlacementSurface.new()
	surface.name = "PlacementSurface"
	surface.size = FLOOR_SIZE
	surface.is_floor = true
	surface.position = Vector3(0.0, FLOOR_TOP_Y, 0.0)
	_spike.get_node(^"Floor").add_child(surface)
	var tools: ToolController = $Spike/Player/ToolController
	tools.add_tool(tool)
	($Autosave as Autosave).setup(_spike, tools)
	# Références prises avant le chargement : un objet restauré en main ou en ceinture change de parent.
	var items: Array[TestItem] = []
	for node: Node in get_children():
		if node is TestItem:
			items.append(node)
	_apply_continue()
	await get_tree().physics_frame
	for item: TestItem in items:
		_drop_to_floor(item)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == FINISH_KEY:
		finish_next_surface()


## Termine d'un coup la prochaine surface non terminée (balayage complet de ses faces, par le chemin du
## geste : fin de surface, signal, Autosave). Renvoie false s'il n'en reste aucune.
func finish_next_surface() -> bool:
	for surface: CleaningSurface in CleaningSurface.room_surfaces(_spike):
		if not surface.is_finished():
			for face: CleanableFace in surface.faces:
				if is_instance_valid(face):
					_sweep(face)
			return true
	return false


func _sweep(face: CleanableFace) -> void:
	face.ensure_fine_grid()
	var xform: Transform3D = face.global_transform
	var size: Vector3 = face.world_bounds().size
	var rows: int = ceili(maxf(size.x, maxf(size.y, size.z)) / SWEEP_STEP) + 1
	for j: int in rows + 1:
		for i: int in SWEEP_SEGMENTS:
			var v: float = float(j) / float(rows)
			face.clean_stroke(xform * face.mapping.point_at(Vector2(float(i) / SWEEP_SEGMENTS, v)),
					xform * face.mapping.point_at(Vector2(float(i + 1) / SWEEP_SEGMENTS, v)), SWEEP_RADIUS, 100.0)


## Pose l'objet sur ce qui se trouve sous lui (rayon vertical, couche monde), sauf s'il vient d'être
## restauré depuis la sauvegarde.
func _drop_to_floor(item: TestItem) -> void:
	if not is_instance_valid(item) or item.placement_restored:
		return
	var top: Vector3 = item.global_position + Vector3.UP
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 4.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	item.global_position = (hit["position"] as Vector3) + Vector3.UP * item.item_data.height * 0.5
	var surface: PlacementSurface = PlacementSurface.of_body(hit["collider"])
	if surface != null:
		item.on_placed(surface)


func _apply_continue() -> void:
	var data: Dictionary = GameFlow.take_continue_data(get_node_or_null(^"/root/SaveService"))
	if data.is_empty():
		return
	CleanableFace.import_room(_spike, data.get(Autosave.CLEANING_KEY, {}))
	if data.has(ToolSlots.SAVE_KEY):
		var catalog: Array[ToolData] = [tool]
		($Spike/Player/ToolController as ToolController).import_tools(data[ToolSlots.SAVE_KEY], catalog)
	($Disposition as RoomLayout).restore(data.get(LayoutState.SAVE_KEY, {}))
