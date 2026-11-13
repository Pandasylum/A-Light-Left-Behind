class_name RoomLayout
extends Node
## Disposition d'une pièce (nœud fin de la scène de pièce, pas d'autoload) : relie les objets libres
## (TestItem, Bucket) et le portage du joueur à la section « disposition » de la sauvegarde (LayoutState).
## Identifiant stable d'un objet = son chemin d'origine depuis la racine de la pièce, attribué au
## départ de la scène (TestItem.layout_id) : le chemin réel change à chaque prise et à chaque pose.
## restore() ne crée ni ne supprime aucun objet et s'applique à la scène tout juste chargée.

## Dépôt validé d'un objet repris (chute comprise) : seul déclencheur de sauvegarde de la
## disposition (écouté par l'Autosave). La pose initiale et la restauration n'émettent rien.
signal item_deposited(item: TestItem)

const LOG_PREFIX: String = "RoomLayout : "

## Racine de la pièce : repère des identifiants et des positions sauvegardées.
@export var room_path: NodePath = ^".."
## Joueur dont le portage (main, ceinture) est sauvegardé et restauré. Vide : portage ignoré.
@export var player_path: NodePath

## Vrai pendant restore() : l'Autosave ignore alors tout déclencheur (aucune sauvegarde au chargement).
var restoring: bool = false

var _room: Node
var _player: Player
var _items: Dictionary[String, TestItem] = {} # ordre d'enregistrement = ordre de l'arbre au départ
var _postures: Dictionary[String, String] = {}
var _picked: Dictionary[int, bool] = {} # objets repris, pas encore reposés


func _ready() -> void:
	if _room == null:
		setup(get_node_or_null(room_path), get_node_or_null(player_path) as Player)


## Branche la pièce (et le joueur) et enregistre ses objets libres. À appeler avant tout déplacement d'objet.
func setup(room: Node, player: Player = null) -> void:
	_room = room
	_player = player
	if room == null:
		push_warning(LOG_PREFIX + "pièce introuvable (%s)." % room_path)
		return
	for item: TestItem in StorageService.items_under(room):
		watch_item(item)


## Enregistre un objet libre (idempotent). À appeler à sa création pour un objet ajouté plus tard,
## tant qu'il est à sa place d'origine.
func watch_item(item: TestItem) -> void:
	if item.layout_id.is_empty():
		item.layout_id = str(_room.get_path_to(item))
	_items[item.layout_id] = item
	if not item.support_changed.is_connected(_on_support_changed):
		item.support_changed.connect(_on_support_changed)


func posture_of(item: TestItem) -> String:
	return _postures.get(item.layout_id, LayoutState.POSTURE_FLAT)


func set_posture(item: TestItem, posture: String) -> void:
	_postures[item.layout_id] = posture


## Image de la disposition et du portage à cet instant : section « disposition » de la sauvegarde.
## Un objet porté est écrit dans le portage seulement. Un objet sans surface porteuse (jamais
## déplacé ni posé) n'est pas écrit : il reprend sa place initiale.
func export_state() -> Dictionary:
	var objects: Array[Dictionary] = []
	if _room == null:
		return LayoutState.make_section(objects)
	var held: String = ""
	var belt: Array[String] = []
	var carried: Dictionary = {}
	var carry: CarryController = _carry()
	if carry != null:
		var state: Dictionary = carry.export_carry()
		held = _carried_id(state["held"], carried)
		for body: Node3D in state["belt"]:
			belt.append(_carried_id(body, carried))
	var to_room: Transform3D = _room_transform().affine_inverse()
	for item: TestItem in _placed_items():
		if carried.has(item.layout_id):
			continue
		var support: String = _surface_id(item.support_surface)
		var local: Transform3D = to_room * item.global_transform
		if support.is_empty() or not local.is_finite():
			push_warning(LOG_PREFIX + "objet « %s » non sauvegardé (support hors de la pièce ou position non finie)." % item.layout_id)
			continue
		objects.append(LayoutState.make_entry(item.layout_id, local.origin, local.basis.get_euler().y, support, posture_of(item)))
	return LayoutState.make_section(objects, held, belt)


## Applique une section « disposition » ({} = rien à faire). Meubles libres, puis autres objets,
## puis surfaces porteuses et charges par le chemin de la pose, puis portage par le chemin de la
## prise. Faux si toute la section est ignorée. Les outils doivent déjà être restaurés.
func restore(section: Variant) -> bool:
	if _room == null:
		return false
	var surfaces: Dictionary[String, PlacementSurface] = {}
	var floors: Array[PlacementSurface] = []
	var supports: Dictionary = _collect_supports(surfaces, floors)
	var capacity: int = _player.belt_capacity if is_instance_valid(_player) else 0
	var plan: LayoutState.Plan = LayoutState.parse(section, _catalog(), supports, capacity)
	if not plan.accepted:
		push_warning(LOG_PREFIX + "section « %s » ignorée (%s) : disposition initiale, portage vide." % [LayoutState.SAVE_KEY, plan.error])
		return false
	for warning: String in plan.warnings:
		push_warning(LOG_PREFIX + warning + ".")
	restoring = true
	var from_room: Transform3D = _room_transform()
	for placement: Dictionary in plan.positioning_order():
		var body: TestItem = _items[placement["id"]]
		body.global_transform = from_room * Transform3D(Basis(Vector3.UP, placement["angle"]), placement["position"])
	for placement: Dictionary in plan.placements:
		var item: TestItem = _items[placement["id"]]
		_postures[placement["id"]] = placement["posture"]
		if placement["support"] == LayoutState.FLOOR_ID:
			item.restore_support(_floor_under(floors, item.global_position))
		else:
			item.restore_support(surfaces[placement["support"]])
	_restore_carry(plan)
	restoring = false
	return true


