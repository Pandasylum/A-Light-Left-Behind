class_name TestItem
extends StaticBody3D
## Objet de test ramassable. Le cube suit l'ItemData (x, z = emprise ; hauteur = height).

@export var item_data: ItemData

## Surface de pose porteuse (null tant que l'objet n'est pas posé ; vidée à la reprise).
var support_surface: PlacementSurface = null


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


static func cube_size(data: ItemData) -> Vector3:
	return Vector3(data.footprint.x, data.height, data.footprint.y)
