class_name PlanarMapping
extends SurfaceMapping
## Face plane (mur droit, contremarche). u = (p − origine)·axe_u / taille.x ;
## v = 1 − (p − origine)·axe_v / taille.y (v inversée par l'export glTF). Normale = axe_u × axe_v.

@export var origine: Vector3 = Vector3.ZERO ## coin u = 0, v = 1 (repère du module)
@export var axe_u: Vector3 = Vector3.RIGHT ## unitaire
@export var axe_v: Vector3 = Vector3.UP ## unitaire, perpendiculaire à axe_u
@export var taille: Vector2 = Vector2(2.0, 2.16) ## m (2,16 PROVISOIRE)
@export var tuile_m: float = SurfaceMapping.TUILE_M_DEFAUT ## PROVISOIRE


func uv_at(local: Vector3) -> Vector2:
	var d: Vector3 = local - origine
	return Vector2(d.dot(axe_u) / taille.x, 1.0 - d.dot(axe_v) / taille.y)


func point_at(uv: Vector2) -> Vector3:
	return origine + axe_u * (uv.x * taille.x) + axe_v * ((1.0 - uv.y) * taille.y)


func normal_at(_uv: Vector2) -> Vector3:
	return axe_u.cross(axe_v).normalized()


func depth_at(local: Vector3) -> float:
	return (local - origine).dot(normal_at(Vector2.ZERO))


func size_m() -> Vector2:
	return taille


func projection(module_xform: Transform3D) -> SurfaceMapping.WorldProjection:
	return SurfaceMapping.plane_projection(module_xform.basis * normal_at(Vector2.ZERO), tuile_m)
