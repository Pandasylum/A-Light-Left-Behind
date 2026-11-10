extends SceneTree
## Test de la pose simple (P1-D1). Lancer : tools/godot.sh --headless --path game --script res://tests/test_placement.gd

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_test_check_pure()
	_test_surface_transform()
	await _test_shape_query()
	await _test_greybox_flow()
	print("test_placement : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_check_pure() -> void:
	var c: PlacementCheck = PlacementCheck.new() # règles provisoires : marge 0,02, couverture 0,6
	var table: Vector2 = Vector2(1.2, 0.8)
	var o: PlacementCheck.Outcome = c.evaluate_local(Vector2(0.3, 0.3), 0.0, Vector2.ZERO, table)
	_check(o.status == PlacementCheck.Status.OK and is_equal_approx(o.coverage, 1.0), "centré : OK, couverture 1")
	# Centre sur le bord : environ la moitié moins la marge (~0,4) -> instable.
	o = c.evaluate_local(Vector2(0.3, 0.3), 0.0, Vector2(0.6, 0.0), table)
	_check(o.status == PlacementCheck.Status.UNSUPPORTED and absf(o.coverage - 0.4) < 0.06, "centre sur le bord : instable (%.2f)" % o.coverage)
	# Débord léger : couverture partielle mais suffisante.
	o = c.evaluate_local(Vector2(0.3, 0.3), 0.0, Vector2(0.5, 0.0), table)
	_check(o.status == PlacementCheck.Status.OK and o.coverage < 1.0 and o.coverage >= 0.6, "léger débord : OK partiel (%.2f)" % o.coverage)
	# Hors de la surface : couverture nulle.
	o = c.evaluate_local(Vector2(0.3, 0.3), 0.0, Vector2(3.0, 0.0), table)
	_check(o.status == PlacementCheck.Status.UNSUPPORTED and o.coverage == 0.0, "hors surface : couverture 0")
	# Marge au bord : l'empreinte qui affleure le bord est partiellement rejetée.
	var no_margin: PlacementRules = PlacementRules.new()
	no_margin.edge_margin = 0.0
	var flush: Vector2 = Vector2(0.45, 0.0) # empreinte 0,3 : bord à x = 0,6 = bord de la table
	_check(PlacementCheck.new(no_margin).evaluate_local(Vector2(0.3, 0.3), 0.0, flush, table).coverage == 1.0, "sans marge : affleurant = 1")
	_check(c.evaluate_local(Vector2(0.3, 0.3), 0.0, flush, table).coverage < 1.0, "avec marge 0,02 : affleurant < 1")
	var wide_margin: PlacementRules = PlacementRules.new()
	wide_margin.edge_margin = 0.3
	_check(PlacementCheck.new(wide_margin).evaluate_local(Vector2(0.3, 0.3), 0.0, Vector2.ZERO, Vector2(0.5, 0.5)).status
			== PlacementCheck.Status.UNSUPPORTED, "marge >= demi-surface : instable")
	# Rotation du lacet : 0,8 x 0,1 sur une bande 1,0 x 0,3.
	var strip: Vector2 = Vector2(1.0, 0.3)
	_check(c.evaluate_local(Vector2(0.8, 0.1), 0.0, Vector2.ZERO, strip).status == PlacementCheck.Status.OK, "lacet 0° : tient sur la bande")
	_check(c.evaluate_local(Vector2(0.8, 0.1), PI / 2.0, Vector2.ZERO, strip).status == PlacementCheck.Status.UNSUPPORTED,
			"lacet 90° : déborde de la bande")
	_check(c.evaluate_local(Vector2(0.8, 0.1), PI, Vector2.ZERO, strip).status == PlacementCheck.Status.OK, "lacet 180° : OK")
	# Objet plus grand que la surface (plot 0,3 x 0,3).
	var plot: Vector2 = Vector2(0.3, 0.3)
	o = c.evaluate_local(Vector2(0.45, 0.45), 0.0, Vector2.ZERO, plot)
	_check(o.status == PlacementCheck.Status.UNSUPPORTED and o.coverage < 0.6, "plus grand que la surface : instable (%.2f)" % o.coverage)
	_check(c.evaluate_local(Vector2(0.3, 0.3), 0.0, Vector2.ZERO, plot).status == PlacementCheck.Status.OK, "0,3 sur plot 0,3 : OK")
	# Couverture minimale paramétrable.
	var strict: PlacementRules = PlacementRules.new()
	strict.min_support_coverage = 0.9
	_check(PlacementCheck.new(strict).evaluate_local(Vector2(0.3, 0.3), 0.0, Vector2.ZERO, plot).status
			== PlacementCheck.Status.UNSUPPORTED, "couverture minimale 0,9 : plot refusé")


func _test_surface_transform() -> void:
	var s: PlacementSurface = PlacementSurface.new()
	s.size = Vector2(1.0, 0.3)
	s.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(2.0, 0.5, 1.0))
	root.add_child(s)
	var c: PlacementCheck = PlacementCheck.new()
	var data: ItemData = ItemData.new()
	data.footprint = Vector2(0.8, 0.1)
	# Surface tournée de 90° : l'objet doit l'être aussi pour tenir sur la bande.
	var center: Vector3 = Vector3(2.0, 0.5, 1.0)
	_check(c.evaluate(data, PI / 2.0, center, s).status == PlacementCheck.Status.OK, "surface tournée : lacet aligné OK")
	_check(c.evaluate(data, 0.0, center, s).status == PlacementCheck.Status.UNSUPPORTED, "surface tournée : lacet 0 déborde")
	_check(is_equal_approx(s.top_y(), 0.5), "top_y = hauteur monde de la surface")
	s.queue_free()


