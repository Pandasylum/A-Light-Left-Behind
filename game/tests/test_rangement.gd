extends SceneTree
## Rangement (lot 1) : règles pures (StorageRules), volume d'une zone (StorageZone), puis cas en scène
## dans rangement_test.tscn (StorageService, signal stored_changed). Le contrôleur est forcé actif comme
## dans test_phase1_flow.gd (souris non capturée en headless : appels directs, visée forcée).
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_rangement.gd

const SMALL: ItemData.Category = ItemData.Category.SMALL
const MEDIUM: ItemData.Category = ItemData.Category.MEDIUM
const LARGE: ItemData.Category = ItemData.Category.LARGE
const FIXED: ItemData.Category = ItemData.Category.FIXED

var _failures: int = 0
## Émissions de stored_changed depuis le dernier _take_events() : [objet, état].
var _events: Array = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_rules()
	await _zone_volume()
	await _scene()
	print("test_rangement : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _zone(id: StringName, categories: Array[ItemData.Category]) -> ZoneData:
	var zone: ZoneData = ZoneData.new()
	zone.id = id
	zone.accepted_categories = categories
	return zone


## Logique pure : aucune scène.
func _rules() -> void:
	var any: ZoneData = _zone(&"toutes", [SMALL, MEDIUM, LARGE])
	var small_only: ZoneData = _zone(&"petits", [SMALL])
	_check(any.validate().is_empty() and small_only.validate().is_empty(), "règles : ZoneData de test valides")
	_check(StorageRules.accepts(any, MEDIUM) and StorageRules.accepts(small_only, SMALL), "accepts : catégorie listée")
	_check(not StorageRules.accepts(small_only, MEDIUM), "accepts : catégorie non listée")
	_check(not StorageRules.accepts(null, SMALL) and not StorageRules.accepts(any, FIXED), "accepts : zone absente, FIXED")

	# [libellé, sur support déclaré non-sol, catégorie, zones contenant l'objet, attendu]
	var cases: Array = [
		["support déclaré + zone acceptante = rangé", true, SMALL, [any], true],
		["support déclaré + catégorie refusée = non", true, MEDIUM, [small_only], false],
		["support déclaré + hors de toute zone = non", true, SMALL, [], false],
		["sol, objet ordinaire ou tenu (pas de support déclaré) + zone acceptante = non", false, SMALL, [any], false],
		["pas de support déclaré, hors zone = non", false, SMALL, [], false],
		["deux zones, une seule acceptante = rangé", true, MEDIUM, [small_only, any], true],
		["meuble libre LARGE sur support déclaré + zone acceptante = rangé", true, LARGE, [any], true],
	]
	for case: Array in cases:
		var zones: Array[ZoneData] = []
		zones.assign(case[3])
		_check(StorageRules.is_stored(case[1], case[2], zones) == case[4], "is_stored : %s" % case[0])

	_check(StorageRules.footprint_center(Vector3(1.0, 0.5, 2.0), Vector3.UP, 0.4).is_equal_approx(Vector3(1.0, 0.3, 2.0)),
			"footprint_center : base de l'objet")
	var size: Vector3 = Vector3(2.0, 1.0, 4.0)
	_check(StorageRules.box_contains(size, Vector3.ZERO) and StorageRules.box_contains(size, Vector3(1.0, -0.5, 2.0)),
			"box_contains : centre et bord")
	_check(not StorageRules.box_contains(size, Vector3(1.01, 0.0, 0.0)) and not StorageRules.box_contains(size, Vector3(0.0, 0.51, 0.0))
			and not StorageRules.box_contains(size, Vector3(0.0, 0.0, -2.01)), "box_contains : dehors sur chaque axe")


## Volume d'une zone construite par code : boîte déplacée et tournée, deux boîtes, aucune couche physique.
func _zone_volume() -> void:
	var zone: StorageZone = StorageZone.new()
	zone.zone_data = _zone(&"volume", [SMALL])
	var first: CollisionShape3D = _box(Vector3(2.0, 1.0, 0.4))
	var second: CollisionShape3D = _box(Vector3(0.2, 0.2, 0.2))
	second.position = Vector3(0.0, 3.0, 0.0)
	zone.add_child(first)
	zone.add_child(second)
	zone.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(10.0, 0.0, 0.0))
	root.add_child(zone)
	await process_frame
	_check(zone.contains_point(Vector3(10.0, 0.0, 0.9)) and not zone.contains_point(Vector3(10.9, 0.0, 0.0)),
			"zone tournée de 90° : volume tourné avec elle")
	_check(zone.contains_point(Vector3(10.0, 3.05, 0.0)) and not zone.contains_point(Vector3(10.0, 2.0, 0.0)),
			"zone à deux boîtes : union des volumes")
	_check(zone.collision_layer == 0 and zone.collision_mask == 0 and not zone.monitoring and not zone.monitorable
			and zone.is_in_group(StorageZone.GROUP), "zone : aucune surveillance ni couche physique, groupe des zones")
	_check(zone.get_signal_connection_list(&"body_entered").is_empty() and zone.get_signal_connection_list(&"body_exited").is_empty(),
			"zone : body_entered/body_exited non utilisés")
	zone.queue_free()
	await process_frame


