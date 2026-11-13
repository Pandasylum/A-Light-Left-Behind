extends SceneTree
## Test de la persistance de la disposition (LayoutState, RoomLayout, Autosave, chargement de partie).
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_disposition.gd

const RANGEMENT_SCENE: String = "res://tests/test_rangement/rangement_test.tscn"
const SPONGE_SCENE: String = "res://tests/test_tools/sponge_test.tscn"
const BUCKET_SCENE: String = "res://props/bucket.tscn"
const SPONGE: String = "res://data/tools/sponge.tres"
const SaveServiceScript: GDScript = preload("res://core/save_service.gd")
const SAVE_DIR: String = "user://test_saves_disposition/"
const AUTO_SLOT: String = "disposition_test"
const ITEMS: String = "Greybox/TestItems/"
const TABLE_ID: String = "Greybox/Supports/TestTable/PlacementSurface"
const SMALL: int = ItemData.Category.SMALL
const MEDIUM: int = ItemData.Category.MEDIUM
const LARGE: int = ItemData.Category.LARGE

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_clear_saves()
	_pure()
	_pure_carry()
	_inventory()
	var section: Dictionary = await _room_roundtrip()
	await _room_faults_and_triggers(section)
	await _room_carry()
	await _game_flow()
	_clear_saves()
	print("test_disposition : %s" % ("OK" if _failures == 0 else "%d ÉCHEC(S)" % _failures))
	quit(1 if _failures > 0 else 0)


# --- Logique pure (aucune scène) ---

func _items() -> Dictionary:
	return {"a": LayoutState.describe_item(false, SMALL), "b": LayoutState.describe_item(false, SMALL),
			"seau": LayoutState.describe_item(false, MEDIUM), "meuble": LayoutState.describe_item(true, LARGE)}


func _supports() -> Dictionary:
	return {"sol": "", "table": "", "meuble/dessus": "meuble", "a/dessus": "a", "b/dessus": "b", "seau/dessus": "seau"}


func _section(objects: Array[Dictionary]) -> Dictionary:
	return _json(LayoutState.make_section(objects))


## Aller-retour par le texte JSON, comme dans le fichier (les nombres reviennent en flottants).
func _json(section: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(section)) as Dictionary


## Section écrite à la main (objets quelconques, portage vide).
func _raw(version: Variant, objects: Variant) -> Dictionary:
	return {"version": version, "objets": objects, "portage": {"main": "", "ceinture": []}}


func _ids(plan: LayoutState.Plan) -> Array:
	return plan.placements.map(func(placement: Dictionary) -> String: return placement["id"])


func _pure() -> void:
	var items: Dictionary = _items()
	var supports: Dictionary = _supports()
	var section: Dictionary = _section([
		LayoutState.make_entry("a", Vector3(1.5, 0.275, -2.125), 0.5, "meuble/dessus", "debout"),
		LayoutState.make_entry("meuble", Vector3(-1.0, 0.225, 3.0), -1.25, "sol"),
		LayoutState.make_entry("seau", Vector3(0.3, 0.9, 0.1), PI * 0.5, "table"),
	])
	_check(section["version"] is float and section.has(LayoutState.OBJECTS_KEY) and section.has(LayoutState.CARRY_KEY),
			"pur : section avec version, objets et portage ; nombres en flottants après le JSON")
	var plan: LayoutState.Plan = LayoutState.parse(section, items, supports)
	_check(plan.accepted and plan.warnings.is_empty() and _ids(plan) == ["a", "meuble", "seau"], "pur : aller-retour, ordre sauvegardé conservé")
	var first: Dictionary = plan.placements[0]
	_check((first["position"] as Vector3).is_equal_approx(Vector3(1.5, 0.275, -2.125)) and is_equal_approx(first["angle"], 0.5)
			and first["posture"] == "debout" and first["support"] == "meuble/dessus", "pur : position, angle, posture et support relus")
	_check(plan.placements[2]["support"] == "table" and plan.placements[2]["posture"] == LayoutState.POSTURE_FLAT
			and is_equal_approx(plan.placements[2]["angle"], PI * 0.5), "pur : seau inclus, posture « a_plat » par défaut")
	var order: Array[Dictionary] = plan.positioning_order()
	_check(order[0]["id"] == "meuble" and order[1]["id"] == "a" and order[2]["id"] == "seau", "pur : meubles libres placés d'abord")

	var empty: LayoutState.Plan = LayoutState.parse({}, items, supports)
	_check(empty.accepted and empty.placements.is_empty() and empty.warnings.is_empty(), "pur : ancien format sans section = rien à restaurer")

	var entry: Dictionary = LayoutState.make_entry("a", Vector3.ZERO, 0.0, "sol")
	var rejected: Dictionary = {
		"section illisible (texte)": "n'importe quoi",
		"section illisible (tableau)": [1, 2],
		"version inconnue": _raw(2, [entry]),
		"version nulle": _raw(0, [entry]),
		"version absente": {"objets": [entry], "portage": {"main": "", "ceinture": []}},
		"version en texte": _raw("1", [entry]),
		"objets absents": {"version": 1, "portage": {"main": "", "ceinture": []}},
		"objets illisibles": _raw(1, "x"),
		"entrée illisible": _raw(1, [entry, 12]),
		"entrée sans identifiant": _raw(1, [{"position": [0, 0, 0]}]),
		"identifiant en double": _raw(1, [entry, LayoutState.make_entry("a", Vector3.ONE, 1.0, "table")]),
		"identifiant inconnu en double": _raw(1, [LayoutState.make_entry("x", Vector3.ZERO, 0.0, "sol"),
				LayoutState.make_entry("x", Vector3.ZERO, 0.0, "sol")]),
	}
	for label: String in rejected:
		var refused: LayoutState.Plan = LayoutState.parse(rejected[label], items, supports)
		_check(not refused.accepted and not refused.error.is_empty() and refused.placements.is_empty(), "pur : %s = toute la section ignorée" % label)

	# Entrées douteuses : chacune est ignorée seule, les autres sont gardées.
	var no_position: Dictionary = entry.duplicate()
	no_position["id"] = "seau"
	no_position["position"] = [0.0, 1.0]
	var faulty: Dictionary = _raw(1.0, [
		LayoutState.make_entry("inconnu", Vector3.ZERO, 0.0, "sol"),
		LayoutState.make_entry("a", Vector3.ZERO, 0.0, "etagere"),
		LayoutState.make_entry("b", Vector3(INF, 0.0, 0.0), 0.0, "sol"),
		no_position,
		LayoutState.make_entry("meuble", Vector3(1.0, 0.2, 1.0), 0.25, "sol"),
	])
	var partial: LayoutState.Plan = LayoutState.parse(faulty, items, supports)
	_check(partial.accepted and _ids(partial) == ["meuble"] and partial.warnings.size() == 4,
			"pur : entrée inconnue, support introuvable, position non finie ou illisible = entrée seule ignorée (%d avertissements)" % partial.warnings.size())
	var nan_angle: LayoutState.Plan = LayoutState.parse(_raw(1, [LayoutState.make_entry("a", Vector3.ZERO, NAN, "sol")]), items, supports)
	_check(nan_angle.accepted and nan_angle.placements.is_empty() and nan_angle.warnings.size() == 1, "pur : angle non fini = entrée ignorée")

	# Support porté par un objet qui n'est pas en place : objet ignoré, boucles comprises.
	var cascade: LayoutState.Plan = LayoutState.parse(_section([
		LayoutState.make_entry("b", Vector3.ZERO, 0.0, "a/dessus"),
		LayoutState.make_entry("a", Vector3.ZERO, 0.0, "etagere"),
		LayoutState.make_entry("seau", Vector3.ZERO, 0.0, "sol"),
	]), items, supports)
	_check(cascade.accepted and _ids(cascade) == ["seau"] and cascade.warnings.size() == 2, "pur : objet posé sur un objet ignoré = ignoré lui aussi")
	var loop: LayoutState.Plan = LayoutState.parse(_section([
		LayoutState.make_entry("a", Vector3.ZERO, 0.0, "b/dessus"),
		LayoutState.make_entry("b", Vector3.ZERO, 0.0, "a/dessus"),
		LayoutState.make_entry("seau", Vector3.ZERO, 0.0, "seau/dessus"),
		LayoutState.make_entry("meuble", Vector3.ZERO, 0.0, "sol"),
	]), items, supports)
	_check(loop.accepted and _ids(loop) == ["meuble"] and loop.warnings.size() == 3, "pur : boucle de supports et objet posé sur lui-même ignorés")
	var stacked: LayoutState.Plan = LayoutState.parse(_section([
		LayoutState.make_entry("b", Vector3.ZERO, 0.0, "a/dessus"),
		LayoutState.make_entry("a", Vector3.ZERO, 0.0, "meuble/dessus"),
		LayoutState.make_entry("meuble", Vector3.ZERO, 0.0, "sol"),
	]), items, supports)
	_check(stacked.accepted and _ids(stacked) == ["b", "a", "meuble"] and stacked.warnings.is_empty(), "pur : pile gardée quel que soit l'ordre des entrées")


