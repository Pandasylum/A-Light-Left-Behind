extends SceneTree
## Test du nettoyage localisé (spike P2-N1) + mesures chiffrées.
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_cleaning.gd

const Spike := preload("res://tests/test_cleaning/cleaning_spike.gd")
const SPIKE_SCENE: String = "res://tests/test_cleaning/cleaning_spike.tscn"
const RADIUS: float = 0.15

var _failures: int = 0
var _spike: Node3D
var _faces: Array[CleanableFace] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_rng.seed = 20261111
	var defs: Dictionary = Spike.module_defs()
	_test_mappings(defs)
	_test_glb_uv2(defs)
	_test_generated(defs)

	_spike = (load(SPIKE_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(_spike)
	_faces.assign(_spike.get("faces"))
	_check(_faces.size() == 31, "assemblage : 31 faces nettoyables (trouvé %d)" % _faces.size())
	var generated: PackedStringArray = _spike.get("generated")
	var notes: PackedStringArray = _spike.get("notes")
	print("Modules : ", ".glb" if generated.is_empty() else "GÉNÉRÉS PAR CODE : " + ", ".join(generated))
	_check(notes.is_empty(), "conventions des modules : " + " ; ".join(notes))

	_test_default_dirty()
	_test_parity()
	_test_weights()
	_test_strokes()
	_test_finish()
	_test_save()
	_measure_save()

	print("test_cleaning : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _face(path: String) -> CleanableFace:
	return _spike.get_node("Assemblage/" + path) as CleanableFace


# --- Correspondances ---

func _test_mappings(defs: Dictionary) -> void:
	for kind: String in defs:
		for face_def: Dictionary in defs[kind]["faces"]:
			var mapping: SurfaceMapping = face_def["mapping"]
			var label: String = "%s/%s" % [kind, face_def["name"]]
			var uv_error: float = 0.0
			var depth_error: float = 0.0
			for j: int in 9:
				for i: int in 9:
					var uv: Vector2 = Vector2(i / 8.0, j / 8.0)
					var point: Vector3 = mapping.point_at(uv)
					var back: Vector2 = mapping.uv_at(point)
					uv_error = maxf(uv_error, maxf(absf(back.x - uv.x), absf(back.y - uv.y)))
					depth_error = maxf(depth_error, absf(mapping.depth_at(point)))
					var again: Vector3 = mapping.point_at(back)
					uv_error = maxf(uv_error, again.distance_to(point))
			_check(uv_error < 1e-5, "%s : aller-retour point -> uv -> point (écart %.8f)" % [label, uv_error])
			_check(depth_error < 1e-5, "%s : profondeur nulle sur la face (écart %.8f)" % [label, depth_error])
			# Somme des aires de texels = aire de la face.
			var size: Vector2i = mapping.grid_size(64.0)
			var total: float = 0.0
			for y: int in size.y:
				for x: int in size.x:
					total += mapping.texel_area(x, y, size.x, size.y)
			_check(absf(total - mapping.area()) < 1e-9 * maxf(1.0, mapping.area()), "%s : somme des aires de texels = aire de la face" % label)
			# radius_to_uv majore l'étendue de la sphère du pinceau.
			var center_uv: Vector2 = Vector2(0.37, 0.61)
			var center: Vector3 = mapping.point_at(center_uv)
			var ext: Vector2 = mapping.radius_to_uv(center_uv, RADIUS)
			var covered: bool = true
			for y: int in size.y:
				for x: int in size.x:
					var uv: Vector2 = Vector2((x + 0.5) / size.x, (y + 0.5) / size.y)
					if mapping.point_at(uv).distance_to(center) < RADIUS \
							and (absf(uv.x - center_uv.x) > ext.x + 1e-6 or absf(uv.y - center_uv.y) > ext.y + 1e-6):
						covered = false
			_check(covered, "%s : radius_to_uv couvre tout le pinceau" % label)


## UV2 réelle des sommets des .glb contre uv_at ; écart au centre des triangles (facettes).
func _test_glb_uv2(defs: Dictionary) -> void:
	for kind: String in defs:
		var path: String = Spike.MODULES_DIR + String(defs[kind]["file"])
		if not ResourceLoader.exists(path):
			print("UV2 .glb : %s ABSENT, comparaison non faite" % path)
			continue
		var module: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		var found: Array[Node] = module.find_children("*", "MeshInstance3D", true, false)
		var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else (module as MeshInstance3D).mesh
		for face_def: Dictionary in defs[kind]["faces"]:
			var mapping: SurfaceMapping = face_def["mapping"]
			var surface: int = face_def["surface"]
			var label: String = "%s/%s" % [kind, face_def["name"]]
			var material: Material = mesh.surface_get_material(surface)
			_check(material != null and material.resource_name == face_def["material"],
					"%s : emplacement %d = %s" % [label, surface, face_def["material"]])
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			_check(uv2.size() == vertices.size() and not vertices.is_empty(), "%s : UV2 présente" % label)
			if uv2.size() != vertices.size():
				continue
			var vertex_error: float = 0.0
			var depth_error: float = 0.0
			for i: int in vertices.size():
				var uv: Vector2 = mapping.uv_at(vertices[i])
				vertex_error = maxf(vertex_error, maxf(absf(uv.x - uv2[i].x), absf(uv.y - uv2[i].y)))
				depth_error = maxf(depth_error, absf(mapping.depth_at(vertices[i])))
			_check(vertex_error < 1e-4, "%s : UV2 des sommets = uv_at (écart %.8f)" % [label, vertex_error])
			_check(depth_error < 1e-4, "%s : sommets sur la surface analytique (écart %.8f m)" % [label, depth_error])
			var size: Vector2i = mapping.grid_size(64.0)
			var facet_texels: float = 0.0
			var facet_depth: float = 0.0
			for t: int in range(0, indices.size(), 3):
				var a: int = indices[t]
				var b: int = indices[t + 1]
				var c: int = indices[t + 2]
				for weights: Vector3 in [Vector3(1, 1, 1) / 3.0, Vector3(0.5, 0.5, 0.0), Vector3(0.5, 0.0, 0.5), Vector3(0.0, 0.5, 0.5)]:
					var point: Vector3 = vertices[a] * weights.x + vertices[b] * weights.y + vertices[c] * weights.z
					var interpolated: Vector2 = uv2[a] * weights.x + uv2[b] * weights.y + uv2[c] * weights.z
					var analytic: Vector2 = mapping.uv_at(point)
					facet_texels = maxf(facet_texels, maxf(absf(analytic.x - interpolated.x) * size.x, absf(analytic.y - interpolated.y) * size.y))
					facet_depth = maxf(facet_depth, absf(mapping.depth_at(point)))
			print("UV2 .glb %s : sommets %.8f ; facettes : %.3f texel, %.2f mm de flèche" % [label, vertex_error, facet_texels, facet_depth * 1000.0])
			# Mesure, pas un échec : l'UV2 interpolée dans les triangles n'est pas la correspondance analytique.
			if facet_texels >= 0.5:
				print("  ATTENTION %s : l'état affiché est décalé jusqu'à %.2f texels du point nettoyé (UV2 non affine sur les triangles)" % [label, facet_texels])
		module.free()


func _test_generated(defs: Dictionary) -> void:
	var face_defs: Array = defs["marche"]["faces"]
	var mesh: ArrayMesh = Spike.generate_mesh(face_defs)
	_check(mesh.get_surface_count() == face_defs.size(), "repli par code : une surface par face")
	for s: int in mesh.get_surface_count():
		var mapping: SurfaceMapping = face_defs[s]["mapping"]
		var arrays: Array = mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var error: float = 0.0
		for i: int in vertices.size():
			var uv: Vector2 = mapping.uv_at(vertices[i])
			error = maxf(error, maxf(absf(uv.x - uv2[i].x), absf(uv.y - uv2[i].y)))
		_check(error < 1e-5 and not vertices.is_empty(), "repli par code : UV2 = uv_at (surface %d)" % s)
		_check(tangents.size() == vertices.size() * 4, "repli par code : tangentes générées (surface %d)" % s)
		var a: Vector3 = vertices[indices[0]]
		var b: Vector3 = vertices[indices[1]]
		var c: Vector3 = vertices[indices[2]]
		_check((c - a).cross(b - a).dot(mapping.normal_at(Vector2.ZERO)) > 0.0, "repli par code : faces orientées vers la normale (surface %d)" % s)


# --- Défaut = sale ---

func _test_default_dirty() -> void:
	var face: CleanableFace = _face("Mur1_5/FaceMur")
	_check(not face.has_fine_grid(), "défaut : aucune grille fine avant le premier contact")
	_check(face.face_material().get_shader_parameter(&"etat") == null, "défaut : aucun masque d'état (noir = sale)")
	_check(is_equal_approx(face.cleanliness(), 0.0) and not face.is_finished(), "défaut : propreté 0, non finie")
	_check(face.export_state(_spike).is_empty(), "défaut : face intacte absente de la sauvegarde")
	_check(face.import_state({}), "défaut : clé absente acceptée")
	face.ensure_fine_grid()
	_check(_all_equal(face.state_buffer(0), 0.0) and _all_equal(face.state_buffer(1), 0.0), "défaut : tampons à 0")
	_check(face.state_bytes().count(0) == face.state_bytes().size(), "défaut : copie GPU à 0")
	_check(is_equal_approx(face.remaining_dirty_area(), face.initial_dirty_area()) and face.initial_dirty_area() > 0.0, "défaut : reste = aire sale initiale")
	_check(face.face_material().get_shader_parameter(&"etat") is ImageTexture, "premier contact : masque d'état créé")
	var size: Vector2i = face.grid_size()
	_check(size == Vector2i(34, 139), "mur : grille 34 x 139 (trouvé %s)" % size)


# --- Parité CPU / GPU de la projection (formule seulement) ---

## Transcription de la projection de fragment() à partir des uniforms réellement écrits.
func _shader_uv_monde(material: ShaderMaterial, pos: Vector3) -> Vector2:
	var tile: float = material.get_shader_parameter(&"proj_tuile_m")
	if int(material.get_shader_parameter(&"proj_mode")) == 1:
		var axis: Vector2 = material.get_shader_parameter(&"proj_axe_xz")
		var q: Vector2 = Vector2(pos.x - axis.x, -(pos.z - axis.y))
		var k: float = float(material.get_shader_parameter(&"proj_rayon_ref")) / tile
		return Vector2(atan2(q.y, q.x) * k, pos.y / tile)
	var axe_u: Vector3 = material.get_shader_parameter(&"proj_axe_u")
	var axe_v: Vector3 = material.get_shader_parameter(&"proj_axe_v")
	return Vector2(pos.dot(axe_u), pos.dot(axe_v)) / tile


func _test_parity() -> void:
	var worst: float = 0.0
	for face: CleanableFace in _faces:
		var material: ShaderMaterial = face.face_material()
		for n: int in 64:
			var world: Vector3 = face.global_transform * face.mapping.point_at(Vector2(_rng.randf(), _rng.randf()))
			var cpu: Vector2 = face.world_projection().uv_monde(world)
			var gpu: Vector2 = _shader_uv_monde(material, world)
			worst = maxf(worst, maxf(absf(cpu.x - gpu.x), absf(cpu.y - gpu.y)))
		_check(is_equal_approx(float(material.get_shader_parameter(&"epsilon")), face.params.epsilon), "parité : epsilon du shader = CleaningParams")
	print("Parité CPU/GPU de la projection (formule, mêmes paramètres) : écart max %.9f uv" % worst)
	_check(worst < 1e-6, "parité de la projection CPU / shader")
	var wall: SurfaceMapping.WorldProjection = _face("Mur0_0/FaceMur").world_projection()
	var core: SurfaceMapping.WorldProjection = _face("Noyau0/FaceNoyau").world_projection()
	_check(wall.mode == SurfaceMapping.Mode.CYLINDRE and core.mode == SurfaceMapping.Mode.CYLINDRE, "mur et noyau : projection cylindrique")
	_check(is_equal_approx(wall.tuile_m, core.tuile_m) and absf(wall.tuile_m - 1.0472) < 1e-4, "mur (N = 12) et noyau (N = 3) : même tuile de 1,047 m")
	_check(_face("Marche3/FaceDessus").world_projection().axe_v == Vector3.BACK, "dessus de marche : projection XZ monde")
	var riser0: SurfaceMapping.WorldProjection = _face("Marche0/FaceContremarche").world_projection()
	var riser5: SurfaceMapping.WorldProjection = _face("Marche5/FaceContremarche").world_projection()
	_check(riser0.axe_u == Vector3.RIGHT and riser5.axe_u == Vector3.BACK, "contremarches : plan choisi par l'axe dominant de la normale")
	# Continuité entre modules voisins : même uv_monde sur l'arête commune.
	var edge_a: Vector3 = _face("Mur0_0/FaceMur").global_transform * _face("Mur0_0/FaceMur").mapping.point_at(Vector2(1.0, 0.3))
	var edge_b: Vector3 = _face("Mur0_1/FaceMur").global_transform * _face("Mur0_1/FaceMur").mapping.point_at(Vector2(0.0, 0.3))
	_check(edge_a.distance_to(edge_b) < 1e-4, "assemblage : arête commune de deux tronçons de mur")
	var seam: Vector2 = wall.uv_monde(edge_a) - _face("Mur0_1/FaceMur").world_projection().uv_monde(edge_b)
	_check(seam.length() < 1e-4, "projection continue à la couture de deux tronçons de mur")


# --- Poids (mesure) ---

func _test_weights() -> void:
	var coarse_total: float = 0.0
	var fine_total: float = 0.0
	var area_total: float = 0.0
	var coarse_usec: int = 0
	var fine_usec: int = 0
	var fine_max_usec: int = 0
	var by_kind: Dictionary = {}
	for face: CleanableFace in _faces:
		var coarse: float = face.initial_dirty_area_coarse()
		face.ensure_fine_grid()
		var fine: float = face.initial_dirty_area()
		_check(face.has_fine_grid() and fine > 0.0 and fine <= 2.0 * face.face_area() + 1e-9, "poids : aire sale fine dans [0, 2 x aire] (%s)" % face.get_path())
		coarse_total += coarse
		fine_total += fine
		area_total += face.face_area()
		coarse_usec += face.coarse_init_usec
		fine_usec += face.fine_grid_usec
		fine_max_usec = maxi(fine_max_usec, face.fine_grid_usec)
		if not by_kind.has(face.name):
			by_kind[face.name] = face
	print("Poids par type de face (aire ; aire sale initiale grossière 16/m ; fine 64/m ; écart relatif ; grille ; durées) :")
	for key: StringName in by_kind:
		var face: CleanableFace = by_kind[key]
		var coarse: float = face.initial_dirty_area_coarse()
		var fine: float = face.initial_dirty_area()
		print("  %-18s %.4f m² ; %.4f ; %.4f ; %+.2f %% ; %dx%d ; grossier %.2f ms, fine %.2f ms" % [key, face.face_area(), coarse, fine,
				(coarse - fine) / fine * 100.0, face.grid_size().x, face.grid_size().y, face.coarse_init_usec / 1000.0, face.fine_grid_usec / 1000.0])
	print("Assemblage : aire %.3f m² ; aire sale grossière %.4f ; fine %.4f ; écart relatif %+.2f %%" % [
			area_total, coarse_total, fine_total, (coarse_total - fine_total) / fine_total * 100.0])
	print("Durée d'initialisation de l'assemblage : %.1f ms (dont poids grossiers %.1f ms pour %d faces)" % [
			int(_spike.get("init_usec")) / 1000.0, coarse_usec / 1000.0, _faces.size()])
	print("Durée des grilles fines : total %.1f ms pour %d faces ; plus lente %.1f ms" % [fine_usec / 1000.0, _faces.size(), fine_max_usec / 1000.0])
	_check(absf(coarse_total - fine_total) / fine_total < 0.1, "poids : écart grossier / fin de l'assemblage < 10 %")


# --- Gestes : monotonie, bornes, compteur incrémental ---

func _random_stroke(face: CleanableFace, amount: float, span: float = 1.0) -> bool:
	var uv_a: Vector2 = Vector2(_rng.randf(), _rng.randf())
	var uv_b: Vector2 = uv_a + Vector2(_rng.randf_range(-span, span), _rng.randf_range(-span, span))
	var xform: Transform3D = face.global_transform
	return face.clean_stroke(xform * face.mapping.point_at(uv_a), xform * face.mapping.point_at(uv_b.clampf(0.0, 1.0)), RADIUS, amount)


func _check_counters(face: CleanableFace, label: String) -> void:
	var counted: Dictionary = face.recount()
	var areas: PackedFloat64Array = counted["aire"]
	var texels: PackedInt32Array = counted["texels"]
	for layer: int in face.channels:
		_check(face.remaining_texels(layer) == texels[layer], "%s : compteur de texels incrémental = recalcul (couche %d : %d / %d)" % [
				label, layer, face.remaining_texels(layer), texels[layer]])
		_check(absf(face.remaining_area(layer) - areas[layer]) <= 1e-9 * maxf(1.0, areas[layer]), "%s : aire restante incrémentale = recalcul (couche %d)" % [label, layer])


func _test_strokes() -> void:
	for path: String in ["MurDroit/FaceMurDroit", "Mur0_0/FaceMur", "Noyau0/FaceNoyau", "Marche0/FaceDessus", "Marche0/FaceContremarche"]:
		var face: CleanableFace = _face(path)
		var monotone: bool = true
		var bounded: bool = true
		var bytes_ok: bool = true
		var previous: Array[PackedFloat32Array] = [face.state_buffer(0).duplicate(), face.state_buffer(1).duplicate()]
		for n: int in 24:
			_random_stroke(face, _rng.randf_range(0.05, 3.0), 0.5)
			var bytes: PackedByteArray = face.state_bytes()
			for layer: int in 2:
				var state: PackedFloat32Array = face.state_buffer(layer)
				var before: PackedFloat32Array = previous[layer]
				for i: int in state.size():
					var s: float = state[i]
					if s < before[i]:
						monotone = false
					if s < 0.0 or s > 1.0:
						bounded = false
					if bytes[i * 2 + layer] != roundi(s * 255.0):
						bytes_ok = false
				previous[layer] = state.duplicate()
			if n % 8 == 7:
				_check_counters(face, path)
		_check(monotone, "%s : la propreté ne diminue jamais" % path)
		_check(bounded, "%s : propreté dans [0, 1]" % path)
		_check(bytes_ok, "%s : copie GPU = tampon flottant arrondi" % path)
		_check(face.cleanliness() > 0.0 and face.cleanliness() <= 1.0, "%s : propreté pondérée dans ]0, 1]" % path)
	# Gestes sans effet.
	var wall: CleanableFace = _face("Mur1_4/FaceMur")
	var center: Vector3 = wall.global_transform * wall.mapping.point_at(Vector2(0.5, 0.5))
	_check(not wall.clean_stroke(center, center, RADIUS, -1.0) and not wall.clean_stroke(center, center, 0.0, 1.0)
			and not wall.clean_stroke(center, center, RADIUS, 0.0), "quantité ou rayon nuls ou négatifs : aucun effet")
	_check(not wall.clean_stroke(center + Vector3(0, 10, 0), center + Vector3(0, 10, 0), RADIUS, 1.0), "geste hors de portée : aucun effet")
	_check(_all_equal(wall.state_buffer(0), 0.0), "gestes sans effet : état inchangé")
	# Masque de couches.
	_check(wall.clean_stroke(center, center, RADIUS, 0.5, 0b01), "geste sur la couche saleté seule")
	_check(not _all_equal(wall.state_buffer(0), 0.0) and _all_equal(wall.state_buffer(1), 0.0), "couche mousse intacte quand seule la saleté est visée")
	_check_counters(wall, "Mur1_4")
	# Tampons interpolés : un geste long ne laisse pas de trou le long du segment.
	var long_wall: CleanableFace = _face("Mur1_3/FaceMur")
	var from: Vector3 = long_wall.global_transform * long_wall.mapping.point_at(Vector2(0.5, 0.1))
	var to: Vector3 = long_wall.global_transform * long_wall.mapping.point_at(Vector2(0.5, 0.9))
	long_wall.clean_stroke(from, to, RADIUS, 1000.0)
	var gaps: int = 0
	var size: Vector2i = long_wall.grid_size()
	var column: PackedFloat32Array = long_wall.state_buffer(0)
	for y: int in range(int(size.y * 0.15), int(size.y * 0.9)):
		if column[y * size.x + (size.x >> 1)] < 1.0:
			gaps += 1
	_check(gaps == 0, "tampons interpolés : aucun trou le long d'un geste de 1,7 m (%d trous)" % gaps)
	# Couture : un geste sur l'arête commune touche les deux faces voisines.
	var left: CleanableFace = _face("Mur1_0/FaceMur")
	var right: CleanableFace = _face("Mur1_1/FaceMur")
	var edge: Vector3 = left.global_transform * left.mapping.point_at(Vector2(1.0, 0.5))
	_check(left.clean_stroke(edge, edge, RADIUS, 1.0) and right.clean_stroke(edge, edge, RADIUS, 1.0), "couture : le geste sur l'arête nettoie les deux faces voisines")
	# Durées.
	var target: CleanableFace = _face("MurDroit/FaceMurDroit")
	target.import_state({}) # repart d'une face sale : chaque geste modifie des texels
	var point: Vector3 = target.global_transform * target.mapping.point_at(Vector2(0.5, 0.5))
	var far: Vector3 = target.global_transform * target.mapping.point_at(Vector2(0.75, 0.5))
	var t0: int = Time.get_ticks_usec()
	for n: int in 50:
		target.clean_stroke(point, point, RADIUS, 0.001)
	var single_usec: float = (Time.get_ticks_usec() - t0) / 50.0
	t0 = Time.get_ticks_usec()
	for n: int in 50:
		target.clean_stroke(point, far, RADIUS, 0.001)
	var segment_usec: float = (Time.get_ticks_usec() - t0) / 50.0
	t0 = Time.get_ticks_usec()
	for n: int in 50:
		for face: CleanableFace in _faces:
			face.clean_stroke(point, point, RADIUS, 0.001)
	var all_usec: float = (Time.get_ticks_usec() - t0) / 50.0
	print("Durée d'un clean_stroke (mur droit 128x139, rayon 0,15 m, envoi GPU compris) : 1 tampon %.3f ms ; segment de 0,5 m (7 tampons) %.3f ms ; 1 tampon proposé aux 31 faces %.3f ms" % [
			single_usec / 1000.0, segment_usec / 1000.0, all_usec / 1000.0])


# --- Fin de geste ---

func _test_finish() -> void:
	var face: CleanableFace = _face("Marche1/FaceContremarche")
	var emitted: Array[int] = [0]
	face.finished.connect(func() -> void: emitted[0] += 1)
	var xform: Transform3D = face.global_transform
	var last_ratio: float = face.remaining_ratio()
	var steps: int = 0
	while not face.is_finished() and steps < 400:
		last_ratio = face.remaining_ratio()
		var point: Vector3 = xform * face.mapping.point_at(Vector2(steps * 0.01, 0.5))
		face.clean_stroke(point, point, RADIUS, 5.0)
		steps += 1
	_check(face.is_finished(), "fin de geste : déclenchée quand le reste <= tau")
	print("Fin de geste : déclenchée après %d tampons ; reste juste avant %.2f %% (tau = %.0f %%)" % [steps, last_ratio * 100.0, face.params.tau * 100.0])
	_check(last_ratio > face.params.tau, "fin de geste : pas avant tau")
	_check(emitted[0] == 1, "fin de geste : signal finished émis une fois")
	_check(face.is_fading(), "fin de geste : fondu en cours")
	_check(_all_equal(face.state_buffer(0), 1.0) and _all_equal(face.state_buffer(1), 1.0), "fin de geste : état écrit propre dès le déclenchement (persistant)")
	face.advance_fade(face.params.duree_fondu * 0.5)
	var mid: float = face.face_material().get_shader_parameter(&"fondu")
	_check(face.is_fading() and absf(mid - 0.5) < 1e-3, "fin de geste : fondu à mi-course après 0,25 s (%.3f)" % mid)
	face.advance_fade(face.params.duree_fondu * 0.6)
	_check(not face.is_fading() and is_zero_approx(float(face.face_material().get_shader_parameter(&"fondu"))), "fin de geste : fondu terminé")
	_check(_all_equal(face.state_buffer(0), 1.0) and _all_equal(face.state_buffer(1), 1.0), "fin de geste : état entièrement propre après le fondu")
	_check(face.state_bytes().count(255) == face.state_bytes().size(), "fin de geste : copie GPU entièrement propre")
	_check(is_equal_approx(face.cleanliness(), 1.0) and is_zero_approx(face.remaining_dirty_area()), "fin de geste : propreté 1, reste 0")
	var point: Vector3 = xform * face.mapping.point_at(Vector2(0.5, 0.5))
	_check(not face.clean_stroke(point, point, RADIUS, 1.0), "face finie : geste sans effet")
	# Une face finie se recharge finie, sans fondu.
	var entry: Dictionary = face.export_state(_spike)
	_check(face.import_state(entry) and face.is_finished() and not face.is_fading(), "face finie : rechargée finie, sans fondu")


# --- Sauvegarde ---

func _packed(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes.compress(CleanableFace.COMPRESSION))


func _is_dirty(face: CleanableFace) -> bool:
	return face.state_bytes().count(0) == face.state_bytes().size() and _all_equal(face.state_buffer(0), 0.0) \
			and _all_equal(face.state_buffer(1), 0.0) and is_equal_approx(face.cleanliness(), 0.0) and not face.is_finished()


func _test_save() -> void:
	var face: CleanableFace = _face("Mur0_2/FaceMur")
	for n: int in 12:
		_random_stroke(face, _rng.randf_range(0.2, 3.0), 0.4)
	var entry: Dictionary = face.export_state(_spike)
	_check(entry.get("id") == "Assemblage/Mur0_2/FaceMur", "sauvegarde : id = chemin depuis la racine de la pièce (%s)" % entry.get("id"))
	_check(entry.get("largeur") == 34 and entry.get("hauteur") == 139 and entry.get("canaux") == 2, "sauvegarde : largeur, hauteur, canaux")
	_check(not entry.has("poids") and entry.size() == 5, "sauvegarde : le poids n'est pas sauvegardé")
	var bytes_before: PackedByteArray = face.state_bytes().duplicate()
	var ratio_before: float = face.remaining_ratio()
	var parsed: Variant = JSON.parse_string(JSON.stringify(entry)) # comme le SaveService (JSON)
	_check(parsed is Dictionary, "sauvegarde : entrée sérialisable en JSON")
	_check(face.import_state({}) and _is_dirty(face), "sauvegarde : clé absente = sale")
	_check(face.import_state(parsed), "sauvegarde : aller-retour accepté")
	_check(face.state_bytes() == bytes_before, "sauvegarde : aller-retour identique à l'octet")
	_check(face.export_state(_spike)["donnees"] == entry["donnees"], "sauvegarde : ré-export identique")
	_check_counters(face, "après chargement")
	print("Sauvegarde : reste avant %.4f %% ; après rechargement (état quantifié sur 8 bits) %.4f %%" % [ratio_before * 100.0, face.remaining_ratio() * 100.0])
	_check(absf(face.remaining_ratio() - ratio_before) < 0.01, "sauvegarde : reste conservé à 1 point près")
	var expected: int = 34 * 139 * 2
	var bad_cases: Dictionary = {
		"largeur corrompue": {"largeur": 35},
		"hauteur corrompue": {"hauteur": 138},
		"canaux corrompus": {"canaux": 1},
		"largeur et hauteur échangées": {"largeur": 139, "hauteur": 34},
		"largeur non numérique": {"largeur": "34"},
		"données absentes": {"donnees": null},
		"base64 invalide": {"donnees": "%%%pas du base64%%%"},
		"flux tronqué": {"donnees": Marshalls.raw_to_base64(Marshalls.base64_to_raw(entry["donnees"]).slice(0, 20))},
		"un octet en trop": {"donnees": _packed(bytes_before + PackedByteArray([7]))},
		"un octet en moins": {"donnees": _packed(bytes_before.slice(0, expected - 1))},
		"moitié des octets": {"donnees": _packed(bytes_before.slice(0, expected >> 1))},
		"double des octets": {"donnees": _packed(bytes_before + bytes_before)},
	}
	print("(les avertissements « état sauvegardé incohérent » qui suivent sont attendus)")
	for label: String in bad_cases:
		_check(face.import_state(parsed), "sauvegarde : état valide rechargé avant le cas « %s »" % label)
		var bad: Dictionary = (parsed as Dictionary).duplicate()
		bad.merge(bad_cases[label], true)
		if bad["donnees"] == null:
			bad.erase("donnees")
		_check(not face.import_state(bad) and _is_dirty(face), "sauvegarde : %s = face sale + avertissement" % label)
	# Pièce entière : aller-retour par id, clé absente = sale, entrée d'une autre taille rejetée.
	_check(face.import_state(parsed), "sauvegarde : état valide rechargé")
	var room: Dictionary = CleanableFace.export_room(_spike)
	_check(room.size() == _faces.size(), "sauvegarde de la pièce : une entrée par face touchée (%d)" % room.size())
	var snapshots: Dictionary = {}
	for other: CleanableFace in _faces:
		snapshots[other] = other.state_bytes().duplicate()
	var room_parsed: Dictionary = JSON.parse_string(JSON.stringify(room))
	room_parsed.erase("Assemblage/Mur0_0/FaceMur")
	room_parsed["Assemblage/Noyau0/FaceNoyau"] = room_parsed["Assemblage/MurDroit/FaceMurDroit"]
	var rejected: int = CleanableFace.import_room(_spike, room_parsed)
	_check(rejected == 1, "chargement de la pièce : une entrée rejetée (%d)" % rejected)
	_check(_is_dirty(_face("Mur0_0/FaceMur")), "chargement de la pièce : clé absente = sale")
	_check(_is_dirty(_face("Noyau0/FaceNoyau")), "chargement de la pièce : entrée d'une autre taille = sale")
	var identical: bool = true
	for other: CleanableFace in _faces:
		if other != _face("Mur0_0/FaceMur") and other != _face("Noyau0/FaceNoyau") and other.state_bytes() != snapshots[other]:
			identical = false
	_check(identical, "chargement de la pièce : les autres faces sont identiques à l'octet")


## Tailles de sauvegarde : état partiellement nettoyé sur toutes les faces (cas défavorable).
func _measure_save() -> void:
	for face: CleanableFace in _faces:
		if face.is_finished():
			continue
		if _is_dirty(face) or face.cleanliness() < 0.05:
			for n: int in 6:
				_random_stroke(face, _rng.randf_range(0.2, 3.0), 0.4)
	var by_kind: Dictionary = {}
	var raw_total: int = 0
	var zstd_total: int = 0
	var deflate_total: int = 0
	var base64_total: int = 0
	for face: CleanableFace in _faces:
		var raw: PackedByteArray = face.state_bytes()
		var packed: PackedByteArray = raw.compress(CleanableFace.COMPRESSION)
		var text: String = Marshalls.raw_to_base64(packed)
		raw_total += raw.size()
		zstd_total += packed.size()
		deflate_total += raw.compress(FileAccess.COMPRESSION_DEFLATE).size()
		base64_total += text.length()
		if not by_kind.has(face.name) and not face.is_finished():
			by_kind[face.name] = [face.grid_size(), raw.size(), packed.size(), text.length(), face.cleanliness()]
	print("Taille de sauvegarde par face (grille ; brut ; compressé zstd ; base64 ; propreté au moment de la mesure) :")
	for key: StringName in by_kind:
		var row: Array = by_kind[key]
		print("  %-18s %dx%d ; %d o ; %d o ; %d o ; %.0f %%" % [key, row[0].x, row[0].y, row[1], row[2], row[3], row[4] * 100.0])
	var json_size: int = JSON.stringify(CleanableFace.export_room(_spike)).length()
	print("Assemblage (%d faces, toutes partiellement nettoyées) : brut %d o ; zstd %d o (deflate %d o) ; base64 %d o ; JSON complet %d o" % [
			_faces.size(), raw_total, zstd_total, deflate_total, base64_total, json_size])
	# Borne basse : la même pièce entièrement finie.
	var clean: PackedByteArray = PackedByteArray()
	clean.resize(128 * 139 * 2)
	clean.fill(255)
	print("Repère : mur droit entièrement propre : brut %d o ; zstd %d o ; base64 %d o" % [
			clean.size(), clean.compress(CleanableFace.COMPRESSION).size(), _packed(clean).length()])


func _all_equal(values: PackedFloat32Array, expected: float) -> bool:
	if values.is_empty():
		return false
	for value: float in values:
		if value != expected:
			return false
	return true


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("ÉCHEC : ", label)
