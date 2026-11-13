class_name StorageZone
extends Area3D
## Zone de rangement souple : volume placé dans la scène de pièce, règles dans une ZoneData.
## Volume = enfants CollisionShape3D à BoxShape3D (plusieurs boîtes possibles), interrogé par calcul :
## aucune surveillance physique, aucun body_entered/body_exited (objets déplacés par code).
## Le volume doit englober le dessus du support (le point testé est à la base de l'objet).

const GROUP: StringName = &"storage_zones"

@export var zone_data: ZoneData


func _ready() -> void:
	add_to_group(GROUP)
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	if zone_data == null:
		push_warning("StorageZone %s : zone_data manquante" % name)
	if _boxes().is_empty():
		push_warning("StorageZone %s : aucun volume (CollisionShape3D à BoxShape3D)" % name)


## Vrai si le point monde est dans le volume de la zone.
func contains_point(world_point: Vector3) -> bool:
	for shape: CollisionShape3D in _boxes():
		var local: Vector3 = shape.global_transform.affine_inverse() * world_point
		if StorageRules.box_contains((shape.shape as BoxShape3D).size, local):
			return true
	return false


## Vrai si le centre de l'emprise de l'objet est dans le volume de la zone.
func contains_item(item: TestItem) -> bool:
	if item == null or item.item_data == null:
		return false
	return contains_point(StorageRules.footprint_center(item.global_position, item.global_basis.y,
			item.item_data.height))


## Question posée à la zone : cet objet est-il dans mon volume et sa catégorie est-elle acceptée ?
## (Ne dit pas s'il est rangé : le support est jugé par StorageRules.is_stored.)
func holds(item: TestItem) -> bool:
	return contains_item(item) and StorageRules.accepts(zone_data, item.item_data.category)


func _boxes() -> Array[CollisionShape3D]:
	var boxes: Array[CollisionShape3D] = []
	for child: Node in get_children():
		var shape: CollisionShape3D = child as CollisionShape3D
		if shape != null and not shape.disabled and shape.shape is BoxShape3D:
			boxes.append(shape)
	return boxes
