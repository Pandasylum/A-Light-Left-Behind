extends Node3D
## Spike P2-N1 : mini-assemblée de 90° (6 tronçons de mur × 2 anneaux, 6 tronçons de noyau,
## 6 marches, un mur droit) + pinceau de test (use_primary maintenu, souris capturée) + HUD.
## Scène de test NON OFFICIELLE. Valeurs provisoires. Les modules viennent des .glb de
## assets/modules_temoins/ ; s'ils sont absents, les faces nettoyables sont générées par code.

const MODULES_DIR: String = "res://assets/modules_temoins/"
const THETA: float = deg_to_rad(15.0)
const STEP_HEIGHT: float = 0.18
const RING_HEIGHT: float = 2.16 # PROVISOIRE
const SEGMENTS: int = 6
const RINGS: int = 2
const BRUSH_RADIUS: float = 0.15 # m
const BRUSH_REACH: float = 3.0 # m
const BRUSH_RATE: float = 4.0 # dose par seconde, PROVISOIRE
const WORLD_LAYER: int = 1

@export var stone_material: ShaderMaterial
@export var force_generated_modules: bool = false

var faces: Array[CleanableFace] = []
var init_usec: int = 0 ## construction de l'assemblage, poids grossiers compris
var generated: PackedStringArray = PackedStringArray() ## modules générés par code (.glb absents)
var notes: PackedStringArray = PackedStringArray() ## écarts constatés avec les conventions

var _params: CleaningParams = CleaningParams.new()
var _shapes: Dictionary = {}
var _aimed: CleanableFace
var _brushing: bool = false
var _last_point: Vector3 = Vector3.ZERO
var _stroke_usec: int = 0

@onready var _camera: Camera3D = $Player/Head/Camera3D
@onready var _label: Label = $HUD/Infos


## Modules témoins : fichier, faces nettoyables (correspondance, emplacement de matériau attendu).
static func module_defs() -> Dictionary:
	var wall: CylinderMapping = CylinderMapping.new()
	wall.rayon = 2.0
	wall.vers_interieur = true
	wall.tuiles_par_tour = 12
	var core: CylinderMapping = CylinderMapping.new()
	core.rayon = 0.5
	core.vers_interieur = false
	core.tuiles_par_tour = 3
	var tread: SectorMapping = SectorMapping.new()
	var riser: PlanarMapping = PlanarMapping.new()
	riser.origine = Vector3(0.5, 0.0, 0.0)
	riser.taille = Vector2(1.5, STEP_HEIGHT)
	var straight: PlanarMapping = PlanarMapping.new()
	straight.taille = Vector2(2.0, RING_HEIGHT)
	return {
		"mur": {"file": "module_tronçon_mur.glb", "faces": [
			{"name": "FaceMur", "mapping": wall, "surface": 0, "material": "mur_nettoyable", "segments": Vector2i(4, 1)}]},
		"noyau": {"file": "module_tronçon_noyau.glb", "faces": [
			{"name": "FaceNoyau", "mapping": core, "surface": 0, "material": "noyau_nettoyable", "segments": Vector2i(4, 1)}]},
		"marche": {"file": "module_marche.glb", "faces": [
			{"name": "FaceDessus", "mapping": tread, "surface": 0, "material": "marche_dessus", "segments": Vector2i(1, 4)},
			{"name": "FaceContremarche", "mapping": riser, "surface": 1, "material": "contremarche", "segments": Vector2i(1, 1)}]},
		"mur_droit": {"file": "module_mur_droit.glb", "faces": [
			{"name": "FaceMurDroit", "mapping": straight, "surface": 0, "material": "mur_droit_nettoyable", "segments": Vector2i(1, 1)}]},
	}


## Repli sans .glb : faces nettoyables seules (pas de surface « cache »), mêmes formules, UV2 = uv.
static func generate_mesh(face_defs: Array) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for def: Dictionary in face_defs:
		var mapping: SurfaceMapping = def["mapping"]
		var seg: Vector2i = def["segments"]
		var tool: SurfaceTool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j: int in seg.y + 1:
			for i: int in seg.x + 1:
				var uv: Vector2 = Vector2(float(i) / float(seg.x), float(j) / float(seg.y))
				tool.set_normal(mapping.normal_at(uv))
				tool.set_uv(uv)
				tool.set_uv2(uv)
				tool.add_vertex(mapping.point_at(uv))
		# Godot : face avant = sens horaire. Sens choisi d'après la normale de la correspondance.
		var p0: Vector3 = mapping.point_at(Vector2.ZERO)
		var pu: Vector3 = mapping.point_at(Vector2(1.0 / float(seg.x), 0.0))
		var pv: Vector3 = mapping.point_at(Vector2(0.0, 1.0 / float(seg.y)))
		var flip: bool = (pv - p0).cross(pu - p0).dot(mapping.normal_at(Vector2.ZERO)) < 0.0
		for j: int in seg.y:
			for i: int in seg.x:
				var a: int = j * (seg.x + 1) + i
				var b: int = a + 1
				var c: int = a + seg.x + 1
				var d: int = c + 1
				for index: int in ([a, c, b, b, c, d] if flip else [a, b, c, b, d, c]):
					tool.add_index(index)
		tool.generate_tangents()
		tool.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, def["material"])
	return mesh


