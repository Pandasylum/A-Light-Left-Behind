class_name FinSurfaceSweep
extends RefCounted
## Référence pour fin_surface.gdshader : calcule le « chemin de balayage » d'une surface à nettoyer
## d'après ses CleanableFace, et fabrique le matériau de voile de chaque face (next_pass).
## Chemin commun à toutes les faces d'une surface, abscisse en mètres :
##   - faces verticales (mur, panneau de noyau, contremarche) : hauteur monde à partir du bord bas ;
##   - dessus de marche (SectorMapping) : arc de cercle (rayon moyen) à partir de l'arête commune avec
##     la contremarche, abscisse décalée de la hauteur de la contremarche.
## Valeurs et méthode PROVISOIRES (Art, 2026-11-12). Utilisé par CleaningSurface pour le voile de fin.

const SHADER_PATH: String = "res://systems/cleaning/fin_surface.gdshader"


## Uniforms balayage_* de chaque face : { CleanableFace -> { nom d'uniform -> valeur } }.
static func compute(faces: Array[CleanableFace]) -> Dictionary:
	var y_low: float = INF
	var y_high: float = -INF
	var vertical_center: Vector3 = Vector3.ZERO
	var vertical_count: int = 0
	var tread: SectorMapping = null
	for face: CleanableFace in faces:
		if face.mapping is SectorMapping:
			tread = face.mapping as SectorMapping
			continue
		var xf: Transform3D = face.global_transform
		for v: float in [0.0, 1.0]:
			var y: float = (xf * face.mapping.point_at(Vector2(0.5, v))).y
			y_low = minf(y_low, y)
			y_high = maxf(y_high, y)
		vertical_center += xf * face.mapping.point_at(Vector2(0.5, 0.5))
		vertical_count += 1
	var height: float = (y_high - y_low) if vertical_count > 0 else 0.0
	var depth: float = 0.0
	if tread != null:
		depth = tread.angle_rad * 0.5 * (tread.r0 + tread.r1)
	var length: float = maxf(height + depth, 0.0001)
	if vertical_count > 0:
		vertical_center /= float(vertical_count)

	var out: Dictionary = {}
	for face: CleanableFace in faces:
		var p: Dictionary = {&"balayage_longueur": length}
		if face.mapping is SectorMapping:
			var sm: SectorMapping = face.mapping as SectorMapping
			var xf: Transform3D = face.global_transform
			var axis: Vector2 = Vector2(xf.origin.x, xf.origin.z)
			var edge_a: Vector3 = xf * sm.point_at(Vector2(0.5, 1.0)) # angle local 0
			var edge_b: Vector3 = xf * sm.point_at(Vector2(0.5, 0.0)) # angle local angle_rad
			var start: Vector3 = edge_a
			var other: Vector3 = edge_b
			if vertical_count > 0 and _flat_dist(edge_b, vertical_center) < _flat_dist(edge_a, vertical_center):
				start = edge_b
				other = edge_a
			var angle_start: float = _angle(start, axis)
			p[&"balayage_mode"] = 1
			p[&"balayage_axe_xz"] = axis
			p[&"balayage_angle0"] = angle_start
			p[&"balayage_sens"] = 1.0 if wrapf(_angle(other, axis) - angle_start, -PI, PI) >= 0.0 else -1.0
			p[&"balayage_rayon"] = 0.5 * (sm.r0 + sm.r1)
			p[&"balayage_decalage"] = height
		else:
			p[&"balayage_mode"] = 0
			p[&"balayage_y0"] = y_low
			p[&"balayage_decalage"] = 0.0
		out[face] = p
	return out


## Matériau de voile d'une face : balayage + projection monde de la pierre (edge_boost).
static func make_material(face: CleanableFace, sweep: Dictionary, peak: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_PATH) as Shader
	face.world_projection().apply_to(material)
	for key: StringName in sweep:
		material.set_shader_parameter(key, sweep[key])
	material.set_shader_parameter(&"progress", 0.0)
	material.set_shader_parameter(&"peak", peak)
	return material


## Abscisse (m) d'un point monde sur le chemin de la face : même formule que le shader.
static func abscissa(sweep: Dictionary, world_point: Vector3) -> float:
	if int(sweep[&"balayage_mode"]) == 1:
		var axis: Vector2 = sweep[&"balayage_axe_xz"]
		var a: float = (_angle(world_point, axis) - float(sweep[&"balayage_angle0"])) * float(sweep[&"balayage_sens"])
		a = wrapf(a, -PI, PI)
		return float(sweep[&"balayage_decalage"]) + a * float(sweep[&"balayage_rayon"])
	return float(sweep[&"balayage_decalage"]) + world_point.y - float(sweep[&"balayage_y0"])


static func _angle(p: Vector3, axis: Vector2) -> float:
	return atan2(-(p.z - axis.y), p.x - axis.x)


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