func _pure_carry() -> void:
	var items: Dictionary = _items()
	items["c"] = LayoutState.describe_item(false, SMALL)
	items["fixe"] = LayoutState.describe_item(false, ItemData.Category.FIXED)
	var supports: Dictionary = _supports()
	var on_floor: Array[Dictionary] = [LayoutState.make_entry("meuble", Vector3(1.0, 0.2, 1.0), 0.0, "sol")]
	var plan: LayoutState.Plan = LayoutState.parse(_json(LayoutState.make_section(on_floor, "seau", ["", "a", "b"])), items, supports, 3)
	_check(plan.accepted and plan.held == "seau" and plan.belt == ["", "a", "b"] and plan.has_carry() and _ids(plan) == ["meuble"],
			"pur portage : main et ceinture relues par emplacement, dans l'ordre")
	var none: LayoutState.Plan = LayoutState.parse(_section(on_floor), items, supports, 1)
	_check(none.accepted and not none.has_carry() and none.held == "", "pur portage : portage vide accepté")
	var wide: LayoutState.Plan = LayoutState.parse(_json(LayoutState.make_section(on_floor, "", ["a", "", ""])), items, supports, 1)
	_check(wide.accepted and wide.belt[0] == "a", "pur portage : emplacements vides au-delà de la capacité tolérés")
	var no_carry: Dictionary = _section(on_floor)
	no_carry.erase(LayoutState.CARRY_KEY)
	var bad_slot: Dictionary = _section(on_floor)
	bad_slot[LayoutState.CARRY_KEY][LayoutState.BELT_KEY] = [3.0]
	var rejected: Dictionary = {
		"porté et dans la pièce": LayoutState.make_section(on_floor, "meuble"),
		"porté et dans la pièce (entrée ignorée comprise)": LayoutState.make_section(
				[LayoutState.make_entry("a", Vector3.ZERO, 0.0, "etagere")], "a"),
		"plus d'objets en ceinture que la capacité": LayoutState.make_section(on_floor, "", ["a", "b", "c"]),
		"objet en ceinture au-delà de la capacité": LayoutState.make_section(on_floor, "", ["", "", "a"]),
		"objet autre que SMALL en ceinture": LayoutState.make_section(on_floor, "", ["seau"]),
		"identifiant de portage inconnu (main)": LayoutState.make_section(on_floor, "inconnu"),
		"identifiant de portage inconnu (ceinture)": LayoutState.make_section(on_floor, "", ["inconnu"]),
		"objet porté deux fois": LayoutState.make_section(on_floor, "a", ["a"]),
		"objet fixe en main": LayoutState.make_section(on_floor, "fixe"),
		"portage absent": no_carry,
		"portage illisible": bad_slot,
	}
	for label: String in rejected:
		var refused: LayoutState.Plan = LayoutState.parse(_json(rejected[label]), items, supports, 2)
		_check(not refused.accepted and refused.placements.is_empty() and not refused.has_carry() and not refused.error.is_empty(),
				"pur portage : %s = toute la section ignorée" % label)
	# Objet posé sur un objet porté : ignoré seul (son porteur n'est pas dans la pièce).
	var on_carried: LayoutState.Plan = LayoutState.parse(_json(LayoutState.make_section(
			[LayoutState.make_entry("b", Vector3.ZERO, 0.0, "a/dessus")], "a")), items, supports, 1)
	_check(on_carried.accepted and on_carried.held == "a" and on_carried.placements.is_empty() and on_carried.warnings.size() == 1,
			"pur portage : objet posé sur un objet porté = entrée ignorée")


