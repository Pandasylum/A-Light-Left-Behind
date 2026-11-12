extends SceneTree
## Essai du voile de fin de surface sur cleaning_tour.tscn : un mur, un panneau de noyau, une marche.
## Lancement (rendu requis, pas --headless) :
##   godot --path game --rendering-driver opengl3 --resolution 480x720 --script res://tests/test_fin_surface/essai_balayage.gd -- <dossier de sortie>
## Écrit une planche PNG par cas (progress 0,25 / 0,4 / 0,55 / 0,75) et vérifie : continuité de l'abscisse à
## l'arête dessus/contremarche, image à progress = 1 identique à l'image sans voile.

const TOUR: String = "res://tests/test_cleaning/cleaning_tour.tscn"
const PEAK: float = 0.5 # fort, pour que le voile se lise sur les captures (réglage de jeu : 0,12)
const STEPS: Array[float] = [0.25, 0.4, 0.55, 0.75] # 0,4 : le centre du voile passe l'arête de la marche

var _out_dir: String = "/tmp/essai_balayage"
var _tour: Node
var _camera: Camera3D


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _run() -> void:
	_tour = (load(TOUR) as PackedScene).instantiate()
	root.add_child(_tour)
	_camera = Camera3D.new()
	_camera.fov = 60.0
	root.add_child(_camera)
	_camera.current = true
	var hud: CanvasLayer = _tour.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false # le HUD (FPS, mesures) change à chaque image
	for _i: int in 5:
		await process_frame
	var failures: int = 0
	var cases: Array[Dictionary] = [
		{"name": "mur", "surface": "Mur1_3", "view": "wall"},
		{"name": "noyau", "surface": "Noyau1_P1", "view": "core"},
		{"name": "marche", "surface": "Marche10", "view": "step"},
	]
	for c: Dictionary in cases:
		var surface: CleaningSurface = _tour.get_node("Surfaces/" + String(c["surface"])) as CleaningSurface
		if surface == null:
			print("ABSENTE : ", c["surface"])
			failures += 1
			continue
		failures += await _case(c, surface)
	print("essai_balayage : ", "OK" if failures == 0 else "%d ECHEC(S)" % failures)
	quit(failures)


func _case(c: Dictionary, surface: CleaningSurface) -> int:
	var faces: Array[CleanableFace] = surface.faces
	var sweep: Dictionary = FinSurfaceSweep.compute(faces)
	var failures: int = 0
	print("--- %s (%s) : %d face(s)" % [c["name"], c["surface"], faces.size()])
	for face: CleanableFace in faces:
		print("   ", face.get_parent().name, "/", face.name, " ", sweep[face])
	_aim(String(c["view"]), faces)
	var materials: Array[ShaderMaterial] = []
	for face: CleanableFace in faces:
		var material: ShaderMaterial = FinSurfaceSweep.make_material(face, sweep[face], PEAK)
		materials.append(material)
	# image de référence, sans voile
	await _frames(3)
	var base: Image = _grab()
	var shots: Array[Image] = [base]
	for p: float in STEPS:
		_set_veil(faces, materials, p)
		await _frames(3)
		shots.append(_grab())
	_set_veil(faces, materials, 1.0)
	await _frames(3)
	var done: Image = _grab()
	var diff: int = _diff(base, done)
	print("   progress = 1 vs sans voile : %d pixel(s) différent(s)" % diff)
	if diff != 0:
		failures += 1
	_set_veil(faces, materials, 0.5)
	await _frames(3)
	var changed: int = _diff(base, _grab())
	print("   progress = 0,5 vs sans voile : %d pixel(s) différent(s)" % changed)
	if changed == 0:
		failures += 1
	for face: CleanableFace in faces:
		face.face_material().next_pass = null
	# planche : sans voile + 4 instants
	var w: int = base.get_width()
	var h: int = base.get_height()
	var sheet: Image = Image.create(w * shots.size(), h, false, Image.FORMAT_RGB8)
	for i: int in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	sheet.save_png("%s/%s.png" % [_out_dir, c["name"]])

	if String(c["view"]) == "step":
		failures += _check_step_edge(faces, sweep)
	return failures


func _set_veil(faces: Array[CleanableFace], materials: Array[ShaderMaterial], progress: float) -> void:
	for i: int in faces.size():
		materials[i].set_shader_parameter(&"progress", progress)
		faces[i].face_material().next_pass = materials[i]


## Continuité : l'arête commune dessus/contremarche a la même abscisse des deux côtés.
func _check_step_edge(faces: Array[CleanableFace], sweep: Dictionary) -> int:
	var riser: CleanableFace = null
	var tread: CleanableFace = null
	for face: CleanableFace in faces:
		if face.mapping is SectorMapping:
			tread = face
		else:
			riser = face
	if riser == null or tread == null:
		return 1
	var failures: int = 0
	var worst: float = 0.0
	for r: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var top: Vector3 = riser.global_transform * riser.mapping.point_at(Vector2(r, 0.0)) # haut de la contremarche
		var s_riser: float = FinSurfaceSweep.abscissa(sweep[riser], top)
		var edge: Vector3 = tread.global_transform * tread.mapping.point_at(Vector2(r, 1.0)) # arête du dessus
		var s_tread: float = FinSurfaceSweep.abscissa(sweep[tread], edge)
		worst = maxf(worst, absf(s_riser - s_tread))
	print("   écart d'abscisse à l'arête (5 points) : %.6f m" % worst)
	if worst > 0.0005:
		failures += 1
	var length: float = float(sweep[riser][&"balayage_longueur"])
	var s_top_far: float = FinSurfaceSweep.abscissa(sweep[tread], tread.global_transform * tread.mapping.point_at(Vector2(0.5, 0.0)))
	print("   longueur du chemin %.4f m ; abscisse du bord arrière du dessus %.4f m" % [length, s_top_far])
	if absf(s_top_far - length) > 0.002:
		failures += 1
	return failures


func _aim(view: String, faces: Array[CleanableFace]) -> void:
	var center: Vector3 = Vector3.ZERO
	for face: CleanableFace in faces:
		center += face.global_transform * face.mapping.point_at(Vector2(0.5, 0.5))
	center /= float(faces.size())
	var radial: Vector3 = Vector3(center.x, 0.0, center.z).normalized()
	match view:
		"wall":
			_camera.global_position = center - radial * 1.3
		"core":
			_camera.global_position = center + radial * 1.3
		"step":
			var a: float = atan2(-center.z, center.x) - 0.55
			_camera.global_position = Vector3(1.8 * cos(a), center.y + 0.5, -1.8 * sin(a))
	_camera.look_at(center, Vector3.UP)


func _grab() -> Image:
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	return image


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _diff(a: Image, b: Image) -> int:
	var n: int = 0
	var da: PackedByteArray = a.get_data()
	var db: PackedByteArray = b.get_data()
	for i: int in mini(da.size(), db.size()):
		if da[i] != db[i]:
			n += 1
	return n