func _ready() -> void:
	var t0: int = Time.get_ticks_usec()
	var defs: Dictionary = module_defs()
	var assembly: Node3D = Node3D.new()
	assembly.name = "Assemblage"
	add_child(assembly)
	for k: int in SEGMENTS:
		_add_module(assembly, defs, "marche", "Marche%d" % k, k * THETA, Vector3(0.0, k * STEP_HEIGHT, 0.0))
		_add_module(assembly, defs, "noyau", "Noyau%d" % k, k * THETA, Vector3.ZERO)
		for j: int in RINGS:
			_add_module(assembly, defs, "mur", "Mur%d_%d" % [j, k], k * THETA, Vector3(0.0, j * RING_HEIGHT, 0.0))
	_add_module(assembly, defs, "mur_droit", "MurDroit", 0.0, Vector3(-2.5, 0.0, 0.0))
	init_usec = Time.get_ticks_usec() - t0
	if not generated.is_empty():
		push_warning("cleaning_spike : .glb absents, modules générés par code : %s" % ", ".join(generated))
	for note: String in notes:
		push_warning("cleaning_spike : " + note)


func _add_module(parent: Node3D, defs: Dictionary, kind: String, node_name: String, angle: float, offset: Vector3) -> void:
	var def: Dictionary = defs[kind]
	var module: Node3D = _instantiate(kind, def)
	module.name = node_name
	module.transform = Transform3D(Basis(Vector3.UP, angle), offset)
	parent.add_child(module)
	var mesh_instance: MeshInstance3D = _find_mesh_instance(module)
	if mesh_instance == null:
		notes.append("%s : aucun MeshInstance3D" % kind)
		return
	if mesh_instance != module and not mesh_instance.transform.is_equal_approx(Transform3D.IDENTITY):
		_note("%s : le maillage n'est pas à l'identité dans le module" % kind)
	# Collisions du module sur la couche 1 (monde).
	if not _shapes.has(kind):
		_shapes[kind] = mesh_instance.mesh.create_trimesh_shape()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Corps"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = _shapes[kind]
	body.add_child(shape)
	module.add_child(body)
	for face_def: Dictionary in def["faces"]:
		var surface: int = face_def["surface"]
		var found: Material = mesh_instance.mesh.surface_get_material(surface) if surface < mesh_instance.mesh.get_surface_count() else null
		var found_name: String = found.resource_name if found != null else mesh_instance.mesh.surface_get_name(surface)
		if found_name != face_def["material"]:
			_note("%s : emplacement %d = « %s » au lieu de « %s »" % [kind, surface, found_name, face_def["material"]])
		var face: CleanableFace = CleanableFace.new()
		face.name = face_def["name"]
		face.mapping = face_def["mapping"]
		face.params = _params
		face.material = stone_material
		face.mesh_instance = mesh_instance
		face.surface_index = surface
		module.add_child(face) # enfant du module, transformation identité
		faces.append(face)


func _instantiate(kind: String, def: Dictionary) -> Node3D:
	var path: String = MODULES_DIR + String(def["file"])
	if not force_generated_modules and ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene != null:
			return scene.instantiate() as Node3D
	if not generated.has(kind):
		generated.append(kind)
	if not def.has("mesh"):
		def["mesh"] = generate_mesh(def["faces"])
	var module: Node3D = Node3D.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Maillage"
	mesh_instance.mesh = def["mesh"]
	module.add_child(mesh_instance)
	return module


func _find_mesh_instance(module: Node3D) -> MeshInstance3D:
	if module is MeshInstance3D:
		return module as MeshInstance3D
	var found: Array[Node] = module.find_children("*", "MeshInstance3D", true, false)
	return found[0] as MeshInstance3D if not found.is_empty() else null


func _note(text: String) -> void:
	if not notes.has(text):
		notes.append(text)


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
			# Toutes les faces reçoivent le geste : chacune rejette ce qui est hors de portée,
			# ce qui nettoie à travers les coutures entre modules.
			for face: CleanableFace in faces:
				face.clean_stroke(start, point, BRUSH_RADIUS, BRUSH_RATE * delta)
			_stroke_usec = Time.get_ticks_usec() - t0
			_last_point = point
	_brushing = active


func _face_at(point: Vector3) -> CleanableFace:
	var best: CleanableFace = null
	var best_distance: float = 0.05
	for face: CleanableFace in faces:
		var distance: float = face.surface_distance(point)
		if distance < best_distance:
			best_distance = distance
			best = face
	return best


func _process(_delta: float) -> void:
	var coarse_usec: int = 0
	for face: CleanableFace in faces:
		coarse_usec += face.coarse_init_usec
	var aimed: String = "aucune"
	if _aimed != null:
		aimed = "%s/%s — propreté %.1f %% — %s" % [_aimed.get_parent().name, _aimed.name,
				_aimed.cleanliness() * 100.0, "finie" if _aimed.is_finished() else "en cours"]
	_label.text = "\n".join(PackedStringArray([
		"Face visée : " + aimed,
		"Dernier clean_stroke (toutes faces) : %.2f ms" % (_stroke_usec / 1000.0),
		"Initialisation : %.1f ms (dont poids grossiers %.1f ms, %d faces)" % [init_usec / 1000.0, coarse_usec / 1000.0, faces.size()],
		"Appels de dessin : %d — FPS : %d" % [
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Engine.get_frames_per_second())],
		"Modules : " + ("GÉNÉRÉS PAR CODE (%s)" % ", ".join(generated) if not generated.is_empty() else ".glb"),
		"Clic gauche maintenu : nettoyer (rayon %.2f m, portée %.0f m)" % [BRUSH_RADIUS, BRUSH_REACH],
	]))
