class_name StorageService
extends Node
## Service de rangement d'une pièce (nœud de la scène de pièce, pas d'autoload).
## Tient l'état « rangé » de chaque TestItem de la pièce. État dérivé : rien n'est sauvegardé.
## Évaluation : à la pose (chute comprise) et à la reprise (TestItem.support_changed), et une fois
## au chargement, différée d'une frame physique.

## Émis seulement quand l'état d'un objet change.
signal stored_changed(item: TestItem, stored: bool)
## Émis une fois l'évaluation de chargement terminée.
signal room_evaluated

## Racine de la pièce : objets et zones suivis sont ses descendants.
@export var room_path: NodePath = ^".."
## Chargement : profondeur (m) sondée sous la base d'un objet pour trouver sa surface porteuse.
@export var load_probe_depth: float = 0.05
## Chargement : couches des corps porteurs (1 = monde, 3 = objets).
@export_flags_3d_physics var support_mask: int = 5

## Identifiants d'instance des objets rangés (absent = non rangé).
var _stored: Dictionary[int, bool] = {}


func _ready() -> void:
	await get_tree().physics_frame
	_evaluate_room()
	room_evaluated.emit()


## Objets ramassables sous un nœud, à toute profondeur.
static func items_under(node: Node) -> Array[TestItem]:
	var items: Array[TestItem] = []
	for child: Node in node.get_children():
		if child is TestItem:
			items.append(child)
		items.append_array(items_under(child))
	return items


func is_stored(item: TestItem) -> bool:
	return item != null and _stored.has(item.get_instance_id())


## Suit un objet (pose et reprise réévaluées). Sans effet s'il est déjà suivi ; n'évalue rien.
func watch_item(item: TestItem) -> void:
	if not item.support_changed.is_connected(evaluate):
		item.support_changed.connect(evaluate)


## Recalcule l'état de l'objet ; stored_changed n'est émis que si l'état change.
func evaluate(item: TestItem) -> bool:
	var stored: bool = false
	if item.item_data != null:
		stored = StorageRules.is_stored(item.rests_on_declared_support(), item.item_data.category, _zones_at(item))
	if stored != is_stored(item):
		if stored:
			_stored[item.get_instance_id()] = true
		else:
			_stored.erase(item.get_instance_id())
		stored_changed.emit(item, stored)
	return stored


## Chargement : suit chaque objet de la pièce, retrouve la surface porteuse de ceux qui sont déjà
## posés (aucune n'est mémorisée dans la scène), puis évalue.
func _evaluate_room() -> void:
	var room: Node = get_node_or_null(room_path)
	if room == null:
		push_warning("StorageService : pièce introuvable (%s)" % room_path)
		return
	for item: TestItem in items_under(room):
		watch_item(item)
		if item.support_surface == null and item.item_data != null:
			_find_support(item)
		evaluate(item)


## Rayon vertical du centre de l'objet jusque sous sa base : le corps touché porte l'objet.
func _find_support(item: TestItem) -> void:
	var base: Vector3 = StorageRules.footprint_center(item.global_position, item.global_basis.y, item.item_data.height)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(item.global_position,
			base + Vector3.DOWN * load_probe_depth, support_mask, [item.get_rid()])
	var hit: Dictionary = item.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var surface: PlacementSurface = PlacementSurface.of_body(hit["collider"])
	if surface != null:
		item.on_placed(surface)


## Règles des zones de la pièce dont le volume contient le point de référence de l'objet.
func _zones_at(item: TestItem) -> Array[ZoneData]:
	var zones: Array[ZoneData] = []
	var room: Node = get_node_or_null(room_path)
	if room == null:
		return zones
	for node: Node in get_tree().get_nodes_in_group(StorageZone.GROUP):
		var zone: StorageZone = node as StorageZone
		if zone != null and room.is_ancestor_of(zone) and zone.contains_item(item):
			zones.append(zone.zone_data)
	return zones