func _item_data(category: ItemData.Category) -> ItemData:
	var data: ItemData = ItemData.new()
	data.category = category
	return data


## CarryInventory (logique pure) : image du portage par emplacement et restauration à l'identique.
func _inventory() -> void:
	var a: ItemData = _item_data(ItemData.Category.SMALL)
	var b: ItemData = _item_data(ItemData.Category.SMALL)
	var medium: ItemData = _item_data(ItemData.Category.MEDIUM)
	var refs: Array[RefCounted] = [RefCounted.new(), RefCounted.new(), RefCounted.new()]
	var state: Dictionary = {"held": medium, "held_ref": refs[0], "belt": [a, null, b], "belt_refs": [refs[1], null, refs[2]]}
	var inventory: CarryInventory = CarryInventory.new(3)
	var events: Array = []
	inventory.held_changed.connect(func(item: ItemData) -> void: events.append(["main", item]))
	inventory.belt_changed.connect(func(slot: int, item: ItemData) -> void: events.append(["ceinture", slot, item]))
	_check(inventory.import_state(state) and inventory.held() == medium and inventory.held_ref() == refs[0] and inventory.belt_item(0) == a
			and inventory.belt_item(1) == null and inventory.belt_ref(2) == refs[2], "inventaire : état restauré, mêmes emplacements")
	_check(events == [["ceinture", 0, a], ["ceinture", 2, b], ["main", medium]], "inventaire : signaux émis pour chaque emplacement restauré")
	_check(inventory.export_state() == state, "inventaire : export identique à l'état importé")
	var copy: CarryInventory = CarryInventory.new(3)
	_check(copy.import_state(inventory.export_state()) and copy.export_state() == state, "inventaire : aller-retour export -> import")
	events.clear()
	var small_capacity: CarryInventory = CarryInventory.new(1)
	_check(not inventory.import_state({"held": null, "belt": [medium]}) and not small_capacity.import_state(state)
			and not inventory.import_state({"held": _item_data(ItemData.Category.FIXED), "belt": []}),
			"inventaire : ceinture non SMALL, capacité dépassée ou FIXED en main = refusé")
	_check(events.is_empty() and inventory.export_state() == state and small_capacity.belt_count() == 0, "inventaire : état refusé = rien ne change")


# --- Pièce de test du rangement (instanciée telle quelle, complétée par le test) ---

## Scène de test du rangement + un seau + un RoomLayout (pièce = la scène). Rien n'est modifié sur disque.
func _room(belt_capacity: int = 1) -> Node3D:
	var scene: Node3D = (load(RANGEMENT_SCENE) as PackedScene).instantiate()
	(scene.get_node("Greybox/Player") as Player).belt_capacity = belt_capacity
	var bucket: Bucket = (load(BUCKET_SCENE) as PackedScene).instantiate() as Bucket
	bucket.name = "Bucket"
	bucket.position = Vector3(3.0, 0.15, 3.0)
	scene.add_child(bucket)
	var layout: RoomLayout = RoomLayout.new()
	layout.name = "Disposition"
	layout.player_path = ^"../Greybox/Player"
	scene.add_child(layout)
	root.add_child(scene)
	return scene


## Pose directe (sans contrôleur) : reprise, déplacement au point (x, z) du dessus de la surface, pose.
func _put(item: TestItem, surface: PlacementSurface, x: float, z: float, yaw: float = 0.0) -> void:
	item.on_picked_up()
	item.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, surface.top_y() + item.item_data.height * 0.5, z))
	item.on_placed(surface)


## État observable de chaque objet suivi : rangé, position, angle, support, charges, posture.
func _snapshot(layout: RoomLayout, service: StorageService) -> Dictionary:
	var result: Dictionary = {}
	for id: String in layout._items:
		var item: TestItem = layout._items[id]
		var loads: Array[String] = []
		for load_body: Node3D in item.loads:
			loads.append((load_body as TestItem).layout_id)
		result[id] = {"stored": service.is_stored(item), "position": item.global_position, "angle": item.global_rotation.y,
				"support": layout._surface_id(item.support_surface) if item.support_surface != null else "",
				"loads": loads, "posture": layout.posture_of(item)}
	return result


