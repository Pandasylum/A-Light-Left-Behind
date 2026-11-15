extends SceneTree
## Vestibule (blocage gris) : chargement, GAME_SCENE, comptage surfaces + 10 objets suivis (7 SMALL, 2 MEDIUM, 1 LARGE ; ItemData .tres), table et palette
## zones comptées (meubles non comptés), verrou « restaurée » à 100 % et conservé après sauvegarde/rechargement.
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_vestibule.gd

const SaveServiceScript: GDScript = preload("res://core/save_service.gd")
const SCENE: String = "res://rooms/vestibule/vestibule.tscn"
const SAVE_DIR: String = "user://test_saves_vestibule/"
const SURFACES: int = 3
const ITEMS: int = 10
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

	# Règle de contenu (Direction 15/11/2026, provisoire) : tout objet suivi démarre non rangé, sans geste du joueur.
	var started_stored: int = 0
	for tracked: Node in (scene.get_node("StorageService") as StorageService).tracked_items():
		if (scene.get_node("StorageService") as StorageService).is_stored(tracked):
			started_stored += 1
	_check(started_stored == 0 and progress.storing_counts().x == 0 and progress.percent() == 0,
			"scène neuve : 0 objet suivi rangé (%d), 0 objet compté, 0 %%" % started_stored)

	# Comptage par taille : 7 SMALL, 2 MEDIUM, 1 LARGE, tous suivis, 10 ItemData utilisés ; PorteSortie présent.
	var by_size: Array[int] = [0, 0, 0]
	for tracked: Node in (scene.get_node("StorageService") as StorageService).tracked_items():
		if (tracked as TestItem).item_data.tracks_storing:
			by_size[(tracked as TestItem).item_data.category] += 1
	_check(by_size == [7, 2, 1], "objets suivis par taille : SMALL 7, MEDIUM 2, LARGE 1 (%s)" % str(by_size))
	_check(scene.get_node("PorteSortie") is Marker3D, "repère PorteSortie présent")

	# Table (SMALL/MEDIUM) et palette (SMALL/MEDIUM/LARGE) : zones comptées ; les meubles eux-mêmes ne comptent pas.
	var storage: StorageService = scene.get_node("StorageService")
	var cle: TestItem = scene.get_node("Cle")
	var bottes: TestItem = scene.get_node("Bottes")
	var coffre: TestItem = scene.get_node("Coffre")
	_check(cle.item_data == load("res://data/items/cle.tres") and coffre.item_data == load("res://data/items/coffre.tres"),
			"les objets utilisent les .tres de game/data/items/")
	# Art : chaque objet a un visuel .glb (pas de boîte de test), collision et surface conformes à l'ItemData.
	for item: Node in scene.get_children():
		if not (item is TestItem) or item.name == &"Bucket":
			continue
		var it: TestItem = item
		var data: ItemData = it.item_data
		var box: Vector3 = Vector3(data.footprint.x, data.height, data.footprint.y)
		var shape: BoxShape3D = (it.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		var top: PlacementSurface = it.get_node("PlacementSurface")
		_check(it.has_node("Visuel") and not it.has_node("MeshInstance3D") and it.get_node("Visuel").get_child_count() > 0,
				"visuel .glb, sans boîte de test : " + it.name)
		_check(shape != null and shape.size.is_equal_approx(box) and top.size == data.footprint
				and is_equal_approx(top.position.y, data.height * 0.5), "collision et surface conformes à l'ItemData : " + it.name)
	_put(cle, _support(scene, "Table"), -3.5, -1.5)
	_put(bottes, _support(scene, "Table"), -3.2, -1.5)
	_put(coffre, _support(scene, "Table"), -3.8, -1.5)
	_check(storage.is_stored(cle) and storage.is_stored(bottes) and not storage.is_stored(coffre) and progress.storing_counts() == Vector2i(2, ITEMS),
			"table : SMALL et MEDIUM rangés, LARGE refusé, total inchangé (%s)" % str(progress.storing_counts()))
	_put(coffre, _support(scene, "Palette"), -3.5, 1.5)
	_check(storage.is_stored(coffre) and progress.storing_counts() == Vector2i(3, ITEMS), "palette : LARGE rangé (%s)" % str(progress.storing_counts()))
	_check(_zone_count(scene) == 5 and _count_nodes(scene, ^"Furniture") == 5, "5 zones comptées (basse, table, palette, 2 murales), 5 meubles non suivis")
	for furniture: Node in scene.get_node("Furniture").get_children():
		_check(not (furniture is TestItem) and not furniture.has_node("StorageZone"), "meuble non compté : " + furniture.name)

	# Meubles .glb (15/11/2026, hauteurs de l'art provisoires) : surfaces et zones alignées sur le dessus,
	# dimensions horizontales (capacités) inchangées, Visuel des étagères murales pivoté de 90°.
	# nom : [hauteur monde du dessus, zone, centre Y de zone, emprise zone XZ, catégories]
	var expect: Dictionary = {
		"Table": [0.75, "ZoneTable", Vector2(1.2, 0.8), [0, 1]],
		"Palette": [0.144, "ZonePalette", Vector2(1.2, 1.0), [0, 1, 2]],
		"EtagereBasse": [0.70, "ZoneEtagereBasse", Vector2(1.2, 0.8), [0]],
		"EtagereMuraleA": [1.425, "ZoneEtagereMuraleA", Vector2(0.4, 1.0), [0]],
		"EtagereMuraleB": [1.425, "ZoneEtagereMuraleB", Vector2(0.4, 1.0), [0]],
	}
	for fname: String in expect:
		var furn: StaticBody3D = scene.get_node("Furniture/" + fname)
		var row: Array = expect[fname]
		var surf: PlacementSurface = PlacementSurface.of_body(furn)
		var zone: StorageZone = scene.get_node("Zones/" + str(row[1]))
		var zshape: BoxShape3D = (zone.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		var visuel: Node3D = furn.get_node_or_null("Visuel")
		_check(visuel != null and visuel.get_child_count() > 0 and not furn.has_node("MeshInstance3D"), "visuel .glb sans boîte de test : " + fname)
		_check(is_equal_approx(surf.global_position.y, row[0]), "surface de pose au dessus du modèle (%.3f m) : %s" % [row[0], fname])
		var is_wall: bool = fname.begins_with("EtagereMurale")
		if is_wall:
			_check(is_equal_approx(zone.global_position.y, 1.65), "zone murale inchangée (1,65 m) : " + fname)
		else:
			_check(is_equal_approx(zone.global_position.y, row[0]), "zone centrée sur le dessus : " + fname)
		_check(is_equal_approx(zshape.size.x, row[2].x) and is_equal_approx(zshape.size.z, row[2].y) and is_equal_approx(zshape.size.y, 0.6 if is_wall else 0.8),
				"zone : dimensions inchangées (capacité) : " + fname)
		_check(zone.zone_data.accepted_categories == Array(row[3], TYPE_INT, &"", null), "zone : catégories inchangées : " + fname)
		_check(is_equal_approx(zone.global_position.x, furn.global_position.x) and is_equal_approx(zone.global_position.z, furn.global_position.z),
				"zone alignée sur le meuble (XZ) : " + fname)
		var cshape: BoxShape3D = (furn.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		_check(is_equal_approx(furn.global_position.y + cshape.size.y * 0.5, row[0]), "collision boîte : dessus = dessus du modèle : " + fname)
		_check(is_equal_approx(surf.size.x, row[2].x) and is_equal_approx(surf.size.y, row[2].y), "surface de pose : emprise inchangée : " + fname)
		if is_wall:
			var bois: MeshInstance3D = visuel.find_child("bois", true, false)
			var box: AABB = bois.global_transform * bois.get_aabb()
			_check(is_equal_approx(box.size.x, 0.4) and is_equal_approx(box.size.z, 1.0) and is_equal_approx(visuel.rotation.x, 0.0) and is_equal_approx(visuel.rotation.z, 0.0),
					"Visuel pivoté de 90° autour de la verticale (0,4 en X, 1,0 en Z), surface et zone non pivotées : " + fname)
			_check(surf.global_transform.basis.is_equal_approx(Basis()) and zone.global_transform.basis.is_equal_approx(Basis()), "surface et zone sans rotation : " + fname)
			# Plaque verticale des équerres côté -Z du modèle : doit viser le mur est (+X).
			_check((visuel.global_transform.basis * Vector3(0.0, 0.0, -1.0)).is_equal_approx(Vector3.RIGHT), "côté mur des équerres vers +X : " + fname)

	# Rangement : 100 % pose le verrou une fois.
	var locks: Array[StringName] = []
	progress.lock_posed.connect(func(id: StringName) -> void: locks.append(id))
	while _finish_next_surface(scene):
		pass
	_check(progress.cleaning_counts() == Vector2i(SURFACES, SURFACES) and not progress.is_restored(), "surfaces finies, verrou pas encore posé")
	_put(cle, _support(scene, "EtagereBasse"), 3.0, -1.2)
	_put(scene.get_node("BoiteVis1"), _support(scene, "EtagereBasse"), 3.3, -1.2)
	_put(scene.get_node("BoiteVis2"), _support(scene, "EtagereBasse"), 3.6, -1.2)
	_put(scene.get_node("BoiteVis3"), _support(scene, "EtagereBasse"), 3.9, -1.2)
	_put(scene.get_node("Bobine"), _support(scene, "EtagereMuraleA"), 4.75, -3.0)
	_put(scene.get_node("Gants"), _support(scene, "EtagereMuraleB"), 4.75, 2.8)
	_put(scene.get_node("Tasse"), _support(scene, "EtagereMuraleB"), 4.75, 3.2)
	_put(bottes, _support(scene, "Table"), -3.8, -1.5)
	_check(progress.percent() < 100 and not progress.is_restored(), "9 objets sur 10 rangés : < 100 %%, verrou à faux (%d %%)" % progress.percent())
	_put(scene.get_node("Cire"), _support(scene, "Table"), -3.2, -1.5)
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
