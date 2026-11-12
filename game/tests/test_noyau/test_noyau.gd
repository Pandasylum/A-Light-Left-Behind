extends Node3D
# Contrôle visuel des textures du noyau : cylindre r 0,5 m, h 2,16 m, 24 faces par anneau.
# UV : u = angle/360, v = 0 en bas (convention Blender). Dans Godot l'origine de l'image est
# en haut : uv.y = 1 - v. Aucune géométrie du projet n'est utilisée ni modifiée.
# Lancer avec F6, puis « Capturer les 8 vues » (PNG 1920x1080 dans tests/test_noyau/captures/).

const RACINE := "res://tests/test_noyau/"
const SORTIE := "res://tests/test_noyau/captures/"
const SORTIE_COMPRESSION := "res://tests/test_noyau/captures_compression/"
# Jeux de textures identiques (mêmes octets), importés différemment :
# sans = Lossless ; vram = VRAM Compressed (réglage Godot par défaut) ; vram_hq = VRAM + High Quality.
const JEUX := ["sans", "vram", "vram_hq"]
const DOSSIERS := {"sans": "tex/", "vram": "tex_vram/", "vram_hq": "tex_vram_hq/"}
const RAYON := 0.5
const HAUTEUR := 2.16
const FACES := 24
const HAUTEUR_CAMERA := 1.08
const DISTANCES := [0.9, 2.0]  # distance caméra - surface du noyau, en m
const ETATS := ["propre", "sale"]
const TAILLE_CAPTURE := Vector2i(1920, 1080)

var noyau: MeshInstance3D
var camera: Camera3D
var vue_capture: SubViewport
var camera_capture: Camera3D
var interface: CanvasLayer
var etiquette: Label
var mesh_lisse: ArrayMesh
var mesh_plat: ArrayMesh
var materiaux := {}
var i_distance := 0
var i_etat := 0
var i_jeu := 0
var lisse := true


func _ready() -> void:
	mesh_lisse = _construire(true)
	mesh_plat = _construire(false)
	for j in JEUX:
		materiaux[j] = {}
		for e in ETATS:
			materiaux[j][e] = _materiau(j, e)
	noyau = MeshInstance3D.new()
	add_child(noyau)
	noyau.position = Vector3(0, HAUTEUR * 0.5, 0)
	_monter_decor()
	_monter_interface()
	_appliquer()


func _normale(a: float) -> Vector3:
	return Vector3(sin(a), 0.0, cos(a))


func _sommet(st: SurfaceTool, a: float, y: float, n: Vector3, u: float, v_blender: float) -> void:
	st.set_normal(n)
	st.set_uv(Vector2(u, 1.0 - v_blender))
	st.add_vertex(Vector3(RAYON * sin(a), y - HAUTEUR * 0.5, RAYON * cos(a)))


func _construire(avec_lissage: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in FACES:
		var a0 := TAU * float(i) / FACES
		var a1 := TAU * float(i + 1) / FACES
		var am := (a0 + a1) * 0.5
		var n0 := _normale(a0) if avec_lissage else _normale(am)
		var n1 := _normale(a1) if avec_lissage else _normale(am)
		var u0 := float(i) / FACES
		var u1 := float(i + 1) / FACES
		# Vu de l'extérieur, u croît vers la droite. Sens horaire = face avant dans Godot.
		# Triangle 1 : haut-gauche, haut-droite, bas-droite.
		_sommet(st, a0, HAUTEUR, n0, u0, 1.0)
		_sommet(st, a1, HAUTEUR, n1, u1, 1.0)
		_sommet(st, a1, 0.0, n1, u1, 0.0)
		# Triangle 2 : haut-gauche, bas-droite, bas-gauche.
		_sommet(st, a0, HAUTEUR, n0, u0, 1.0)
		_sommet(st, a1, 0.0, n1, u1, 0.0)
		_sommet(st, a0, 0.0, n0, u0, 0.0)
	st.generate_tangents()
	return st.commit()


func _materiau(jeu: String, etat: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var dossier: String = RACINE + DOSSIERS[jeu]
	m.albedo_texture = load(dossier + "alb_" + etat + ".png")
	m.normal_enabled = true
	m.normal_texture = load(dossier + "pierre_normal.png")
	m.normal_scale = 1.0
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _monter_decor() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.10, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.52)
	env.ambient_light_energy = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Lumière rasante par le haut, légèrement de côté : un joint creux est sombre sur son
	# bord supérieur et clair sur son bord inférieur si la normal map est correcte.
	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-50, 20, 0)
	lumiere.light_energy = 1.2
	lumiere.shadow_enabled = false
	add_child(lumiere)
	camera = Camera3D.new()
	camera.fov = 60.0
	add_child(camera)
	camera.make_current()
	vue_capture = SubViewport.new()
	vue_capture.size = TAILLE_CAPTURE
	vue_capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vue_capture.msaa_3d = get_viewport().msaa_3d
	vue_capture.screen_space_aa = get_viewport().screen_space_aa
	vue_capture.use_taa = get_viewport().use_taa
	add_child(vue_capture)
	camera_capture = Camera3D.new()
	camera_capture.fov = 60.0
	vue_capture.add_child(camera_capture)


