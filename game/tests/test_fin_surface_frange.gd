extends SceneTree
## Mesure (NON OFFICIELLE) : frange propre laissée sur une face par un geste le long de ses limites
## avec un voisin, comparée à son seuil de fin. Affiche, n'échoue pas.
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_fin_surface_frange.gd

const RADIUS: float = 0.15 # m, BRUSH_RADIUS du spike
const DOSE: float = 100.0 # dose large du geste (comme la touche K du spike)
const PIECES: int = 24 # segments par limite, pour rester sur la surface
const CASES: Array = [
	{"scene": "res://tests/test_fin_surface/noyau_panneaux.tscn", "face": "Panneaux/Panneau1_1/FacePanneau", "limits": ["u0", "u1", "v0", "v1"]},
	{"scene": "res://tests/test_cleaning/cleaning_spike.tscn", "face": "", "limits": ["u0", "u1", "vtop"]},
]


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	for c: Dictionary in CASES:
		var spike: Node3D = (load(c["scene"]) as PackedScene).instantiate()
		root.add_child(spike)
		await process_frame
		var face: CleanableFace = _find(spike, c["face"])
		if face == null:
			print("face introuvable : ", c["scene"])
			continue
		var initial: float = face.initial_dirty_area()
		var limits: Array[String] = []
		for l: String in c["limits"]:
			limits.append(l)
		for l: String in limits:
			var pts: Array[Vector3] = _limit_points(face, l, limits)
			for i: int in range(pts.size() - 1):
				for f: CleanableFace in spike.faces:
					f.clean_stroke(pts[i], pts[i + 1], RADIUS, DOSE / float(pts.size() - 1))
		var remaining: float = face.remaining_dirty_area()
		var threshold: float = minf(0.5, 0.10 * face.face_area())
		print("== %s | %s" % [c["scene"].get_file(), face.get_path()])
		print("  limites : %s | grille fine : %s | aire face %.4f m²" % [limits, face.has_fine_grid(), face.face_area()])
		print("  initial %.4f m² | restant %.4f m² | enlevé %.1f %%" % [initial, remaining, 100.0 * (1.0 - remaining / initial) if initial > 0.0 else 0.0])
		print("  seuil %.4f m² | restant < seuil : %s | fini : %s" % [threshold, remaining < threshold, face.is_finished() if face.has_method("is_finished") else "?"])
		spike.free()
	quit(0)


func _find(spike: Node3D, path: String) -> CleanableFace:
	if path != "":
		return spike.get_node_or_null(path) as CleanableFace
	for f: CleanableFace in spike.faces:
		if f.get_parent().name == "Mur0_2":
			return f
	return null


## Points monde sur la surface le long d'une limite de la face ; "vtop" = bord de v au y monde le plus haut.
func _limit_points(face: CleanableFace, limit: String, limits: Array[String]) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var edge: float = 0.0
	var along_u: bool = false
	match limit:
		"u0": edge = 0.0
		"u1": edge = 1.0
		"v0": edge = 0.0; along_u = true
		"v1": edge = 1.0; along_u = true
		"vtop":
			along_u = true
			var y0: float = (face.global_transform * face.mapping.point_at(Vector2(0.5, 0.0))).y
			var y1: float = (face.global_transform * face.mapping.point_at(Vector2(0.5, 1.0))).y
			edge = 1.0 if y1 > y0 else 0.0
	for i: int in PIECES + 1:
		var t: float = float(i) / float(PIECES)
		var uv: Vector2 = Vector2(t, edge) if along_u else Vector2(edge, t)
		pts.append(face.global_transform * face.mapping.point_at(uv))
	return pts