func _room_roundtrip() -> Dictionary:
	var scene: Node3D = _room()
	var layout: RoomLayout = scene.get_node("Disposition")
	var service: StorageService = scene.get_node("StorageService")
	var room: Node3D = scene.get_node("Greybox")
	var carry: CarryController = room.get_node("Player/CarryController")
	var floor_surface: PlacementSurface = PlacementSurface.of_body(room.get_node("Floor"))
	var table: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestTable"))
	var pallet: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestPallet"))
	var plot: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestPlot"))
	var items: Node = room.get_node("TestItems")
	var low: TestItem = items.get_node("furniture_low")
	var small_1: TestItem = items.get_node("small_1")
	var small_3: TestItem = items.get_node("small_3")
	var small_4: TestItem = items.get_node("small_4")
	var small_5: TestItem = items.get_node("small_5")
	var small_7: TestItem = items.get_node("small_7")
	var bucket: TestItem = scene.get_node("Bucket")
	_check(small_1.layout_id == ITEMS + "small_1" and bucket.layout_id == "Bucket" and layout._items.size() == 13,
			"pièce : identifiant = chemin depuis la racine de la pièce (%d objets suivis, seau compris)" % layout._items.size())
	await service.room_evaluated
	await physics_frame

	# Disposition : meuble libre déplacé et tourné, chargé de deux objets (dans l'ordre inverse de
	# l'arbre) dont l'un porte un troisième ; palette, table, plot ; seau ; un objet tenu.
	_put(low, floor_surface, -1.3, 3.3, 0.4)
	var low_top: PlacementSurface = PlacementSurface.of_body(low)
	var on_low_a: Vector3 = low.global_transform * Vector3(0.25, 0.0, 0.0)
	var on_low_b: Vector3 = low.global_transform * Vector3(-0.25, 0.0, 0.1)
	_put(small_4, low_top, on_low_a.x, on_low_a.z, 0.7)
	_put(small_3, low_top, on_low_b.x, on_low_b.z, -0.3)
	_put(small_5, PlacementSurface.of_body(small_4), on_low_a.x, on_low_a.z, 1.9)
	_put(small_1, pallet, -3.3, -0.4, 1.1)
	_put(items.get_node("medium_1") as TestItem, table, 3.2, -0.5, -2.2)
	_put(items.get_node("small_2") as TestItem, plot, 3.5, 1.5, 0.2)
	_put(bucket, table, 3.8, -0.5, 2.0)
	layout.set_posture(small_1, "debout")
	carry.pick_up(small_7.get_node("Interactable"))
	_check(carry.held_body() == small_7, "pièce : un objet est tenu au moment de la sauvegarde")
	var before: Dictionary = _snapshot(layout, service)
	var stored_count: int = before.values().filter(func(state: Dictionary) -> bool: return state["stored"]).size()
	_check(stored_count >= 4 and stored_count < before.size(), "pièce : %d objets rangés sur %d avant la sauvegarde" % [stored_count, before.size()])
	_check(before[low.layout_id]["loads"] == [small_4.layout_id, small_3.layout_id] and before[small_4.layout_id]["loads"] == [small_5.layout_id],
			"pièce : meuble libre chargé de deux objets, pile de deux")

	var section: Dictionary = _json(layout.export_state())
	var written: Array = (section[LayoutState.OBJECTS_KEY] as Array).map(func(entry: Dictionary) -> String: return entry["id"])
	_check(written.size() == 12 and not written.has(small_7.layout_id) and section[LayoutState.CARRY_KEY][LayoutState.HELD_KEY] == small_7.layout_id
			and section[LayoutState.CARRY_KEY][LayoutState.BELT_KEY] == [""], "export : 12 objets posés écrits, l'objet tenu écrit dans le portage seulement")
	_check(written.has("Bucket") and written.find(small_4.layout_id) < written.find(small_3.layout_id),
			"export : seau inclus, charges du meuble dans l'ordre de ses charges")
	var entry_size: int = JSON.stringify(section[LayoutState.OBJECTS_KEY]).length() / written.size()
	print("mesure : %d octets par objet dans la section « disposition »" % entry_size)
	scene.queue_free()
	await process_frame

	# Rechargement : nouvelle scène, restauration avant l'évaluation du rangement.
	var scene_b: Node3D = _room()
	var layout_b: RoomLayout = scene_b.get_node("Disposition")
	var service_b: StorageService = scene_b.get_node("StorageService")
	var deposits: Array = []
	layout_b.item_deposited.connect(func(item: TestItem) -> void: deposits.append(item))
	var events: Array = []
	service_b.stored_changed.connect(func(item: TestItem, stored: bool) -> void: events.append([item, stored]))
	_check(layout_b.restore(section), "rechargement : section acceptée")
	_check(events.is_empty(), "rechargement : rangement évalué après la restauration complète, pas pendant")
	await service_b.room_evaluated
	var after: Dictionary = _snapshot(layout_b, service_b)
	var same_stored: bool = true
	var same_layout: bool = true
	for id: String in before:
		same_stored = same_stored and before[id]["stored"] == after[id]["stored"]
		if not written.has(id):
			continue
		var a: Dictionary = before[id]
		var b: Dictionary = after[id]
		var same: bool = (a["position"] as Vector3).distance_to(b["position"]) < 0.0001 and absf(angle_difference(a["angle"], b["angle"])) < 0.0001 \
				and a["support"] == b["support"] and a["loads"] == b["loads"] and a["posture"] == b["posture"]
		if not same:
			print("  différence sur %s : %s -> %s" % [id, a, b])
		same_layout = same_layout and same
	_check(same_layout, "rechargement : position, angle, posture, support et charges identiques pour les 12 objets")
	_check(same_stored and events.size() == stored_count, "rechargement : état « rangé » identique pour chaque objet (%d signaux)" % events.size())
	var low_b: TestItem = scene_b.get_node(ITEMS + "furniture_low")
	var bucket_b: TestItem = scene_b.get_node("Bucket")
	_check(after[low_b.layout_id]["loads"] == [ITEMS + "small_4", ITEMS + "small_3"] and after[ITEMS + "small_4"]["loads"] == [ITEMS + "small_5"]
			and low_b.has_loads(), "rechargement : charges du meuble reconstruites dans l'ordre, pile comprise")
	_check(after["Bucket"]["support"] == TABLE_ID and bucket_b.placement_restored and after[ITEMS + "small_1"]["posture"] == "debout",
			"rechargement : seau sur la table, posture relue")
	var small_7_b: TestItem = layout_b._items[ITEMS + "small_7"]
	var carry_b: CarryController = scene_b.get_node("Greybox/Player/CarryController")
	_check(carry_b.held_body() == small_7_b and small_7_b.get_parent().name == "HandAnchor" and small_7_b.support_surface == null
			and not service_b.is_stored(small_7_b), "rechargement : l'objet tenu est de nouveau en main, non rangé")
	_check(deposits.is_empty(), "rechargement : aucun dépôt signalé (aucun déclencheur)")
	var again: Array = (layout_b.export_state()[LayoutState.OBJECTS_KEY] as Array).map(func(entry: Dictionary) -> String: return entry["id"])
	_check(again.slice(0, written.size()) == written or again.filter(func(id: String) -> bool: return written.has(id)) == written,
			"rechargement : nouvel export dans le même ordre")
	scene_b.queue_free()
	await process_frame
	return section


func _drain(autosave: Autosave) -> int:
	var frames: int = 0
	while autosave.is_busy() and frames < 2000:
		autosave.advance()
		frames += 1
	return frames


func _saved(service: Node, slot: String) -> Dictionary:
	var loaded: Dictionary = service.call("load_slot", slot)
	return loaded["data"] as Dictionary if loaded["ok"] else {}


