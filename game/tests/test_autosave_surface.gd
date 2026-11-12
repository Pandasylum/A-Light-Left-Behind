extends SceneTree
## Test du déclencheur « fin de surface » de l'Autosave : fin de surface -> une demande de sauvegarde,
## fin pendant une action d'outil -> sauvegarde après la fin de l'action, surface terminée d'office
## et chargement -> aucune demande, deux fins rapprochées -> une seule écriture.
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_autosave_surface.gd

const SHADER: String = "res://systems/cleaning/pierre_nettoyable.gdshader"
const SaveServiceScript: GDScript = preload("res://core/save_service.gd")
const SAVE_DIR: String = "user://test_saves/"
const SLOT: String = "autosave_surface_test"
const SPONGE: String = "res://data/tools/sponge.tres"
const RADIUS: float = 0.15
const DOSE: float = 100.0
const ROW_STEP: float = 0.1
const SEGMENTS: int = 4

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var service: Node = SaveServiceScript.new() as Node
	service.set("save_dir", SAVE_DIR)
	var controller: ToolController = ToolController.new()
	root.add_child(controller)
	var room: Node3D = Node3D.new()
	room.name = "Piece"
	root.add_child(room)
	var holder: Node = Node.new()
	holder.name = "Surfaces"
	room.add_child(holder)
	var dirty_a: CleanableFace = _face(room, "A", 0)
	var dirty_b: CleanableFace = _face(room, "B", 0)
	var dirty_c: CleanableFace = _face(room, "C", 0)
	var clean: CleanableFace = _face(room, "Propre", -1)
	var below: CleanableFace = _face(room, "SousSeuil", 3)
	var surf_a: CleaningSurface = _surface(holder, "SA", dirty_a)
	var surf_b: CleaningSurface = _surface(holder, "SB", dirty_b)
	var surf_c: CleaningSurface = _surface(holder, "SC", dirty_c)
	var surf_clean: CleaningSurface = _surface(holder, "SPropre", clean)
	var surf_below: CleaningSurface = _surface(holder, "SSousSeuil", below)

	var autosave: Autosave = Autosave.new()
	autosave.handle_quit = false
	autosave.slot_id = SLOT
	root.add_child(autosave)
	autosave.setup(room, controller, service)
	autosave.setup(room, controller, service) # second appel : aucune connexion en double
	_check(surf_clean.is_finished() and surf_below.is_finished() and autosave.triggers_received == 0,
			"surfaces d'office terminées au départ : aucune demande")

	# Fin de surface -> une demande de sauvegarde, une écriture.
	_sweep(dirty_a)
	_check(surf_a.is_finished() and autosave.triggers_received == 1 and autosave.is_busy() and autosave.writes_requested == 0,
			"fin de surface : une demande, rien d'écrit à l'appel")
	_drain(autosave)
	_check(autosave.writes_requested == 1, "fin de surface : une écriture")

	# Surface d'office : nettoyer encore ne déclenche rien.
	_sweep(clean)
	_sweep(below)
	_check(autosave.triggers_received == 1 and not autosave.is_busy(), "surface d'office : nettoyée ensuite, aucune demande")

	# Chargement : import_room ne déclenche rien, même vers un état terminé.
	var done: Dictionary = CleanableFace.export_room(room)
	CleanableFace.import_room(room, {})
	CleanableFace.import_room(room, done)
	_check(autosave.triggers_received == 1 and not autosave.is_busy() and surf_a.is_finished(),
			"chargement : aucune demande")

	# Fin pendant une action d'outil -> sauvegarde après la fin de l'action.
	var sponge: ToolData = load(SPONGE) as ToolData
	controller.add_tool(sponge)
	controller.take_out()
	var far: Dictionary = {"position": Vector3(100.0, 0.0, 100.0)}
	controller.apply_aim_hit(far, 1.0 / 60.0)
	_check(controller.is_action_active(), "action : geste en cours")
	var writes: int = autosave.writes_requested
	var frames: int = autosave.export_frames
	_sweep(dirty_b)
	_check(surf_b.is_finished() and autosave.triggers_received == 2 and autosave.is_busy(), "action : fin de surface reçue")
	for i: int in 5:
		autosave.advance()
	_check(autosave.writes_requested == writes and autosave.export_frames == frames, "action : sauvegarde en attente, aucun export")
	controller.apply_aim_hit({}, 1.0 / 60.0)
	_check(not controller.is_action_active(), "action : terminée")
	_drain(autosave)
	_check(autosave.writes_requested == writes + 1, "action : sauvegarde faite après la fin de l'action")

	# Chargement qui remet une surface au-dessus du seuil : un nouveau passage sous le seuil redéclenche.
	CleanableFace.import_room(room, {})
	_check(not surf_b.is_finished(), "rechargement : surface B de nouveau au-dessus du seuil")
	var before: int = autosave.triggers_received
	_sweep(dirty_b)
	_check(surf_b.is_finished() and autosave.triggers_received == before + 1, "rechargement : nouveau passage sous le seuil = une demande")
	_drain(autosave)

	# Deux fins rapprochées -> une seule écriture.
	writes = autosave.writes_requested
	var triggers: int = autosave.triggers_received
	# C et A (déjà propre, rechargée sale) : deux fins avant tout export.
	CleanableFace.import_room(room, {})
	_check(not surf_a.is_finished() and not surf_c.is_finished(), "fusion : surfaces A et C sales de nouveau")
	_sweep(dirty_a)
	_sweep(dirty_c)
	_check(autosave.triggers_received == triggers + 2, "fusion : deux fins, deux demandes")
	_drain(autosave)
	_check(autosave.writes_requested == writes + 1, "fusion : une seule écriture")

	service.call(&"flush")
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir != null:
		for file: String in dir.get_files():
			if file.begins_with(SLOT + "."):
				dir.remove(file)
	service.free()
	print("test_autosave_surface : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


## columns < 0 : face propre ; 0 : entièrement sale ; n : n colonnes sales (sous le seuil pour 3).
func _face(room: Node3D, face_name: String, columns: int) -> CleanableFace:
	var mapping: PlanarMapping = PlanarMapping.new()
	mapping.taille = Vector2(1.0, 1.0)
	mapping.tuile_m = 1.0
	var face: CleanableFace = CleanableFace.new()
	face.name = face_name
	face.mapping = mapping
	face.channels = 1
	if columns != 0:
		var image: Image = Image.create(64, 64, false, Image.FORMAT_R8)
		image.fill(Color.BLACK)
		for x: int in maxi(columns, 0):
			for y: int in 64:
				image.set_pixel(32 + x, y, Color.WHITE)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = load(SHADER) as Shader
		material.set_shader_parameter(&"masque_salete", ImageTexture.create_from_image(image))
		face.material = material
	room.add_child(face)
	return face


func _surface(holder: Node, surface_name: String, face: CleanableFace) -> CleaningSurface:
	var surface: CleaningSurface = CleaningSurface.new()
	surface.name = surface_name
	var faces: Array[CleanableFace] = [face]
	surface.faces = faces
	holder.add_child(surface)
	return surface


func _sweep(face: CleanableFace) -> void:
	var xform: Transform3D = face.global_transform
	var rows: int = ceili(1.0 / ROW_STEP)
	for j: int in rows + 1:
		for i: int in SEGMENTS:
			var v: float = float(j) / float(rows)
			face.clean_stroke(xform * face.mapping.point_at(Vector2(float(i) / SEGMENTS, v)),
					xform * face.mapping.point_at(Vector2(float(i + 1) / SEGMENTS, v)), RADIUS, DOSE)


func _drain(autosave: Autosave) -> void:
	var frames: int = 0
	while autosave.is_busy() and frames < 1000:
		autosave.advance()
		frames += 1


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("ÉCHEC : ", label)
