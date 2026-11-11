class_name CylinderMapping
extends SurfaceMapping
## Tronçon de cylindre d'axe Y (mur : face intérieure ; noyau : face extérieure).
## angle = atan2(−z, x) de 0 à angle_rad ; u = angle / angle_rad ; v = 1 − y / hauteur.
## Projection monde : cylindre d'axe vertical passant par l'origine du module.

@export var rayon: float = 2.0 ## m
@export var angle_rad: float = deg_to_rad(15.0)
@export var hauteur: float = 2.16 ## m, PROVISOIRE
@export var vers_interieur: bool = true ## true : normale vers l'axe (mur) ; false : vers l'extérieur (noyau)
@export var tuiles_par_tour: int = 12 ## N entier : tuile_m = 2π·rayon / N (12 pour R = 2,0 ; 3 pour R = 0,5)


func uv_at(local: Vector3) -> Vector2:
	return Vector2(atan2(-local.z, local.x) / angle_rad, 1.0 - local.y / hauteur)


func point_at(uv: Vector2) -> Vector3:
	var a: float = uv.x * angle_rad
	return Vector3(rayon * cos(a), (1.0 - uv.y) * hauteur, -rayon * sin(a))


func normal_at(uv: Vector2) -> Vector3:
	var a: float = uv.x * angle_rad
	var sortante: Vector3 = Vector3(cos(a), 0.0, -sin(a))
	return -sortante if vers_interieur else sortante


func depth_at(local: Vector3) -> float:
	var d: float = Vector2(local.x, local.z).length() - rayon
	return -d if vers_interieur else d


func size_m() -> Vector2:
	return Vector2(rayon * angle_rad, hauteur)


func radius_to_uv(_uv: Vector2, radius_m: float) -> Vector2:
	# Corde -> angle : majorant de l'étendue angulaire de la sphère sur le cylindre.
	var demi_angle: float = 2.0 * asin(minf(1.0, radius_m / (2.0 * rayon)))
	return Vector2(demi_angle / angle_rad, radius_m / hauteur)


func tuile_m() -> float:
	return TAU * rayon / float(maxi(1, tuiles_par_tour))


func projection(module_xform: Transform3D) -> SurfaceMapping.WorldProjection:
	var p: SurfaceMapping.WorldProjection = SurfaceMapping.WorldProjection.new()
	p.mode = SurfaceMapping.Mode.CYLINDRE
	p.axe_xz = Vector2(module_xform.origin.x, module_xform.origin.z)
	# Vu de l'intérieur (mur), u = angle court vers la gauche : texture en miroir. Le signe de rayon_ref
	# inverse u de la projection seule (shader et CPU l'utilisent comme simple facteur) ; l'UV2 d'état, cuite
	# dans les .glb, ne change pas, et le côté extérieur (noyau) non plus.
	p.rayon_ref = -rayon if vers_interieur else rayon
	p.tuile_m = tuile_m()
	return p