func _box(size: Vector3) -> CollisionShape3D:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	return shape


## Cas en scène : rangement_test.tscn (greybox + zones de test + un objet déjà posé sur la palette).
func _scene() -> void:
	var scene: Node3D = (load("res://tests/test_rangement/rangement_test.tscn") as PackedScene).instantiate()
	var service: StorageService = scene.get_node("StorageService")
	service.stored_changed.connect(func(item: TestItem, stored: bool) -> void: _events.append([item, stored]))
	root.add_child(scene)
	var room: Node3D = scene.get_node("Greybox")
	var player: Player = room.get_node("Player")
	var carry: CarryController = player.get_node("CarryController")
	var placement: PlacementController = player.get_node("PlacementController")
	var items: Node = room.get_node("TestItems")
	var floor_surface: PlacementSurface = PlacementSurface.of_body(room.get_node("Floor"))
	var table: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestTable"))
	var pallet: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestPallet"))
	var plot: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestPlot"))
	var preplaced: TestItem = scene.get_node("ExtraItems/small_palette")
	var small: TestItem = items.get_node("small_1")
	var small_b: TestItem = items.get_node("small_2")
	var medium: TestItem = items.get_node("medium_1")
	var low: TestItem = items.get_node("furniture_low")
	var zone_floor: StorageZone = scene.get_node("Zones/ZoneSol")
	var zone_small: StorageZone = scene.get_node("Zones/ZoneTableSmall")
	var zone_pallet: StorageZone = scene.get_node("Zones/ZonePalette")

	# Scène : les quatre zones demandées, données valides.
	var zones: Array[Node] = scene.get_node("Zones").get_children()
	var zones_valid: bool = zones.size() >= 4
	for node: Node in zones:
		var zone: StorageZone = node as StorageZone
		zones_valid = zones_valid and zone != null and zone.zone_data != null and zone.zone_data.validate().is_empty()
	_check(zones_valid, "scène : au moins 4 zones, ZoneData valides")
	_check(zone_small.zone_data.accepted_categories.size() == 1, "scène : une zone n'accepte qu'une catégorie")
	_check(zone_floor.contains_point(Vector3(-0.7, floor_surface.top_y(), 3.4)), "scène : une zone recoupe le sol")

	# Chargement : rien n'est évalué avant la frame physique, puis l'objet déjà posé est rangé.
	_check(not service.is_stored(preplaced) and _events.is_empty() and preplaced.support_surface == null,
			"chargement : aucune évaluation avant la frame physique")
	await service.room_evaluated
	_check(preplaced.support_surface == pallet and service.is_stored(preplaced), "chargement : objet déjà posé sur la palette = rangé")
	_check(_take_events() == [[preplaced, true]], "chargement : un seul signal (objet rangé), rien pour les objets au sol")
	_check(small.support_surface == floor_surface and not service.is_stored(small) and low.support_surface == floor_surface
			and not service.is_stored(low), "chargement : objets au sol non rangés")
	_check((scene.call(&"state_text", preplaced) as String).ends_with(": rangé")
			and (scene.call(&"state_text", small) as String).ends_with(": non rangé"), "scène : Labels d'état à jour")
	await physics_frame

	# Palette, zone acceptante.
	_put(small, pallet, -3.3, -0.4)
	_check(service.is_stored(small) and zone_pallet.holds(small) and _take_events() == [[small, true]],
			"palette dans une zone acceptante = rangé (un signal)")
	# Pas de signal si l'état ne change pas.
	service.evaluate(small)
	_put(small, pallet, -3.0, -0.2)
	_check(service.is_stored(small) and _take_events() == [[small, false], [small, true]],
			"déplacé sur la palette : non rangé à la reprise, rangé à la pose, rien d'autre")
	service.evaluate(small)
	service.evaluate(low)
	_put(small_b, floor_surface, 0.0, 2.0)
	_put(small_b, floor_surface, 0.5, 2.0)
	_check(_take_events().is_empty(), "pas de signal si l'état ne change pas (réévaluation, sol vers sol)")

	# Même objet, catégorie refusée.
	_put(medium, pallet, -3.7, -0.5)
	_check(service.is_stored(medium), "MEDIUM sur la palette (zone acceptante) = rangé")
	_put(medium, table, 3.8, -0.5)
	_check(zone_small.contains_item(medium) and not zone_small.holds(medium) and not service.is_stored(medium),
			"même objet dans une zone qui refuse sa catégorie = non rangé")
	_put(small_b, table, 3.8, -0.2)
	_check(service.is_stored(small_b), "SMALL dans la zone SMALL seulement = rangé")
	_put(medium, table, 3.2, -0.5)
	_check(service.is_stored(medium), "MEDIUM sur l'autre moitié de la table (zone acceptante) = rangé")
	# Dessus d'un objet ordinaire.
	_put(small_b, PlacementSurface.of_body(medium), 3.2, -0.5)
	_check(not small_b.rests_on_declared_support() and not service.is_stored(small_b) and service.is_stored(medium),
			"sur le dessus d'un objet ordinaire (lui-même rangé) = non rangé")
	# Support déclaré hors de toute zone.
	_put(small_b, plot, 3.5, 1.5)
	_check(small_b.rests_on_declared_support() and not service.is_stored(small_b), "support déclaré hors de toute zone = non rangé")
	# Sol dans une zone qui recoupe le sol.
	_put(small_b, floor_surface, -0.7, 3.4)
	_check(zone_floor.holds(small_b) and not service.is_stored(small_b), "au sol dans une zone qui recoupe le sol = non rangé")
	_check(zone_floor.contains_item(low) and not service.is_stored(low), "meuble libre au sol dans la zone = non rangé")
	# Meuble libre (provides_support) dans une zone.
	_put(small_b, PlacementSurface.of_body(low), -1.5, 3.4)
	_check(small_b.rests_on_declared_support() and service.is_stored(small_b), "sur un meuble libre dans une zone = rangé")
	_take_events()

	# Tenu / reprise : par le CarryController.
	carry.pick_up(small.get_node("Interactable"))
	_check(carry.held_body() == small and not service.is_stored(small) and _take_events() == [[small, false]],
			"reprise : objet tenu = non rangé (un signal)")
	# Chute : pose instable au bord de la table, l'objet tombe au sol.
	_aim_at(player, Vector3(4.1, 0.05, 0.7), Vector3(4.095, table.top_y(), -0.5))
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.UNSTABLE, "bord de la table : pose instable (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(carry.held_body() == null and small.support_surface == floor_surface, "l'objet est tombé au sol, jamais détruit")
	_check(is_instance_valid(small) and not service.is_stored(small) and _take_events().is_empty(), "objet tombé = non rangé (aucun signal)")
	await physics_frame
	# Repose valide par le PlacementController.
	carry.pick_up(small.get_node("Interactable"))
	_aim_at(player, Vector3(3.2, 0.05, 0.7), Vector3(3.2, table.top_y(), -0.2))
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.OK, "table : repose valide (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(small.support_surface == table and service.is_stored(small) and _take_events() == [[small, true]],
			"objet tombé reposé dans les règles = rangé (un signal)")
	_check((scene.call(&"state_text", small) as String).ends_with(": rangé"), "scène : Label mis à jour par le signal")
	scene.queue_free()
	await process_frame


## Pose directe (sans contrôleur) : reprise, déplacement au point (x, z) du dessus de la surface, pose.
func _put(item: TestItem, surface: PlacementSurface, x: float, z: float) -> void:
	item.on_picked_up()
	item.global_position = Vector3(x, surface.top_y() + item.item_data.height * 0.5, z)
	item.on_placed(surface)


func _take_events() -> Array:
	var events: Array = _events
	_events = []
	return events


func _aim_at(player: Player, pos: Vector3, target: Vector3) -> void:
	player.global_position = pos
	var dir: Vector3 = target - player.get_node("Head/Camera3D").global_position
	player.rotation.y = atan2(-dir.x, -dir.z)
	player.head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_failures += 1
