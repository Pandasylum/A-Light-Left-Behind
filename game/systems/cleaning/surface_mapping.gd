class_name SurfaceMapping
extends Resource
## Correspondance analytique d'une face nettoyable (spike P2-N1).
## - point (repère du module) <-> UV2 de la face (masque d'état) : uv_at / point_at ;
## - projection monde des épaisseurs et des textures : projection() renvoie l'UNIQUE source
##   de paramètres, utilisée par le shader (apply_to) et par la lecture CPU (uv_monde).
## Classe de base : les sous-classes (plan, cylindre, secteur) redéfinissent les méthodes.

## Mode de projection monde (même valeur que l'uniform proj_mode du shader).
enum Mode { PLAN = 0, CYLINDRE = 1 }

## Tuile de référence : 2π·R/N avec R = 2,0 et N = 12 (1,047 m). PROVISOIRE.
const TUILE_M_DEFAUT: float = TAU * 2.0 / 12.0


## Paramètres de projection monde d'une face posée dans la scène.
class WorldProjection extends RefCounted:
	var mode: int = SurfaceMapping.Mode.PLAN
	var axe_u: Vector3 = Vector3.RIGHT ## plan : axe monde de u
	var axe_v: Vector3 = Vector3.BACK ## plan : axe monde de v
	var axe_xz: Vector2 = Vector2.ZERO ## cylindre : position XZ monde de l'axe vertical
	var rayon_ref: float = 1.0 ## cylindre : rayon de référence (m)
	var tuile_m: float = SurfaceMapping.TUILE_M_DEFAUT ## longueur d'une unité de uv_monde (m)

	## Même formule que fragment() de pierre_nettoyable.gdshader.
	func uv_monde(p: Vector3) -> Vector2:
		if mode == SurfaceMapping.Mode.CYLINDRE:
			var angle: float = atan2(-(p.z - axe_xz.y), p.x - axe_xz.x)
			return Vector2(angle * rayon_ref / tuile_m, p.y / tuile_m)
		return Vector2(p.dot(axe_u), p.dot(axe_v)) / tuile_m

	func apply_to(material: ShaderMaterial) -> void:
		material.set_shader_parameter(&"proj_mode", mode)
		material.set_shader_parameter(&"proj_axe_u", axe_u)
		material.set_shader_parameter(&"proj_axe_v", axe_v)
		material.set_shader_parameter(&"proj_axe_xz", axe_xz)
		material.set_shader_parameter(&"proj_rayon_ref", rayon_ref)
		material.set_shader_parameter(&"proj_tuile_m", tuile_m)


## UV2 (0..1, non bornée hors de la face) d'un point exprimé dans le repère du module.
func uv_at(_local: Vector3) -> Vector2:
	return Vector2.ZERO


## Point de la face (repère du module) pour une UV2 donnée. Inverse de uv_at.
func point_at(_uv: Vector2) -> Vector3:
	return Vector3.ZERO


## Normale de la face (repère du module) pour une UV2 donnée.
func normal_at(_uv: Vector2) -> Vector3:
	return Vector3.UP


## Distance signée à la surface, le long de la normale (m).
func depth_at(_local: Vector3) -> float:
	return 0.0


## Dimensions développées (m) le long de u et de v ; fixe la résolution du masque.
func size_m() -> Vector2:
	return Vector2.ONE


## Aire de la face (m²).
func area() -> float:
	var s: Vector2 = size_m()
	return s.x * s.y


## Aire (m²) du texel (x, y) d'une grille width × height.
func texel_area(_x: int, _y: int, width: int, height: int) -> float:
	return area() / float(width * height)


## Demi-étendue en UV (majorée) d'une sphère de rayon radius_m centrée en uv.
func radius_to_uv(_uv: Vector2, radius_m: float) -> Vector2:
	var s: Vector2 = size_m()
	return Vector2(radius_m / s.x, radius_m / s.y)


## Paramètres de projection monde pour un module placé par module_xform.
func projection(_module_xform: Transform3D) -> WorldProjection:
	return WorldProjection.new()


## Taille de la grille (texels) à la densité demandée.
func grid_size(texels_per_m: float) -> Vector2i:
	var s: Vector2 = size_m()
	return Vector2i(maxi(1, ceili(s.x * texels_per_m - 0.0001)), maxi(1, ceili(s.y * texels_per_m - 0.0001)))


## Projection plane : face horizontale -> XZ monde ; verticale -> plan de l'axe dominant de la normale.
static func plane_projection(world_normal: Vector3, tile_m: float) -> WorldProjection:
	var p: WorldProjection = WorldProjection.new()
	p.mode = Mode.PLAN
	p.tuile_m = tile_m
	var n: Vector3 = world_normal.abs()
	if n.y >= n.x and n.y >= n.z:
		p.axe_u = Vector3.RIGHT
		p.axe_v = Vector3.BACK
	elif n.z >= n.x:
		p.axe_u = Vector3.RIGHT
		p.axe_v = Vector3.UP
	else:
		p.axe_u = Vector3.BACK
		p.axe_v = Vector3.UP
	return p
