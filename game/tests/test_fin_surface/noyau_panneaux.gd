extends "res://tests/test_cleaning/cleaning_spike.gd"
## Spike NON OFFICIEL : noyau en 12 panneaux de 90° (3 anneaux × 4), une CleanableFace par panneau,
## textures d'Art lues en projection cylindrique monde (N = 1), et voile de fin de surface en next_pass.
## Valeurs provisoires. Aucune rainure en géométrie : limites de panneau et joints sont dans les textures.

const Spike := preload("res://tests/test_cleaning/cleaning_spike.gd")
const TEX_DIR: String = "res://tests/test_noyau/tex_vram/" # réglage de production : VRAM standard
const CORE_RADIUS: float = 0.5 # m
const PANELS_PER_RING: int = 4
const RINGS: int = 3
const VEIL_SHADER: String = "res://tests/test_fin_surface/fin_surface.gdshader"
const VEIL_DURATION: float = 1.4 # s
const PEAK_LOW: float = 0.07
const PEAK_HIGH: float = 0.12
const PLAYER_DISTANCE: float = 0.9 # m de la surface

var peak: float = PEAK_LOW
var brush_aimed_only: bool = false
var veil_tweens: Dictionary = {} # CleanableFace -> Tween (une lecture à la fois par face)

var _info: Label


static func module_defs() -> Dictionary:
	var defs: Dictionary = Spike.module_defs()
	var mapping: CylinderMapping = CylinderMapping.new()
	mapping.rayon = CORE_RADIUS
	mapping.angle_rad = PI / 2.0
	mapping.hauteur = Spike.RING_HEIGHT
	mapping.vers_interieur = false
	mapping.tuiles_par_tour = 1
	defs["panneau"] = {"file": "module_panneau.glb", "faces": [ # .glb inexistant : repli généré par code
		{"name": "FacePanneau", "mapping": mapping, "surface": 0, "material": "panneau_nettoyable", "segments": Vector2i(6, 1)}]}
	return defs


func _ready() -> void:
	stone_material = _core_material()
	var defs: Dictionary = module_defs()
	var assembly: Node3D = Node3D.new()
	assembly.name = "Panneaux"
	add_child(assembly)
	for j: int in RINGS:
		for k: int in PANELS_PER_RING:
			_add_module(assembly, defs, "panneau", "Panneau%d_%d" % [j, k], k * PI / 2.0, Vector3(0.0, j * RING_HEIGHT, 0.0))
	for face: CleanableFace in faces:
		face.finished.connect(play_veil.bind(face))
	var player: Node3D = get_node("Player") as Node3D
	player.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(CORE_RADIUS + PLAYER_DISTANCE, 0.05, 0.0))
	_info = Label.new()
	_info.position = Vector2(12.0, 300.0)
	_info.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	_info.add_theme_constant_override(&"shadow_offset_x", 1)
	_info.add_theme_constant_override(&"shadow_offset_y", 1)
	$HUD.add_child(_info)


## Réglages de Mat_pierre du spike, textures de production du noyau, saleté uniforme, pas de mousse.
func _core_material() -> ShaderMaterial:
	var material: ShaderMaterial = stone_material.duplicate() as ShaderMaterial
	material.set_shader_parameter(&"albedo_propre", load(TEX_DIR + "alb_propre.png"))
	material.set_shader_parameter(&"albedo_sale", load(TEX_DIR + "alb_sale.png"))
	material.set_shader_parameter(&"normal_propre", load(TEX_DIR + "pierre_normal.png"))
	material.set_shader_parameter(&"masque_salete", null) # épaisseur 1 partout : tout sale
	material.set_shader_parameter(&"masque_mousse", null) # pas de mousse
	material.set_shader_parameter(&"echelle_epaisseur", Vector2.ONE)
	material.set_shader_parameter(&"uv_echelle", Vector2(1.0, PI / RING_HEIGHT)) # 1 tour × 1 anneau
	return material


func play_veil(face: CleanableFace) -> void:
	if veil_tweens.has(face):
		return
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(VEIL_SHADER) as Shader
	material.set_shader_parameter(&"progress", 0.0)
	material.set_shader_parameter(&"peak", peak)
	material.set_shader_parameter(&"edge_boost", 0.0)
	face.face_material().next_pass = material
	var tween: Tween = create_tween()
	tween.tween_property(material, "shader_parameter/progress", 1.0, VEIL_DURATION)
	tween.tween_callback(_end_veil.bind(face, material))
	veil_tweens[face] = tween


func _end_veil(face: CleanableFace, material: ShaderMaterial) -> void:
	if is_instance_valid(face) and face.face_material().next_pass == material:
		face.face_material().next_pass = null
	veil_tweens.erase(face)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_P:
			peak = PEAK_HIGH if is_equal_approx(peak, PEAK_LOW) else PEAK_LOW
			for face: CleanableFace in veil_tweens:
				var next: ShaderMaterial = face.face_material().next_pass as ShaderMaterial
				if next != null:
					next.set_shader_parameter(&"peak", peak)
		KEY_V:
			if _aimed != null:
				play_veil(_aimed)
		KEY_K:
			if _aimed != null:
				var center: Vector3 = _aimed.global_transform * _aimed.mapping.point_at(Vector2(0.5, 0.5))
				_aimed.clean_stroke(center, center, 5.0, 100.0)
		KEY_B:
			brush_aimed_only = not brush_aimed_only


## Logique du spike ; seule différence : avec B, seule la face visée reçoit le geste.
func _physics_process(delta: float) -> void:
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from - _camera.global_basis.z * BRUSH_REACH
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_aimed = null
	var active: bool = false
	if not hit.is_empty():
		var point: Vector3 = hit["position"]
		_aimed = _face_at(point)
		active = Input.is_action_pressed(&"use_primary") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		if active:
			var start: Vector3 = _last_point if _brushing else point
			var t0: int = Time.get_ticks_usec()
			if brush_aimed_only:
				if _aimed != null:
					_aimed.clean_stroke(start, point, BRUSH_RADIUS, BRUSH_RATE * delta)
			else:
				for face: CleanableFace in faces:
					face.clean_stroke(start, point, BRUSH_RADIUS, BRUSH_RATE * delta)
			_stroke_usec = Time.get_ticks_usec() - t0
			_last_point = point
	_brushing = active


func _process(delta: float) -> void:
	super._process(delta)
	var next_pass: String = "aucun"
	if _aimed != null and _aimed.face_material().next_pass != null:
		next_pass = "actif"
	_info.text = "\n".join(PackedStringArray([
		"P : peak %.2f (0,07 <-> 0,12) — V : voile du panneau visé — K : nettoyer le panneau visé — B : pinceau limité à la face visée" % peak,
		"Pinceau : %s" % ("face visée seule" if brush_aimed_only else "toutes les faces"),
		"next_pass : " + next_pass,
	]))