## Remet les objets portés en main et en ceinture (mêmes emplacements). Un outil sauvegardé en main
## avec un objet en main (interdit par les règles de prise) est rangé par le chemin existant
## (CarryController.held_changed) : l'objet est gardé.
func _restore_carry(plan: LayoutState.Plan) -> void:
	if not plan.has_carry():
		return
	var carry: CarryController = _carry()
	if carry == null:
		push_warning(LOG_PREFIX + "portage sauvegardé ignoré (aucun joueur branché).")
		return
	var tools: ToolController = _player.get_node_or_null(^"ToolController") as ToolController
	if not plan.held.is_empty() and tools != null and tools.held_tool() != null:
		push_warning(LOG_PREFIX + "objet « %s » et outil en main dans la sauvegarde : l'objet est gardé, l'outil est rangé." % plan.held)
	var carried: Array[TestItem] = []
	var belt: Array[Node3D] = []
	for id: String in plan.belt:
		belt.append(_items.get(id))
		carried.append(_items.get(id))
	carried.append(_items.get(plan.held))
	if not carry.import_carry(_items.get(plan.held), belt):
		push_warning(LOG_PREFIX + "portage sauvegardé refusé par l'inventaire : objets laissés en place.")
		return
	for item: TestItem in carried:
		if item != null:
			item.placement_restored = true


func _carry() -> CarryController:
	return _player.get_node_or_null(^"CarryController") as CarryController if is_instance_valid(_player) else null


## Identifiant de sauvegarde d'un objet porté ("" = emplacement vide ou objet non suivi).
func _carried_id(body: Node3D, carried: Dictionary) -> String:
	var item: TestItem = body as TestItem
	if item == null or item.layout_id.is_empty():
		if body != null:
			push_warning(LOG_PREFIX + "objet porté non suivi (%s) : non sauvegardé." % body.name)
		return ""
	carried[item.layout_id] = true
	return item.layout_id


## Objets posés, dans l'ordre d'enregistrement ; les charges d'un même porteur sont remises dans
## l'ordre de ses charges (loads), pour le reconstruire tel quel au chargement.
func _placed_items() -> Array[TestItem]:
	var placed: Array[TestItem] = []
	for id: String in _items:
		var item: TestItem = _items[id]
		if is_instance_valid(item) and item.is_inside_tree() and is_instance_valid(item.support_surface):
			placed.append(item)
	for carrier: TestItem in placed.duplicate():
		var loads: Array[TestItem] = []
		var slots: Array[int] = []
		for load_body: Node3D in carrier.loads:
			var index: int = placed.find(load_body as TestItem) if is_instance_valid(load_body) else -1
			if index >= 0:
				loads.append(placed[index])
				slots.append(index)
		slots.sort()
		for i: int in slots.size():
			placed[slots[i]] = loads[i]
	return placed


func _catalog() -> Dictionary:
	var catalog: Dictionary = {}
	for id: String in _items:
		var item: TestItem = _items[id]
		if is_instance_valid(item) and item.item_data != null:
			catalog[id] = LayoutState.describe_item(item.item_data.provides_support, item.item_data.category)
	return catalog


## Supports de la pièce pour LayoutState.parse() ; remplit surfaces (hors sol) et floors.
func _collect_supports(surfaces: Dictionary[String, PlacementSurface], floors: Array[PlacementSurface]) -> Dictionary:
	var supports: Dictionary = {}
	for node: Node in _room.find_children("*", "PlacementSurface", true, false):
		var surface: PlacementSurface = node as PlacementSurface
		var id: String = _surface_id(surface)
		if surface.is_floor:
			floors.append(surface)
			supports[id] = ""
		elif not id.is_empty():
			surfaces[id] = surface
			var carrier: TestItem = surface.get_parent() as TestItem
			supports[id] = carrier.layout_id if carrier != null else ""
	return supports


## Identifiant d'un support : « sol », sinon chemin de la surface depuis la racine de la pièce (pour
## le dessus d'un objet libre : à partir de l'identifiant stable de l'objet). "" hors de la pièce.
func _surface_id(surface: PlacementSurface) -> String:
	if surface.is_floor:
		return LayoutState.FLOOR_ID
	var carrier: TestItem = surface.get_parent() as TestItem
	if carrier != null:
		return "" if carrier.layout_id.is_empty() else "%s/%s" % [carrier.layout_id, surface.name]
	return str(_room.get_path_to(surface)) if _room.is_ancestor_of(surface) else ""


## Surface de sol dont l'étendue contient le point (la première de la pièce sinon).
func _floor_under(floors: Array[PlacementSurface], point: Vector3) -> PlacementSurface:
	for floor_surface: PlacementSurface in floors:
		var local: Vector2 = floor_surface.to_local_xz(point)
		if absf(local.x) <= floor_surface.size.x * 0.5 and absf(local.y) <= floor_surface.size.y * 0.5:
			return floor_surface
	return floors[0]


func _room_transform() -> Transform3D:
	return (_room as Node3D).global_transform if _room is Node3D else Transform3D.IDENTITY


## Dépôt = pose (surface porteuse non nulle) d'un objet repris auparavant. La reprise seule
## (surface nulle), la pose initiale et la restauration ne sont pas des dépôts.
func _on_support_changed(item: TestItem) -> void:
	if item.support_surface == null:
		_picked[item.get_instance_id()] = true
	elif _picked.erase(item.get_instance_id()):
		item_deposited.emit(item)
