class_name SectorMapping
extends SurfaceMapping
## Secteur d'anneau horizontal (dessus de marche), correspondance polaire.
## u = (r − r0) / (r1 − r0) ; v = 1 − angle / angle_rad ; angle = atan2(−z, x). Normale +Y.

@export var r0: float = 0.5 ## m
@export var r1: float = 2.0 ## m
@export var angle_rad: float = deg_to_rad(15.0)
@export var y: float = 0.18 ## hauteur du dessus (m)
@export var tuile_m: float = SurfaceMapping.TUILE_M_DEFAUT ## PROVISOIRE


func uv_at(local: Vector3) -> Vector2:
	var r: float = Vector2(local.x, local.z).length()
	return Vector2((r - r0) / (r1 - r0), 1.0 - atan2(-local.z, local.x) / angle_rad)


func point_at(uv: Vector2) -> Vector3:
	var r: float = r0 + uv.x * (r1 - r0)
	var a: float = (1.0 - uv.y) * angle_rad
	return Vector3(r * cos(a), y, -r * sin(a))


func depth_at(local: Vector3) -> float:
	return local.y - y


## v est dimensionnée sur l'arc extérieur (le plus long).
func size_m() -> Vector2:
	return Vector2(r1 - r0, r1 * angle_rad)


func area() -> float:
	return 0.5 * (r1 * r1 - r0 * r0) * angle_rad


func texel_area(x: int, _y: int, width: int, height: int) -> float:
	var dr: float = (r1 - r0) / float(width)
	var ra: float = r0 + float(x) * dr
	var rb: float = ra + dr
	return 0.5 * (rb * rb - ra * ra) * angle_rad / float(height)


func radius_to_uv(uv: Vector2, radius_m: float) -> Vector2:
	var r: float = maxf(r0 + uv.x * (r1 - r0), 0.001)
	var demi_angle: float = asin(radius_m / r) if radius_m < r else PI
	return Vector2(radius_m / (r1 - r0), demi_angle / angle_rad)


func projection(module_xform: Transform3D) -> SurfaceMapping.WorldProjection:
	return SurfaceMapping.plane_projection(module_xform.basis * Vector3.UP, tuile_m)
