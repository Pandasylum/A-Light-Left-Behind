extends SceneTree
## Spike noyau en panneaux + voile (NON OFFICIEL) : panneaux, projection monde, voile.
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_fin_surface.gd

const SCENE: String = "res://tests/test_fin_surface/noyau_panneaux.tscn"
const RING_HEIGHT: float = 2.16

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var spike: Node3D = (load(SCENE) as PackedScene).instantiate()
	root.add_child(spike)
	var expected_area: float = 0.5 * (PI / 2.0) * RING_HEIGHT
	# (a) 12 panneaux, une face chacun, aire attendue.
	_check(spike.faces.size() == 12, "12 faces (%d)" % spike.faces.size())
	for j: int in 3:
		for k: int in 4:
			var module: Node = spike.get_node("Panneaux/Panneau%d_%d" % [j, k])
			var count: int = module.find_children("*", "CleanableFace", false, false).size()
			_check(count == 1, "Panneau%d_%d : 1 CleanableFace (%d)" % [j, k, count])
			var face: CleanableFace = module.get_node("FacePanneau")
			var area: float = face.face_area()
			_check(absf(area / expected_area - 1.0) <= 0.01, "Panneau%d_%d : aire %.4f m² (attendu %.4f, ~1,70)" % [j, k, area, expected_area])
			_test_projection(face, j, k)
	# (c) voile : progress = 1 et next_pass nul après un tween avancé par code.
	var face0: CleanableFace = spike.faces[0]
	spike.play_veil(face0)
	var veil: ShaderMaterial = face0.face_material().next_pass as ShaderMaterial
	_check(veil != null and is_equal_approx(veil.get_shader_parameter(&"progress"), 0.0), "voile posé, progress 0")
	_check(veil != null and is_equal_approx(veil.get_shader_parameter(&"peak"), 0.07) and is_equal_approx(veil.get_shader_parameter(&"edge_boost"), 0.0), "peak 0,07, edge_boost 0")
	spike.play_veil(face0) # une seule lecture à la fois
	_check(spike.veil_tweens.size() == 1, "une seule lecture par face")
	var tween: Tween = spike.veil_tweens[face0]
	tween.custom_step(0.7)
	_check(absf(float(veil.get_shader_parameter(&"progress")) - 0.5) < 1e-3, "progress ~0,5 à mi-parcours (linéaire)")
	tween.custom_step(1.0)
	_check(is_equal_approx(float(veil.get_shader_parameter(&"progress")), 1.0), "progress = 1 en fin de voile")
	_check(face0.face_material().next_pass == null and spike.veil_tweens.is_empty(), "next_pass nul après le voile")
	spike.free()
	_test_surface_veil()
	print("test_fin_surface : %s" % ("OK" if _failures == 0 else "%d échec(s)" % _failures))
	quit(1 if _failures > 0 else 0)


## Voile de fin posé par CleaningSurface : marche à deux faces (même progress), un seul voile par fin,
## face libérée pendant le voile, aucun voile au chargement.
func _test_surface_veil() -> void:
	var spike: Node3D = (load(SCENE) as PackedScene).instantiate()
	root.add_child(spike)
	var face_a: CleanableFace = spike.faces[0]
	var face_b: CleanableFace = spike.faces[1]
	var surface: CleaningSurface = CleaningSurface.new()
	surface.faces = [face_a, face_b] as Array[CleanableFace]
	spike.add_child(surface)
	var finishes: Array[int] = [0]
	surface.surface_finished.connect(func(_s: CleaningSurface) -> void: finishes[0] += 1)
	_check(face_a.face_material().next_pass == null and surface.veil_tween == null, "chargement : aucun voile")
	_clean(face_a)
	_clean(face_b)
	var veil_a: ShaderMaterial = face_a.face_material().next_pass as ShaderMaterial
	var veil_b: ShaderMaterial = face_b.face_material().next_pass as ShaderMaterial
	_check(finishes[0] == 1 and veil_a != null and veil_b != null, "voile posé sur chaque face à la fin (%d fin)" % finishes[0])
	if veil_a == null or veil_b == null:
		spike.free()
		return
	_check(is_equal_approx(float(veil_a.get_shader_parameter(&"progress")), 0.0) and is_equal_approx(float(veil_a.get_shader_parameter(&"peak")), 0.12)
			and is_equal_approx(float(veil_a.get_shader_parameter(&"edge_boost")), 0.0), "progress 0, peak 0,12, edge_boost 0")
	var tween: Tween = surface.veil_tween
	surface._play_veil() # nouvelle fin pendant le voile : ignorée
	_check(surface.veil_tween == tween and face_a.face_material().next_pass == veil_a, "pas d'empilement pendant un voile en cours")
	tween.custom_step(0.7)
	var pa: float = veil_a.get_shader_parameter(&"progress")
	_check(absf(pa - 0.5) < 1e-3 and is_equal_approx(pa, float(veil_b.get_shader_parameter(&"progress"))), "progress ~0,5 identique sur les deux faces")
	face_b.free() # face libérée pendant le voile
	tween.custom_step(1.0)
	_check(is_equal_approx(float(veil_a.get_shader_parameter(&"progress")), 1.0), "progress = 1 en fin de voile")
	_check(face_a.face_material().next_pass == null and surface.veil_tween == null, "next_pass nul après le voile, face libérée sans erreur")
	spike.free()


func _clean(face: CleanableFace) -> void:
	if is_instance_valid(face):
		var center: Vector3 = face.global_transform * face.mapping.point_at(Vector2(0.5, 0.5))
		face.clean_stroke(center, center, 5.0, 100.0)


func _test_projection(face: CleanableFace, j: int, k: int) -> void:
	var label: String = "Panneau%d_%d" % [j, k]
	var proj: SurfaceMapping.WorldProjection = face.world_projection()
	var scale: Vector2 = face.face_material().get_shader_parameter(&"uv_echelle")
	var xform: Transform3D = face.global_transform
	_check(absf(scale.y - PI / RING_HEIGHT) < 1e-5 and is_equal_approx(scale.x, 1.0), "%s : uv_echelle" % label)
	# Limites de panneau (angle k × 90° et (k+1) × 90°) : u à un multiple de 1/4 de tour,
	# et exactement k/4 au bord de départ.
	for edge: int in 2:
		for v: float in [0.0, 1.0]:
			var uv: Vector2 = proj.uv_monde(xform * face.mapping.point_at(Vector2(float(edge), v))) * scale
			var quarter: float = fposmod(uv.x * 4.0 + 0.5, 1.0) - 0.5
			_check(absf(quarter) <= 1e-4, "%s bord %d : 4u = %.6f (entier attendu)" % [label, edge, uv.x * 4.0])
			if edge == 0:
				_check(absf(fposmod(uv.x - k / 4.0 + 0.5, 1.0) - 0.5) <= 1e-4, "%s : u = k/4 (%.6f)" % [label, uv.x])
			var hv: float = fposmod(uv.y + 0.5, 1.0) - 0.5
			_check(absf(hv) <= 1e-4, "%s bord %d v=%.0f : (uv×échelle).y = %.6f (entier attendu)" % [label, edge, v, uv.y])


func _check(ok: bool, text: String) -> void:
	if not ok:
		_failures += 1
		push_error("ÉCHEC : " + text)
		print("ÉCHEC : " + text)