func _entry_of(data: Dictionary, id: String) -> Dictionary:
	for entry: Dictionary in (data.get(LayoutState.SAVE_KEY, {}) as Dictionary).get(LayoutState.OBJECTS_KEY, []):
		if entry["id"] == id:
			return entry
	return {}


func _aim_at(player: Player, pos: Vector3, target: Vector3) -> void:
	player.global_position = pos
	var dir: Vector3 = target - player.get_node("Head/Camera3D").global_position
	player.rotation.y = atan2(-dir.x, -dir.z)
	player.head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())


func _room_faults_and_triggers(valid: Dictionary) -> void:
	var scene: Node3D = _room()
	var layout: RoomLayout = scene.get_node("Disposition")
	var service: StorageService = scene.get_node("StorageService")
	var room: Node3D = scene.get_node("Greybox")
	var player: Player = room.get_node("Player")
	var carry: CarryController = player.get_node("CarryController")
	var placement: PlacementController = player.get_node("PlacementController")
	var small_1: TestItem = scene.get_node(ITEMS + "small_1")
	var small_2: TestItem = scene.get_node(ITEMS + "small_2")
	var small_6: TestItem = scene.get_node(ITEMS + "small_6")
	var table: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestTable"))
	var start: Vector3 = small_1.global_position

	# Sections rejetées en entier : rien ne bouge (avertissements attendus dans le journal).
	var double: Dictionary = valid.duplicate(true)
	(double[LayoutState.OBJECTS_KEY] as Array).append((double[LayoutState.OBJECTS_KEY] as Array)[0])
	var unknown_version: Dictionary = valid.duplicate(true)
	unknown_version["version"] = 99.0
	for refused: Variant in ["corrompue", unknown_version, double]:
		_check(not layout.restore(refused), "pièce : section rejetée en entier")
	_check(small_1.global_position == start and small_1.support_surface == null and not small_1.placement_restored,
			"pièce : section corrompue, version inconnue ou identifiant en double = disposition initiale")
	_check(layout.restore({}), "pièce : ancien format sans section accepté, rien à restaurer")

	# Entrées ignorées seules : objet inconnu, support introuvable ; l'entrée valable est appliquée.
	var partial: Dictionary = _section([
		LayoutState.make_entry(ITEMS + "absent", Vector3.ZERO, 0.0, "sol"),
		LayoutState.make_entry(small_2.layout_id, Vector3(2.0, 1.0, 2.0), 0.0, "Greybox/Supports/Absent/PlacementSurface"),
		LayoutState.make_entry(small_1.layout_id, Vector3(-3.3, 0.2, -0.4), 1.1, "Greybox/Supports/TestPallet/PlacementSurface"),
	])
	_check(layout.restore(partial), "pièce : section partiellement valable acceptée")
	await service.room_evaluated
	_check(small_1.global_position.is_equal_approx(Vector3(-3.3, 0.2, -0.4)) and service.is_stored(small_1), "pièce : entrée valable restaurée et rangée")
	_check(small_2.global_position.is_equal_approx(Vector3(-1.0, 0.1, -1.8)) and small_2.support_surface != null and small_2.support_surface.is_floor
			and not small_2.placement_restored, "pièce : entrée au support introuvable = objet à sa place initiale (support retrouvé comme avant)")
	await physics_frame

	# Déclencheur : le dépôt validé seul (chute comprise) demande une sauvegarde.
	var save_service: Node = SaveServiceScript.new() as Node
	save_service.set("save_dir", SAVE_DIR)
	var autosave: Autosave = Autosave.new()
	autosave.handle_quit = false
	autosave.slot_id = AUTO_SLOT
	root.add_child(autosave)
	autosave.setup(scene, player.get_node("ToolController") as ToolController, save_service)
	autosave.watch_layout(layout)
	carry.pick_up(small_1.get_node("Interactable"))
	_check(carry.held_body() == small_1 and autosave.triggers_received == 0 and not autosave.is_busy(), "déclencheur : une prise ne déclenche rien")
	carry.pick_up(small_6.get_node("Interactable"))
	_check(carry.inventory.belt_ref(0) == small_6 and autosave.triggers_received == 0, "déclencheur : un changement de ceinture ne déclenche rien")
	carry.cycle()
	_check(carry.held_body() == small_6 and carry.inventory.belt_ref(0) == small_1 and autosave.triggers_received == 0, "déclencheur : cycle_item ne déclenche rien")
	carry.cycle()
	_aim_at(player, Vector3(4.1, 0.05, 0.7), Vector3(4.095, table.top_y(), -0.5))
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.UNSTABLE, "déclencheur : pose instable au bord de la table (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(small_1.support_surface != null and small_1.support_surface.is_floor and autosave.triggers_received == 1 and autosave.is_busy(),
			"déclencheur : un dépôt suivi d'une chute déclenche une sauvegarde")
	_drain(autosave)
	var data: Dictionary = _saved(save_service, AUTO_SLOT)
	_check(autosave.writes_requested == 1 and data.has(Autosave.CLEANING_KEY) and data.has(ToolSlots.SAVE_KEY) and data.has(LayoutState.SAVE_KEY),
			"autosave : une écriture, section « disposition » à côté de « nettoyage » et « outils »")
	var saved_carry: Dictionary = data[LayoutState.SAVE_KEY][LayoutState.CARRY_KEY]
	_check(_entry_of(data, small_1.layout_id).get("support") == LayoutState.FLOOR_ID and _entry_of(data, small_6.layout_id).is_empty()
			and saved_carry[LayoutState.HELD_KEY] == "" and saved_carry[LayoutState.BELT_KEY] == [small_6.layout_id],
			"autosave : objet tombé écrit au sol, objet en ceinture écrit dans le portage seulement")
	await physics_frame
	carry.pick_up(small_1.get_node("Interactable"))
	_check(carry.held_body() == small_1 and autosave.triggers_received == 1, "déclencheur : la reprise n'est pas un dépôt")
	_aim_at(player, Vector3(3.2, 0.05, 0.7), Vector3(3.2, table.top_y(), -0.2))
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.OK, "déclencheur : pose valide sur la table (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(small_1.support_surface == table and autosave.triggers_received == 2, "déclencheur : un dépôt validé déclenche une sauvegarde")
	_drain(autosave)
	var entry: Dictionary = _entry_of(_saved(save_service, AUTO_SLOT), small_1.layout_id)
	var saved_position: Array = entry.get("position", [0.0, 0.0, 0.0])
	_check(entry.get("support") == TABLE_ID and Vector3(saved_position[0], saved_position[1], saved_position[2]).distance_to(small_1.global_position) < 0.0001
			and entry.get("posture") == LayoutState.POSTURE_FLAT, "autosave : objet déposé écrit avec sa position et son support")
	autosave.queue_free()
	scene.queue_free()
	await process_frame
	save_service.free()


