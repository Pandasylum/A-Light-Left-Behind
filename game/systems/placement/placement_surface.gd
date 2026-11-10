class_name PlacementSurface
extends Node3D
## Surface de pose plate et horizontale. Enfant d'un corps de collision de la couche 1.
## La face supérieure est à l'origine du nœud, normale vers le haut ; seule une rotation
## autour de l'axe vertical est supportée. Le sol de la pièce est une surface is_floor = true ;
## une palette ou une étagère basse est is_floor = false, même au niveau du sol.

## Étendue locale de la face supérieure : x (largeur) et y (profondeur, axe Z local), en mètres.
@export var size: Vector2 = Vector2(1.0, 1.0)
## Vrai pour le sol de la pièce.
@export var is_floor: bool = false
## Vrai pour un support déclaré (sol, palette, table, plot, dessus d'un meuble libre). Faux pour le dessus
## d'un objet ordinaire : un objet posé dessus est non rangé.
@export var is_declared_support: bool = true


## Surface (enfant PlacementSurface) du corps donné, ou null.
static func of_body(body: Object) -> PlacementSurface:
	var node: Node = body as Node
	if node == null:
		return null
	for child: Node in node.get_children():
		if child is PlacementSurface:
			return child
	return null


## Point monde -> coordonnées locales (x, z) sur la surface.
func to_local_xz(world_point: Vector3) -> Vector2:
	var local: Vector3 = global_transform.affine_inverse() * world_point
	return Vector2(local.x, local.z)


## Lacet monde (rotation autour de Y) -> lacet local à la surface.
func to_local_yaw(world_yaw: float) -> float:
	return world_yaw - global_rotation.y


## Hauteur monde de la face supérieure.
func top_y() -> float:
	return global_position.y
