class_name TestItem
extends StaticBody3D
## Objet de test ramassable. Le cube suit l'ItemData (x, z = emprise ; hauteur = height).

## Émis après une pose (chute comprise) ou une reprise : la surface porteuse a changé (écouté par le rangement).
signal support_changed(item: TestItem)

@export var item_data: ItemData

## Surface de pose porteuse (null tant que l'objet n'est pas posé ; vidée à la reprise).
var support_surface: PlacementSurface = null
## Objets posés sur le dessus de celui-ci (mis à jour à la pose et à la reprise).
var loads: Array[Node3D] = []


func _ready() -> void:
	if item_data == null:
		return
	var size: Vector3 = cube_size(item_data)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	($MeshInstance3D as MeshInstance3D).mesh = mesh
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	($CollisionShape3D as CollisionShape3D).shape = shape
	# Dessus de l'objet : surface de pose (suit la rotation du corps), emprise = taille de l'ItemData.
	var top: PlacementSurface = $PlacementSurface
	top.position = Vector3(0.0, item_data.height * 0.5, 0.0)
	top.size = item_data.footprint
	top.is_declared_support = item_data.provides_support


static func cube_size(data: ItemData) -> Vector3:
	return Vector3(data.footprint.x, data.height, data.footprint.y)


## Vrai si au moins un objet est posé dessus (l'objet ne peut alors pas être pris).
func has_loads() -> bool:
	for load_body: Node3D in loads:
		if is_instance_valid(load_body):
			return true
	return false


## Appelé à la pose : mémorise la surface porteuse et s'ajoute aux charges du porteur (dessus d'un objet).
func on_placed(surface: PlacementSurface) -> void:
	support_surface = surface
	var carrier: Node = surface.get_parent()
	if carrier != null and carrier.get(&"loads") != null and not (carrier.get(&"loads") as Array).has(self):
		(carrier.get(&"loads") as Array).append(self)
	support_changed.emit(self)


## Appelé à la reprise : plus de surface porteuse, retiré des charges du porteur.
func on_picked_up() -> void:
	if support_surface != null:
		var carrier: Node = support_surface.get_parent()
		if carrier != null and carrier.get(&"loads") != null:
			(carrier.get(&"loads") as Array).erase(self)
	support_surface = null
	support_changed.emit(self)


## Vrai si l'objet est posé sur une surface qui n'est pas le sol et qui est un support déclaré
## (installation fixe ou meuble libre). Utilisé par le rangement (StorageService).
func rests_on_declared_support() -> bool:
	return support_surface != null and not support_surface.is_floor and support_surface.is_declared_support