## Dépôt direct de l'objet en main, comme PlacementController.place_held() après validation.
func _deposit(carry: CarryController, root_node: Node, surface: PlacementSurface, x: float, z: float) -> void:
	var data: ItemData = carry.held_data()
	var placed: Node3D = carry.release_held()
	placed.reparent(root_node, false)
	placed.global_transform = Transform3D(Basis.IDENTITY, Vector3(x, surface.top_y() + data.height * 0.5, z))
	(placed as CollisionObject3D).collision_layer = 4
	placed.visible = true
	placed.call(&"on_placed", surface)


func _room_carry() -> void:
	# Portage avec un emplacement vide au milieu : main small_2, ceinture [vide, small_3, vide].
	var scene: Node3D = _room(3)
	var layout: RoomLayout = scene.get_node("Disposition")
	var service: StorageService = scene.get_node("StorageService")
	var room: Node3D = scene.get_node("Greybox")
	var carry: CarryController = room.get_node("Player/CarryController")
	var floor_surface: PlacementSurface = PlacementSurface.of_body(room.get_node("Floor"))
	await service.room_evaluated
	await physics_frame
	for short: String in ["small_1", "small_2", "small_3"]:
		carry.pick_up(scene.get_node(ITEMS + short + "/Interactable"))
	_deposit(carry, room.get_node("PlacedObjects"), floor_surface, 0.5, 0.5)
	carry.cycle()
	var small_2_id: String = ITEMS + "small_2"
	var small_3_id: String = ITEMS + "small_3"
	var section: Dictionary = _json(layout.export_state())
	var written: Array = (section[LayoutState.OBJECTS_KEY] as Array).map(func(entry: Dictionary) -> String: return entry["id"])
	_check(section[LayoutState.CARRY_KEY] == {LayoutState.HELD_KEY: small_2_id, LayoutState.BELT_KEY: ["", small_3_id, ""]},
			"portage : main et ceinture écrites par emplacement, dans l'ordre exact")
	_check(written.has(ITEMS + "small_1") and not written.has(small_2_id) and not written.has(small_3_id),
			"portage : un objet porté n'est jamais écrit dans les objets de pièce")
	scene.queue_free()
	await process_frame

	var scene_b: Node3D = _room(3)
	var layout_b: RoomLayout = scene_b.get_node("Disposition")
	var service_b: StorageService = scene_b.get_node("StorageService")
	var room_b: Node3D = scene_b.get_node("Greybox")
	var player_b: Player = room_b.get_node("Player")
	var carry_b: CarryController = player_b.get_node("CarryController")
	var placement_b: PlacementController = player_b.get_node("PlacementController")
	var panel_b: InventoryPanel = player_b.get_node("InventoryPanel")
	var small_2: TestItem = scene_b.get_node(small_2_id)
	var small_3: TestItem = scene_b.get_node(small_3_id)
	var save_service: Node = SaveServiceScript.new() as Node
	save_service.set("save_dir", SAVE_DIR)
	var autosave: Autosave = Autosave.new()
	autosave.handle_quit = false
	autosave.slot_id = AUTO_SLOT
	root.add_child(autosave)
	autosave.setup(scene_b, player_b.get_node("ToolController") as ToolController, save_service)
	autosave.watch_layout(layout_b)
	var signals: Array = []
	carry_b.inventory.held_changed.connect(func(item: ItemData) -> void: signals.append(["main", item]))
	carry_b.inventory.belt_changed.connect(func(slot: int, item: ItemData) -> void: signals.append(["ceinture", slot, item]))
	carry_b.held_changed.connect(func() -> void: signals.append(["controleur"]))
	_check(layout_b.restore(section), "portage : section acceptée")
	var anchor: Node = player_b.get_node("Head/HandAnchor")
	_check(carry_b.held_body() == small_2 and carry_b.inventory.belt_ref(0) == null and carry_b.inventory.belt_ref(1) == small_3
			and carry_b.inventory.belt_ref(2) == null, "portage : objets remis en main et en ceinture, mêmes emplacements")
	_check(small_2.get_parent() == anchor and small_3.get_parent() == anchor and small_2.visible and not small_3.visible
			and small_2.collision_layer == 0 and small_3.collision_layer == 0 and small_2.support_surface == null,
			"portage : mêmes effets que la prise (HandAnchor, ceinture masquée, collision coupée)")
	_check(signals == [["ceinture", 1, small_3.item_data], ["main", small_2.item_data], ["controleur"]],
			"portage : belt_changed et held_changed émis normalement (%d signaux)" % signals.size())
	_check(panel_b.held_text() == InventoryPanel.item_name(small_2.item_data) and StorageService.items_under(scene_b).size() == 13,
			"portage : InventoryPanel à jour, aucun objet dupliqué")
	await service_b.room_evaluated
	_check(not service_b.is_stored(small_2) and not service_b.is_stored(small_3) and small_2.support_surface == null and small_3.support_surface == null,
			"portage : un objet porté est non rangé, aucun support cherché pour lui")
	_check(autosave.triggers_received == 0 and not autosave.is_busy(), "portage : la restauration n'émet aucune demande de sauvegarde")
	await physics_frame
	# Le portage restauré se dépose normalement, et ce dépôt déclenche une sauvegarde.
	var table: PlacementSurface = PlacementSurface.of_body(room_b.get_node("Supports/TestTable"))
	_aim_at(player_b, Vector3(3.2, 0.05, 0.7), Vector3(3.2, table.top_y(), -0.2))
	await physics_frame
	placement_b._update_target()
	placement_b.place_held()
	_check(small_2.support_surface == table and carry_b.held_body() == null and autosave.triggers_received == 1,
			"portage : l'objet restauré en main se dépose et déclenche une sauvegarde")
	_drain(autosave)
	var data: Dictionary = _saved(save_service, AUTO_SLOT)
	_check(_entry_of(data, small_2_id).get("support") == TABLE_ID and data[LayoutState.SAVE_KEY][LayoutState.CARRY_KEY]
			== {LayoutState.HELD_KEY: "", LayoutState.BELT_KEY: ["", small_3_id, ""]}, "portage : après le dépôt, objet dans la pièce et plus dans le portage")
	autosave.queue_free()
	scene_b.queue_free()
	await process_frame

	# Incohérences : toute la section est ignorée (capacité de ceinture 1 ici).
	var scene_c: Node3D = _room(1)
	var layout_c: RoomLayout = scene_c.get_node("Disposition")
	var player_c: Player = scene_c.get_node("Greybox/Player")
	var carry_c: CarryController = player_c.get_node("CarryController")
	var tools_c: ToolController = player_c.get_node("ToolController")
	var small_1_c: TestItem = scene_c.get_node(ITEMS + "small_1")
	var start: Vector3 = small_1_c.global_position
	var on_floor: Array[Dictionary] = [LayoutState.make_entry(ITEMS + "small_1", Vector3(1.0, 0.05, 1.0), 0.0, "sol")]
	var refused: Dictionary = {
		"plus d'objets en ceinture que la capacité": LayoutState.make_section(on_floor, "", [small_2_id, small_3_id]),
		"objet à la fois porté et dans la pièce": LayoutState.make_section(on_floor, ITEMS + "small_1", [""]),
		"objet autre que SMALL en ceinture": LayoutState.make_section(on_floor, "", [ITEMS + "medium_1"]),
		"identifiant de portage inconnu": LayoutState.make_section(on_floor, ITEMS + "absent", [""]),
	}
	for label: String in refused:
		_check(not layout_c.restore(_json(refused[label])) and carry_c.held_body() == null and carry_c.inventory.belt_count() == 0
				and small_1_c.global_position == start, "incohérence (%s) : disposition initiale, portage vide" % label)
	# Ceinture seule avec un outil en main : état permis, l'outil reste en main.
	var autosave_c: Autosave = Autosave.new()
	autosave_c.handle_quit = false
	autosave_c.slot_id = AUTO_SLOT
	root.add_child(autosave_c)
	autosave_c.setup(scene_c, tools_c, save_service)
	autosave_c.watch_layout(layout_c)
	tools_c.add_tool(load(SPONGE) as ToolData)
	tools_c.take_out(0)
	var small_3_c: TestItem = scene_c.get_node(small_3_id)
	_check(layout_c.restore(_json(LayoutState.make_section(on_floor, "", [small_3_id]))) and carry_c.inventory.belt_ref(0) == small_3_c
			and carry_c.held_body() == null and not small_3_c.visible, "portage : ceinture restaurée seule, main vide")
	_check(tools_c.held_tool() != null and autosave_c.triggers_received == 0 and small_1_c.global_position.is_equal_approx(Vector3(1.0, 0.05, 1.0)),
			"portage : l'outil en main y reste (état permis), aucun déclencheur, pièce restaurée")
	autosave_c.queue_free()
	scene_c.queue_free()
	await process_frame
	save_service.free()


