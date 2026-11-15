extends Node3D
## Vestibule en blocage gris (scène de jeu PROVISOIRE, décision du 2026-11-15) : mini-pièce du
## cleaning_spike en configuration réduite (3 surfaces à nettoyer : 2 marches et le mur droit), murs gris,
## table et palette (supports, sans zone comptée), étagère basse et 2 étagères murales (zones SMALL),
## 5 objets suivis (copies d'ItemData de test avec tracks_storing) et le seau (non suivi).
## Branchement : Autosave, RoomLayout, StorageService, RoomProgress, ProgressIndicator, PauseMenu.
## « Continuer » : nettoyage, outils, disposition et portage, puis progression.

const FLOOR_SIZE: Vector2 = Vector2(10.0, 10.0) ## emprise du sol du spike
const FLOOR_TOP_Y: float = 0.1 ## face supérieure, dans le repère du corps Floor

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


## « Continuer » (GameFlow.continue_requested) : nettoyage, outils, puis disposition et portage, puis
## verrous de progression (section absente = aucune pièce restaurée).
func _apply_continue() -> void:
	var data: Dictionary = GameFlow.take_continue_data(get_node_or_null(^"/root/SaveService"))
	if data.is_empty():
		return
	CleanableFace.import_room(_spike, data.get(Autosave.CLEANING_KEY, {}))
	if data.has(ToolSlots.SAVE_KEY):
		var catalog: Array[ToolData] = [tool]
		($Spike/Player/ToolController as ToolController).import_tools(data[ToolSlots.SAVE_KEY], catalog)
	($Disposition as RoomLayout).restore(data.get(LayoutState.SAVE_KEY, {}))
	($RoomProgress as RoomProgress).import_state(data.get(ProgressSave.SAVE_KEY, {}))