func _monter_interface() -> void:
	interface = CanvasLayer.new()
	add_child(interface)
	var boite := VBoxContainer.new()
	boite.position = Vector2(12, 12)
	interface.add_child(boite)
	etiquette = Label.new()
	boite.add_child(etiquette)
	_bouton(boite, "Distance (0,9 / 2,0 m)", _basculer_distance)
	_bouton(boite, "État (propre / sale)", _basculer_etat)
	_bouton(boite, "Shading (lissé / plat)", _basculer_shading)
	_bouton(boite, "Compression (sans / VRAM / VRAM HQ)", _basculer_jeu)
	_bouton(boite, "Capturer les 8 vues", _capturer_tout)
	_bouton(boite, "Capturer la comparaison de compression (12 vues)", _capturer_compression)


func _basculer_distance() -> void:
	i_distance = (i_distance + 1) % DISTANCES.size()
	_appliquer()


func _basculer_etat() -> void:
	i_etat = (i_etat + 1) % ETATS.size()
	_appliquer()


func _basculer_jeu() -> void:
	i_jeu = (i_jeu + 1) % JEUX.size()
	_appliquer()


func _basculer_shading() -> void:
	lisse = not lisse
	_appliquer()


func _bouton(parent: Control, texte: String, action: Callable) -> void:
	var b := Button.new()
	b.text = texte
	b.pressed.connect(action)
	parent.add_child(b)


func _appliquer() -> void:
	var d: float = DISTANCES[i_distance]
	var e: String = ETATS[i_etat]
	noyau.mesh = mesh_lisse if lisse else mesh_plat
	noyau.material_override = materiaux[JEUX[i_jeu]][e]
	camera.position = Vector3(0, HAUTEUR_CAMERA, RAYON + d)
	camera_capture.global_transform = camera.global_transform
	etiquette.text = "distance %.1f m | état %s | shading %s | textures %s" % [d, e, "lissé" if lisse else "plat", JEUX[i_jeu]]


func _capturer_vue(chemin: String) -> void:
	_appliquer()
	await get_tree().process_frame
	await get_tree().process_frame
	vue_capture.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	vue_capture.get_texture().get_image().save_png(ProjectSettings.globalize_path(chemin))


func _capturer_tout() -> void:
	interface.visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE))
	i_jeu = 0
	for di in DISTANCES.size():
		for ei in ETATS.size():
			for l in [true, false]:
				i_distance = di
				i_etat = ei
				lisse = l
				var nom := "d%02d_%s_%s.png" % [int(DISTANCES[di] * 10.0), ETATS[ei], "lisse" if l else "plat"]
				await _capturer_vue(SORTIE + nom)
	interface.visible = true
	etiquette.text += " | 8 captures écrites dans tests/test_noyau/captures/"


# Comparaison de compression : shading lissé, 3 jeux x 2 distances x 2 états.
func _capturer_compression() -> void:
	interface.visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SORTIE_COMPRESSION))
	lisse = true
	for ji in JEUX.size():
		for di in DISTANCES.size():
			for ei in ETATS.size():
				i_jeu = ji
				i_distance = di
				i_etat = ei
				var nom := "%s_d%02d_%s.png" % [JEUX[ji], int(DISTANCES[di] * 10.0), ETATS[ei]]
				await _capturer_vue(SORTIE_COMPRESSION + nom)
	i_jeu = 0
	interface.visible = true
	_appliquer()
	etiquette.text += " | 12 captures écrites dans tests/test_noyau/captures_compression/"
