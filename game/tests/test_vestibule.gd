extends SceneTree
## Vestibule (blocage gris) : chargement, GAME_SCENE, comptage surfaces + 9 objets suivis (ItemData .tres), table et palette
## zones comptées (meubles non comptés), verrou « restaurée » à 100 % et conservé après sauvegarde/rechargement.
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_vestibule.gd

const SaveServiceScript: GDScript = preload("res://core/save_service.gd")
const SCENE: String = "res://rooms/vestibule/vestibule.tscn"
const SAVE_DIR: String = "user://test_saves_vestibule/"
const SURFACES: int = 3
const ITEMS: int = 9
const SWEEP_RADIUS: float = 0.15
const SWEEP_STEP: float = 0.1
const SWEEP_SEGMENTS: int = 8

var _failures: int = 0
var _service: Node
var _own_service: bool = false
var _previous_dir: Variant


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_open_service()
	_check(GameFlow.GAME_SCENE == SCENE, "GAME_SCENE pointe sur la scène vestibule")
	var scene: Node3D = _open(false)
	await _settle()
	var progress: RoomProgress = scene.get_node("RoomProgress")
	_check(progress.is_evaluated() and progress.percent() == 0 and not progress.is_restored(), "chargement sans erreur, 0 %, verrou à faux")
	for path: String in ["Spike/Player", "Autosave", "PauseMenu", "Disposition", "StorageService", "RoomProgress", "ProgressIndicator"]:
		_check(scene.has_node(path), "nœud présent : " + path)
	_check(progress.cleaning_counts() == Vector2i(0, SURFACES) and progress.storing_counts() == Vector2i(0, ITEMS),
			"comptage : %d surfaces + %d objets suivis (%s, %s)" % [SURFACES, ITEMS, str(progress.cleaning_counts()), str(progress.storing_counts())])

	# Table (SMALL/MEDIUM) et palette (SMALL/MEDIUM/LARGE) : zones comptées ; les meubles eux-mêmes ne comptent pas.
	var storage: StorageService = scene.get_node("StorageService")
	var item1: TestItem = scene.get_node("Item1")
	var item8: TestItem = scene.get_node("Item8")
	var item9: TestItem = scene.get_node("Item9")
	_check(item1.item_data == load("res://data/items/test_small_1.tres") and item9.item_data == load("res://data/items/test_large_1.tres"),
			"les objets utilisent les .tres (plus de copies locales)")
	_put(item1, _support(scene, "Table"), -3.5, -1.5)
	_put(item8, _support(scene, "Table"), -3.2, -1.5)
	_put(item9, _support(scene, "Table"), -3.8, -1.5)
	_check(storage.is_stored(item1) and storage.is_stored(item8) and not storage.is_stored(item9) and progress.storing_counts() == Vector2i(2, ITEMS),
			"table : SMALL et MEDIUM rangés, LARGE refusé, total inchangé (%s)" % str(progress.storing_counts()))
	_put(item9, _support(scene, "Palette"), -3.5, 1.5)
	_check(storage.is_stored(item9) and progress.storing_counts() == Vector2i(3, ITEMS), "palette : LARGE rangé (%s)" % str(progress.storing_counts()))
	_check(_zone_count(scene) == 5 and _count_nodes(scene, ^"Furniture") == 5, "5 zones comptées (basse, table, palette, 2 murales), 5 meubles non suivis")
	for furniture: Node in scene.get_node("Furniture").get_children():
		_check(not (furniture is TestItem) and not furniture.has_node("StorageZone"), "meuble non compté : " + furniture.name)

	# Rangement : 100 % pose le verrou une fois.
	var locks: Array[StringName] = []
	progress.lock_posed.connect(func(id: StringName) -> void: locks.append(id))
	while _finish_next_surface(scene):
		pass
	_check(progress.cleaning_counts() == Vector2i(SURFACES, SURFACES) and not progress.is_restored(), "surfaces finies, verrou pas encore posé")
	_put(item1, _support(scene, "EtagereBasse"), 3.2, -1.2)
	_put(scene.get_node("Item2"), _support(scene, "EtagereBasse"), 3.6, -1.2)
	_put(scene.get_node("Item3"), _support(scene, "EtagereMuraleA"), 4.75, -3.0)
	_put(scene.get_node("Item4"), _support(scene, "EtagereMuraleB"), 4.75, 2.8)
	_put(scene.get_node("Item5"), _support(scene, "EtagereMuraleB"), 4.75, 3.2)
	_put(scene.get_node("Item6"), _support(scene, "Table"), -3.8, -1.5)
	_check(progress.percent() < 100 and not progress.is_restored(), "8 objets sur 9 rangés : < 100 %%, verrou à faux (%d %%)" % progress.percent())
	_put(scene.get_node("Item7"), _support(scene, "Palette"), -3.0, 1.5)
	_check(progress.percent() == 100 and progress.is_restored() and locks == [&"vestibule"], "100 %% : verrou posé une seule fois")
	_check((scene.get_node("Autosave") as Autosave).save_and_wait() == 0, "sauvegarde écrite")
	var saved: Dictionary = _saved()
	scene.queue_free()
	await process_frame

	# Rechargement (Continuer) : verrou conservé.
	var scene_b: Node3D = _open(true)
	await _settle()
	var progress_b: RoomProgress = scene_b.get_node("RoomProgress")
	_check(progress_b.is_evaluated() and progress_b.is_restored() and progress_b.percent() == 100 and saved.has(ProgressSave.SAVE_KEY),
			"rechargement : verrou posé, 100 %% (%d %%)" % progress_b.percent())
	scene_b.queue_free()
	await process_frame

	_close_service()
	print("test_vestibule : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _zone_count(scene: Node3D) -> int:
	return scene.get_node("Zones").get_child_count()


func _count_nodes(scene: Node3D, path: NodePath) -> int:
	return scene.get_node(path).get_child_count()


func _support(scene: Node3D, name: String) -> PlacementSurface:
	return PlacementSurface.of_body(scene.get_node("Furniture/" + name))


func _put(item: TestItem, surface: PlacementSurface, x: float, z: float) -> void:
	item.on_picked_up()
	item.global_position = Vector3(x, surface.top_y() + item.item_data.height * 0.5, z)
	item.on_placed(surface)


func _finish_next_surface(scene: Node3D) -> bool:
	for surface: CleaningSurface in CleaningSurface.room_surfaces(scene.get_node("Spike")):
		if not surface.is_finished():
			for face: CleanableFace in surface.faces:
				if is_instance_valid(face):
					_sweep(face)
			return true
	return false


func _sweep(face: CleanableFace) -> void:
	face.ensure_fine_grid()
	var xform: Transform3D = face.global_transform
	var size: Vector3 = face.world_bounds().size
	var rows: int = ceili(maxf(size.x, maxf(size.y, size.z)) / SWEEP_STEP) + 1
	for j: int in rows + 1:
		for i: int in SWEEP_SEGMENTS:
			var v: float = float(j) / float(rows)
			face.clean_stroke(xform * face.mapping.point_at(Vector2(float(i) / SWEEP_SEGMENTS, v)),
					xform * face.mapping.point_at(Vector2(float(i + 1) / SWEEP_SEGMENTS, v)), SWEEP_RADIUS, 100.0)


func _open_service() -> void:
	_service = root.get_node_or_null("SaveService")
	_own_service = _service == null
	if _own_service:
		_service = SaveServiceScript.new() as Node
		_service.name = "SaveService"
		root.add_child(_service)
	_previous_dir = _service.get("save_dir")
	_service.set("save_dir", SAVE_DIR)
	_clear_saves()
	GameFlow.continue_requested = false


func _close_service() -> void:
	_service.call(&"flush")
	_clear_saves()
	_service.set("save_dir", _previous_dir)
	GameFlow.continue_requested = false
	if _own_service:
		_service.free()


func _clear_saves() -> void:
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	for file: String in dir.get_files():
		dir.remove(file)


func _open(continue_game: bool) -> Node3D:
	GameFlow.continue_requested = continue_game
	var scene: Node3D = (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	return scene


func _settle() -> void:
	await physics_frame
	await physics_frame


func _saved() -> Dictionary:
	var loaded: Dictionary = _service.call("load_slot", Autosave.SLOT_ID)
	return loaded["data"] as Dictionary if loaded["ok"] else {}


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_failures += 1
