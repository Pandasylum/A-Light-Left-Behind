class_name PlacementSurface
extends Node3D
## Surface de pose plate et horizontale. Enfant d'un corps de collision de la couche 1.
## La face supérieure est à l'origine du nœud, normale vers le haut ; seule une rotation
## autour de l'axe vertical est supportée. Exception : une surface murale (is_wall) est un plan vertical. Le sol de la pièce est une surface is_floor = true ;
## une palette ou une étagère basse est is_floor = false, même au niveau du sol.

## Étendue locale de la face supérieure : x (largeur) et y (profondeur, axe Z local), en mètres.
@export var size: Vector2 = Vector2(1.0, 1.0)
## Vrai pour le sol de la pièce.
@export var is_floor: bool = false
## Vrai pour un support déclaré (sol, palette, table, plot, dessus d'un meuble libre). Faux pour le dessus
## d'un objet ordinaire : un objet posé dessus est non rangé.
@export var is_declared_support: bool = true

## Surface murale (Direction 2026-11-15, provisoire) : plan vertical, `size` = (largeur, hauteur), centré sur l'origine
## du nœud ; la normale, qui sort du mur vers la pièce, est l'axe Z local (donc l'orientation de la zone dont elle est
## l'enfant). Aucune rotation de l'objet par le joueur : seule la posture ACCROCHE s'y pose (voir HangPose).
@export var is_wall: bool = false

## Zone de rangement qui couvre cette surface (lien minimal, sert à lire la posture imposée). Null : hors zone, posture à plat.
@export var zone: StorageZone = null


## Groupe des surfaces murales (parcouru par la visée du PlacementController).
const WALL_GROUP: StringName = &"wall_surfaces"


func _ready() -> void:
	if is_wall:
		add_to_group(WALL_GROUP)


## Surface (enfant PlacementSurface) du corps donné, ou null.
static func of_body(body: Object) -> PlacementSurface:
	var node: Node = body as Node
	if node == null:
		return null
	for child: Node in node.get_children():
		if child is PlacementSurface:
			return child
	return null


## Posture imposée par la zone à cette catégorie ; à plat hors zone.
func posture_for(category: ItemData.Category) -> ItemData.Posture:
	if zone == null or zone.zone_data == null:
		return ItemData.Posture.A_PLAT
	return zone.zone_data.posture_for(category)


## Point monde -> coordonnées locales (x, z) sur la surface.
func to_local_xz(world_point: Vector3) -> Vector2:
	var local: Vector3 = global_transform.affine_inverse() * world_point
	return Vector2(local.x, local.z)


## Lacet monde (rotation autour de Y) -> lacet local à la surface.
func to_local_yaw(world_yaw: float) -> float:
	return world_yaw - global_rotation.y


## Surface murale : normale du mur (monde, vers la pièce).
func wall_normal() -> Vector3:
	return global_basis.z.normalized()


## Surface murale : point monde -> (x, y) dans le plan du mur, et distance signée au plan (z local).
func to_wall_plane(world_point: Vector3) -> Vector3:
	return global_transform.affine_inverse() * world_point


## Hauteur monde de la face supérieure.
func top_y() -> float:
	return global_position.y