# --- Partie réelle : scène de jeu provisoire, fichier « partie », Continuer ---

func _game_flow() -> void:
	var service: Node = root.get_node_or_null("SaveService")
	var own_service: bool = service == null
	if own_service:
		service = SaveServiceScript.new() as Node
		service.name = "SaveService"
		root.add_child(service)
	var previous_dir: Variant = service.get("save_dir")
	service.set("save_dir", SAVE_DIR)
	GameFlow.continue_requested = false

	var scene: Node3D = (load(SPONGE_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var autosave: Autosave = scene.get_node("Autosave")
	var layout: RoomLayout = scene.get_node("Disposition")
	var bucket: TestItem = scene.get_node("Bucket")
	var item: TestItem = scene.get_node("TestItem")
	var carry: CarryController = scene.get_node("Tour/Player/CarryController")
	var floor_surface: PlacementSurface = PlacementSurface.of_body(scene.get_node("Tour/Floor"))
	_check(autosave.layout == layout and autosave.service == service and bucket.layout_id == "Bucket" and item.layout_id == "TestItem",
			"partie : Autosave relié au RoomLayout de la scène, objets suivis")
	_check(bucket.support_surface == floor_surface and autosave.triggers_received == 0 and not autosave.is_busy(),
			"partie : la pose initiale des objets ne déclenche aucune sauvegarde")
	var item_start: Vector3 = item.global_position

	# Image figée au début de l'export étalé ; export repris du début = image figée de nouveau.
	autosave.export_budget_usec = 0
	_put(bucket, floor_surface, 2.4, 0.9, 0.7)
	_check(autosave.triggers_received == 1, "partie : dépôt du seau = un déclencheur")
	autosave.advance()
	autosave.advance()
	_put(item, floor_surface, 2.0, 1.3, -0.4)
	_check(autosave.triggers_received == 2 and autosave.is_busy(), "partie : dépôt pendant l'export = export repris du début")
	autosave.advance()
	autosave.advance()
	var item_placed: Vector3 = item.global_position
	carry.pick_up(item.get_node("Interactable"))
	_check(carry.held_body() == item and autosave.triggers_received == 2, "partie : prise pendant l'export, aucun déclencheur")
	var frames: int = _drain(autosave)
	var data: Dictionary = _saved(service, Autosave.SLOT_ID)
	var item_entry: Array = _entry_of(data, "TestItem").get("position", [0.0, 0.0, 0.0])
	_check(frames > 10 and autosave.writes_requested == 1 and not _entry_of(data, "Bucket").is_empty()
			and Vector3(item_entry[0], item_entry[1], item_entry[2]).distance_to(item_placed) < 0.0001,
			"partie : une écriture, disposition = image figée au (re)début de l'export (%d images)" % frames)
	# Sortie : la sauvegarde avec attente enregistre le portage du moment.
	_check(autosave.save_and_wait() == 0, "partie : sauvegarde de sortie écrite")
	data = _saved(service, Autosave.SLOT_ID)
	_check(_entry_of(data, "TestItem").is_empty() and _entry_of(data, "Bucket").get("support") == LayoutState.FLOOR_ID
			and data[LayoutState.SAVE_KEY][LayoutState.CARRY_KEY][LayoutState.HELD_KEY] == "TestItem",
			"partie : à la sortie, l'objet tenu est écrit dans le portage, pas dans la pièce")
	var bucket_at: Transform3D = bucket.global_transform
	scene.queue_free()
	await process_frame

	# Continuer : la disposition est restaurée, sans pose initiale ni déclencheur.
	GameFlow.continue_requested = true
	var scene_b: Node3D = (load(SPONGE_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(scene_b)
	await physics_frame
	await physics_frame
	var bucket_b: TestItem = scene_b.get_node("Bucket")
	var item_b: TestItem = (scene_b.get_node("Disposition") as RoomLayout)._items["TestItem"]
	var autosave_b: Autosave = scene_b.get_node("Autosave")
	var carry_b: CarryController = scene_b.get_node("Tour/Player/CarryController")
	var panel_b: InventoryPanel = scene_b.get_node("Tour/Player/InventoryPanel")
	_check(not GameFlow.continue_requested and bucket_b.global_position.distance_to(bucket_at.origin) < 0.0001
			and absf(angle_difference(bucket_b.global_rotation.y, 0.7)) < 0.0001 and bucket_b.placement_restored
			and bucket_b.support_surface == PlacementSurface.of_body(scene_b.get_node("Tour/Floor")),
			"Continuer : seau restauré à sa position, son angle et son support")
	_check(carry_b.held_body() == item_b and item_b.get_parent().name == "HandAnchor" and item_b.visible and item_b.collision_layer == 0
			and item_b.support_surface == null and item_b.global_position.distance_to(item_start) > 0.5,
			"Continuer : l'objet tenu à la sortie est de nouveau en main (pas laissé à sa place initiale, pas reposé au sol)")
	_check(panel_b.held_text() != "" and StorageService.items_under(scene_b).size() == 2, "Continuer : InventoryPanel à jour, aucun objet dupliqué")
	_check(autosave_b.triggers_received == 0 and not autosave_b.is_busy(), "Continuer : le chargement ne déclenche aucune sauvegarde")

	# Seau en main, objet rangé d'office en ceinture ; fichier modifié : l'outil aussi est « en main ».
	carry_b.pick_up(bucket_b.get_node("Interactable"))
	_check(carry_b.held_body() == bucket_b and carry_b.inventory.belt_ref(0) == item_b and autosave_b.triggers_received == 0,
			"partie : seau en main, objet en ceinture, aucun déclencheur")
	_check(autosave_b.save_and_wait() == 0, "partie : sauvegarde de sortie avec main et ceinture")
	data = _saved(service, Autosave.SLOT_ID)
	var carry_section: Dictionary = data[LayoutState.SAVE_KEY][LayoutState.CARRY_KEY]
	_check(carry_section[LayoutState.HELD_KEY] == "Bucket" and carry_section[LayoutState.BELT_KEY] == ["TestItem"]
			and (data[LayoutState.SAVE_KEY][LayoutState.OBJECTS_KEY] as Array).is_empty(), "partie : main + ceinture écrits, plus aucun objet dans la pièce")
	data[ToolSlots.SAVE_KEY]["emplacements"][0]["en_main"] = true
	_check(service.call("save_slot", Autosave.SLOT_ID, data) == 0, "fichier modifié : outil et objet en main")
	scene_b.queue_free()
	await process_frame
	GameFlow.continue_requested = true
	var scene_d: Node3D = (load(SPONGE_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(scene_d)
	await physics_frame
	await physics_frame
	var layout_d: RoomLayout = scene_d.get_node("Disposition")
	var carry_d: CarryController = scene_d.get_node("Tour/Player/CarryController")
	var tools_d: ToolController = scene_d.get_node("Tour/Player/ToolController")
	var autosave_d: Autosave = scene_d.get_node("Autosave")
	var bucket_d: TestItem = layout_d._items["Bucket"]
	var item_d: TestItem = layout_d._items["TestItem"]
	_check(carry_d.held_body() == bucket_d and carry_d.inventory.belt_ref(0) == item_d and bucket_d.visible and not item_d.visible
			and item_d.get_parent().name == "HandAnchor" and item_d.collision_layer == 0, "Continuer : seau en main, objet masqué en ceinture, même emplacement")
	_check(tools_d.held_tool() == null and tools_d.slots.count() == 1, "Continuer : objet et outil en main = objet gardé, outil rangé (avertissement au journal)")
	_check(autosave_d.triggers_received == 0 and not autosave_d.is_busy() and not layout_d.restoring,
			"Continuer : l'outil rangé par la remise en main ne déclenche aucune sauvegarde")
	scene_d.queue_free()
	await process_frame

	# Ancien format : fichier sans section « disposition ».
	_check(service.call("save_slot", Autosave.SLOT_ID, {Autosave.CLEANING_KEY: {}}) == 0, "ancien format : fichier sans section écrit")
	GameFlow.continue_requested = true
	var scene_c: Node3D = (load(SPONGE_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(scene_c)
	await physics_frame
	await physics_frame
	var bucket_c: TestItem = scene_c.get_node("Bucket")
	_check(not GameFlow.continue_requested and absf(bucket_c.global_position.x - 1.75) < 0.0001 and absf(bucket_c.global_position.z - 0.1) < 0.0001
			and bucket_c.support_surface != null and bucket_c.support_surface.is_floor and not bucket_c.placement_restored
			and (scene_c.get_node("Autosave") as Autosave).triggers_received == 0,
			"ancien format sans section : disposition initiale de la scène, aucun déclencheur")
	scene_c.queue_free()
	await process_frame

	service.set("save_dir", previous_dir)
	if own_service:
		service.queue_free()
		await process_frame


func _clear_saves() -> void:
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	for file: String in dir.get_files():
		dir.remove(file)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK    : " + label)
	else:
		_failures += 1
		printerr("ÉCHEC : " + label)
