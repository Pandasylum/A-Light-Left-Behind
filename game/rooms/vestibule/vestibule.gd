extends Node3D
## Vestibule en blocage gris (scène de jeu PROVISOIRE, décision du 2026-11-15) : mini-pièce du
## cleaning_spike en configuration réduite (3 surfaces à nettoyer : 2 marches et le mur droit), murs gris,
## table et palette (supports + zones comptées), étagère basse et 2 étagères murales (zones SMALL),
## 10 objets suivis d'origine (tracks_storing) plus le tableau du phare, et le seau (non suivi).
## Branchement : Autosave, RoomLayout, StorageService, RoomProgress, ProgressIndicator, PauseMenu.
## « Continuer » : nettoyage, outils, disposition et portage, puis progression.
## Zones murales « accroché » (Direction 15/11/2026, provisoire) : construites au départ par WallZoneBuilder, une par pan
## de mur libre des 4 murs (retraits : étagères murales, porte, faces à nettoyer ; valeurs : WallZoneRules).

const FLOOR_SIZE: Vector2 = Vector2(10.0, 10.0) ## emprise du sol du spike
const FLOOR_TOP_Y: float = 0.1 ## face supérieure, dans le repère du corps Floor

@export var tool: ToolData
@export var wall_rules: WallZoneRules ## plage de hauteur, marges, portée des retraits (provisoire)
@export var wall_zone_data: ZoneData ## règles des zones murales (MEDIUM -> ACCROCHE)
## Retraits des pans de mur : corps à volumes BoxShape3D (étagères murales, ouvertures) ou repères Marker3D (portes).
@export var wall_cuts: Array[NodePath] = []

@onready var _spike: Node3D = $Spike


func _ready() -> void:
	_spike.set_physics_process(false) # pinceau de test du spike coupé (comme sponge_test)
	_build_wall_zones()
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


## Zones murales : une par pan libre de chaque mur de $Walls, sous $Zones. Retraits : les nœuds de `wall_cuts`
## (Marker3D = porte, sinon boîte de collision) et les faces à nettoyer de la pièce (CleanableFace).
func _build_wall_zones() -> void:
	var root: Node3D = $Zones
	var to_room: Transform3D = root.global_transform.affine_inverse()
	var bodies: Array[StaticBody3D] = []
	var center: Vector3 = Vector3.ZERO
	for node: Node in $Walls.get_children():
		if node is StaticBody3D:
			bodies.append(node)
			center += to_room * (node as StaticBody3D).global_position
	center /= maxf(1.0, float(bodies.size()))
	var walls: Array[WallZoneBuilder.Wall] = []
	for body: StaticBody3D in bodies:
		var wall: WallZoneBuilder.Wall = WallZoneBuilder.wall_of(body, to_room, center)
		if wall != null:
			walls.append(wall)
	var boxes: Array[AABB] = []
	var doors: Array[Vector3] = []
	for path: NodePath in wall_cuts:
		var cut: Node3D = get_node_or_null(path) as Node3D
		if cut == null:
			push_warning("vestibule : retrait de mur introuvable (%s)" % path)
		elif cut is Marker3D:
			doors.append(to_room * cut.global_position)
		else:
			boxes.append(WallZoneBuilder.box_of_body(cut, to_room))
	for node: Node in get_tree().get_nodes_in_group(CleanableFace.GROUP):
		var face: CleanableFace = node as CleanableFace
		if face != null and is_ancestor_of(face):
			boxes.append(to_room * face.world_bounds())
	WallZoneBuilder.plan(walls, boxes, doors, wall_rules)
	WallZoneBuilder.build(root, walls, wall_rules, wall_zone_data)


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
