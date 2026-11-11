extends SceneTree
## Sens de u sur les faces courbes (défaut 2) : mur vu de l'intérieur, noyau vu de l'extérieur.
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_curved_wall.gd

const SPIKE: String = "res://tests/test_cleaning/cleaning_spike.tscn"

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var spike: Node3D = (load(SPIKE) as PackedScene).instantiate()
	root.add_child(spike)
	for path: String in ["Mur0_2/FaceMur", "Noyau2/FaceNoyau"]:
		_test_face(spike.get_node("Assemblage/" + path) as CleanableFace, path)
	spike.free()
	quit(1 if _failures > 0 else 0)


## Dérivée de f le long de la droite de l'observateur (haut = Y, regard = -normale) en un point de la face.
func _along_right(face: CleanableFace, uv: Vector2, f: Callable) -> float:
	var xform: Transform3D = face.global_transform
	var p: Vector3 = xform * face.mapping.point_at(uv)
	var normal: Vector3 = (xform.basis * face.mapping.normal_at(uv)).normalized()
	var right: Vector3 = (-normal).cross(Vector3.UP).normalized()
	var h: float = 1e-3
	return (f.call(p + right * h) - f.call(p - right * h)) / (2.0 * h)


func _test_face(face: CleanableFace, label: String) -> void:
	var mapping: CylinderMapping = face.mapping
	var xform: Transform3D = face.global_transform
	var proj: SurfaceMapping.WorldProjection = face.world_projection()
	# Parité : UV2 réelle des sommets (module .glb ou repli) = mapping analytique (uv_at du point local).
	var mesh: Mesh = face.mesh_instance.mesh
	var arrays: Array = mesh.surface_get_arrays(face.surface_index)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var worst: float = 0.0
	for i: int in vertices.size():
		var uv: Vector2 = mapping.uv_at(vertices[i])
		worst = maxf(worst, maxf(absf(uv.x - uv2[i].x), absf(uv.y - uv2[i].y)))
	_check(not vertices.is_empty() and worst < 1e-4, "%s : parité mapping analytique / UV2 de la face (écart %.7f)" % [label, worst])
	# Parité aller-retour du mapping analytique.
	var rt: float = 0.0
	for n: int in 32:
		var uv: Vector2 = Vector2(0.05 + 0.9 * n / 32.0, 0.1 + 0.8 * fmod(n * 0.37, 1.0))
		rt = maxf(rt, (mapping.uv_at(mapping.point_at(uv)) - uv).length())
	_check(rt < 1e-5, "%s : aller-retour uv_at/point_at (%.8f)" % [label, rt])
	# Sens de u pour l'observateur côté visible (+ : de gauche à droite, texture lisible).
	var uv_mid: Vector2 = Vector2(0.5, 0.5)
	var state_dir: float = _along_right(face, uv_mid, func(w: Vector3) -> float: return mapping.uv_at(xform.affine_inverse() * w).x)
	var tex_dir: float = _along_right(face, uv_mid, func(w: Vector3) -> float: return proj.uv_monde(w).x)
	print("%s : u état (UV2) vers la droite = %s ; u texture (projection) vers la droite = %s" % [label, state_dir > 0.0, tex_dir > 0.0])
	_check(tex_dir > 0.0, "%s : texture non inversée en miroir pour l'observateur côté visible" % label)
	# L'état (UV2) garde son sens : les .glb ne sont pas modifiés ; le sens affiché est celui de la projection.
	# Étirement : |d uv_monde / d position| · tuile = 1 le long de la face.
	var speed: float = absf(tex_dir) * proj.tuile_m
	_check(absf(speed - 1.0) < 0.02, "%s : u de la projection non étiré (%.4f)" % [label, speed])


func _check(ok: bool, label: String) -> void:
	print(("OK    " if ok else "ECHEC ") + label)
	if not ok:
		_failures += 1