func _body(layer: int, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	b.collision_layer = layer
	b.position = pos
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	root.add_child(b)
	return b


func _test_shape_query() -> void:
	var floor_body: StaticBody3D = _body(1, Vector3(0, -0.1, 0), Vector3(4, 0.2, 4))
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = (root as Node).get_viewport().world_3d.direct_space_state
	var data: ItemData = ItemData.new()
	data.footprint = Vector2(0.3, 0.3)
	data.height = 0.2
	var at: Vector3 = Vector3(0, 0, 0)
	_check(not PlacementController.is_blocked(space, data, 0.0, at), "requête : la surface porteuse n'est pas détectée")
	_check(not PlacementController.is_blocked(space, data, 0.7, at), "requête : idem avec un lacet")
	var obstacle: StaticBody3D = _body(4, Vector3(0.2, 0.1, 0), Vector3(0.2, 0.2, 0.2)) # couche 3
	await physics_frame
	_check(PlacementController.is_blocked(space, data, 0.0, at), "requête : objet couche 3 -> bloqué")
	_check(not PlacementController.is_blocked(space, data, 0.0, at, [obstacle.get_rid()]), "requête : objet exclu ignoré")
	_check(not PlacementController.is_blocked(space, data, 0.0, Vector3(1.0, 0, 0)), "requête : ailleurs libre")
	var player_like: StaticBody3D = _body(2, Vector3(-1.0, 0.5, 0), Vector3(0.3, 1.0, 0.3)) # couche 2
	await physics_frame
	_check(PlacementController.is_blocked(space, data, 0.0, Vector3(-1.0, 0, 0)), "requête : couche 2 (joueur) -> bloqué")
	var other: StaticBody3D = _body(8, Vector3(0, 0.1, -1.0), Vector3(0.5, 0.5, 0.5)) # couche 4, hors masque
	await physics_frame
	_check(not PlacementController.is_blocked(space, data, 0.0, Vector3(0, 0, -1.0)), "requête : couche hors masque ignorée")
	for b: Node in [floor_body, obstacle, player_like, other]:
		b.queue_free()
	await process_frame


func _aim(player: Player, pos: Vector3, yaw: float, pitch_deg: float) -> void:
	player.global_position = pos
	player.rotation.y = yaw
	player.head.rotation.x = deg_to_rad(pitch_deg)


func _hold(carry: CarryController, item: Node3D) -> void:
	carry.inventory.pick_up(item.get("item_data"), item)
	carry._refresh_visuals()


func _test_greybox_flow() -> void:
	var room: Node3D = (load("res://rooms/test/greybox.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await physics_frame
	await physics_frame

	# Choix du support via is_floor.
	var floor_surface: PlacementSurface = PlacementSurface.of_body(room.get_node("Floor"))
	_check(floor_surface != null and floor_surface.is_floor, "sol : PlacementSurface is_floor = true")
	for support: String in ["TestTable", "TestPallet", "TestPlot"]:
		var s: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/" + support))
		_check(s != null and not s.is_floor, "%s : PlacementSurface is_floor = false" % support)
	_check(is_equal_approx(PlacementSurface.of_body(room.get_node("Supports/TestPallet")).top_y(), 0.15), "palette basse : face à 0,15 m")
	_check(PlacementSurface.of_body(room.get_node("Borders/North")) == null, "bordure : pas de surface")
	_check(room.get_node_or_null("PlacedObjects") != null, "nœud PlacedObjects présent")

	var player: Player = room.get_node("Player")
	var carry: CarryController = player.get_node("CarryController")
	var placement: PlacementController = player.get_node("PlacementController")
	var placed_root: Node = room.get_node("PlacedObjects")
	var msg: Label = player.prompt.get_node("Message")
	var table_surface: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestTable"))

	# Pose valide sur la table (plateau à 0,75 m).
	var item: TestItem = room.get_node("TestItems/small_1")
	_hold(carry, item)
	_aim(player, Vector3(3.5, 0.05, 0.7), 0.0, -35.3)
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.OK, "table : pose valide (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(carry.held_body() == null, "pose : la main est vide")
	_check(item.get_parent() == placed_root, "pose : objet sous PlacedObjects")
	_check(is_equal_approx(item.global_position.y, 0.75 + item.item_data.height * 0.5), "pose : posé sur le plateau (y = %.3f)" % item.global_position.y)
	_check(item.collision_layer == 4, "pose : collision couche 3 réactivée")
	_check(item.support_surface == table_surface, "pose : surface porteuse mémorisée")
	_check(item.visible, "pose : objet visible")
	await physics_frame

	# Pose bloquée : même endroit, objet déjà posé.
	var second: TestItem = room.get_node("TestItems/small_2")
	var second_origin: Transform3D = second.global_transform
	_hold(carry, second)
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.BLOCKED, "même endroit : bloqué (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(carry.held_body() == second and msg.text == "place.blocked", "bloqué : message place.blocked, objet toujours en main")
	_check(second.get_parent() != placed_root and second.collision_layer == 0, "bloqué : aucun changement d'état")

	# Pose instable : objet moyen (0,45) sur le plot 0,3 x 0,3.
	carry.inventory.drop_object() # libère la main pour le test (second est remis à son parent ci-dessous)
	second.reparent(room.get_node("TestItems"), false)
	second.global_transform = second_origin
	second.collision_layer = 4
	var medium: TestItem = room.get_node("TestItems/medium_1")
	_hold(carry, medium)
	_aim(player, Vector3(3.5, 0.05, 0.7), PI, -60.3)
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.UNSTABLE, "plot trop petit : instable (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(carry.held_body() == medium and msg.text == "place.unstable", "instable : message place.unstable, objet toujours en main")

	# Aucune surface visée.
	_aim(player, Vector3(0, 0.05, 0.7), 0.0, 30.0)
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.NO_SURFACE, "ciel : aucune surface")
	placement.place_held()
	_check(carry.held_body() == medium and msg.text == "place.no_surface", "sans surface : message place.no_surface")

	# Sol : surface is_floor, pose valide ; rotation par paliers.
	_aim(player, Vector3(0, 0.05, 0.7), 0.0, -60.0)
	await physics_frame
	placement.rotate_by(2)
	_check(is_equal_approx(placement._yaw, deg_to_rad(30.0)), "rotation : 2 paliers de 15° = 30°")
	placement.rotate_by(-3)
	_check(is_equal_approx(placement._yaw, deg_to_rad(-15.0)), "rotation : -1 palier = -15°")
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.OK and placement._surface.is_floor, "sol : pose valide sur la surface is_floor")
	placement.place_held()
	_check(medium.get_parent() == placed_root and medium.support_surface.is_floor, "sol : posé, surface porteuse = sol")
	_check(is_equal_approx(medium.global_transform.basis.get_euler().y, deg_to_rad(-15.0)), "sol : orientation appliquée")
	room.queue_free()


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_failures += 1
