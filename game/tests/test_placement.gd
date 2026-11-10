extends SceneTree
## Test de la pose, de l'empilement et de la chute (P1-D1, P1-D2). Lancer : tools/godot.sh --headless --path game --script res://tests/test_placement.gd

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_test_check_pure()
	_test_can_stack()
	_test_top_face()
	_test_surface_transform()
	_test_push_out()
	await _test_shape_query()
	await _test_item_surface()
	await _test_landing()
	await _test_greybox_flow()
	await _test_furniture()
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


func _test_can_stack() -> void:
	var cat: Dictionary = {"S": ItemData.Category.SMALL, "M": ItemData.Category.MEDIUM, "L": ItemData.Category.LARGE, "F": ItemData.Category.FIXED}
	# [dessus, dessous, attendu]
	var cases: Array = [
		["S", "S", true], ["S", "M", true], ["S", "L", true], ["S", "F", false],
		["M", "S", false], ["M", "M", false], ["M", "L", true], ["M", "F", false],
		["L", "S", false], ["L", "M", false], ["L", "L", false], ["L", "F", false],
		["F", "S", false], ["F", "M", false], ["F", "L", false], ["F", "F", false],
	]
	for c: Array in cases:
		_check(PlacementCheck.can_stack(cat[c[0]], cat[c[1]]) == c[2], "can_stack(%s sur %s) = %s" % [c[0], c[1], c[2]])


func _test_top_face() -> void:
	_check(PlacementController.is_top_face(Vector3.UP), "face : normale vers le haut -> visable")
	_check(PlacementController.is_top_face(Vector3(0.1, 0.995, 0.0).normalized()), "face : légèrement inclinée (~6°) -> visable")
	_check(not PlacementController.is_top_face(Vector3(0.6, 0.8, 0.0)), "face : 37° d'inclinaison -> aucune surface")
	_check(not PlacementController.is_top_face(Vector3(0.0, 0.0, 1.0)), "face : flanc vertical -> aucune surface")
	_check(not PlacementController.is_top_face(Vector3.DOWN), "face : dessous -> aucune surface")
	_check(not PlacementController.is_top_face(Vector3(0.0, 0.9, 0.436).normalized()), "face : 0,9 de produit scalaire (< 0,95) -> aucune surface")


func _item_data(name: String) -> ItemData:
	return load("res://data/items/%s.tres" % name) as ItemData


func _item(name: String, pos: Vector3, yaw: float = 0.0) -> TestItem:
	var item: TestItem = (load("res://props/test_item.tscn") as PackedScene).instantiate()
	item.item_data = _item_data(name)
	item.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	root.add_child(item)
	return item


func _test_item_surface() -> void:
	var medium: TestItem = _item("test_medium_1", Vector3(10.0, 0.2, 0.0), PI / 2.0)
	var surface: PlacementSurface = PlacementSurface.of_body(medium)
	_check(surface != null and not surface.is_floor, "objet : enfant PlacementSurface, is_floor = false")
	_check(surface.size == medium.item_data.footprint, "objet : taille de la surface = emprise")
	_check(is_equal_approx(surface.top_y(), 0.2 + medium.item_data.height * 0.5), "objet : surface à la hauteur du dessus")
	_check(is_equal_approx(surface.to_local_yaw(PI / 2.0), 0.0), "objet tourné : la surface suit la rotation du corps")
	# Contrôle de couverture sur le dessus d'un objet tourné de 90° (emprise 0,8 x 0,2).
	var thin: ItemData = ItemData.new()
	thin.footprint = Vector2(0.8, 0.2)
	thin.height = 0.2
	var rotated: TestItem = (load("res://props/test_item.tscn") as PackedScene).instantiate()
	rotated.item_data = thin
	rotated.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(14.0, 0.2, 0.0))
	root.add_child(rotated)
	var small: ItemData = _item_data("test_small_1")
	var check: PlacementCheck = PlacementCheck.new()
	var top_y: float = 0.2 + thin.height * 0.5
	var surf: PlacementSurface = PlacementSurface.of_body(rotated)
	# Axe long de l'objet = Z monde (rotation 90°) : un SMALL à 0,3 m du centre le long de Z tient, le long de X il déborde.
	_check(check.evaluate(small, PI / 2.0, Vector3(14.0, top_y, -0.3), surf).status == PlacementCheck.Status.OK,
			"dessus d'objet : SMALL le long de l'axe long -> OK")
	_check(check.evaluate(small, PI / 2.0, Vector3(14.3, top_y, 0.0), surf).status == PlacementCheck.Status.UNSUPPORTED,
			"dessus d'objet : SMALL le long de l'axe court -> déborde")
	_check(check.evaluate(small, 0.0, Vector3(14.0, top_y, 0.0), surf).status == PlacementCheck.Status.OK, "dessus d'objet : centré -> OK")
	# Pas de pose sur un objet moins grand que soi : couverture insuffisante.
	var big: ItemData = _item_data("test_medium_1")
	_check(check.evaluate(big, 0.0, Vector3(10.0, top_y, 0.0), PlacementSurface.of_body(medium)).status == PlacementCheck.Status.OK,
			"dessus d'objet : MEDIUM centré sur MEDIUM -> couverture OK (c'est can_stack qui refuse)")
	for n: Node in [medium, rotated]:
		n.queue_free()
	await process_frame


## Support de test : corps de `size` dont la face supérieure est centrée en `top`, surface de même taille (XZ).
func _support(top: Vector3, size: Vector3, layer: int = 1, is_floor: bool = false) -> StaticBody3D:
	var b: StaticBody3D = _body(layer, top - Vector3(0.0, size.y * 0.5, 0.0), size)
	var surf: PlacementSurface = PlacementSurface.new()
	surf.size = Vector2(size.x, size.z)
	surf.is_floor = is_floor
	surf.position = Vector3(0.0, size.y * 0.5, 0.0)
	b.add_child(surf)
	return b


func _land(data: ItemData, start: Vector3, origin: StaticBody3D) -> PlacementLanding.Landing:
	var space: PhysicsDirectSpaceState3D = (root as Node).get_viewport().world_3d.direct_space_state
	return PlacementLanding.resolve(space, PlacementCheck.new(), data, 0.0, start, origin.get_rid(), RID())


func _test_landing() -> void:
	var data: ItemData = ItemData.new() # SMALL 0,3 x 0,3 x 0,1
	data.footprint = Vector2(0.3, 0.3)
	data.height = 0.1
	var floor_body: StaticBody3D = _support(Vector3(0, 0, 0), Vector3(8, 0.2, 8), 1, true)
	var shelf: StaticBody3D = _support(Vector3(0, 0.75, 0), Vector3(1.0, 0.02, 0.6)) # étagère mince
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = (root as Node).get_viewport().world_3d.direct_space_state
	var shelf_surface: PlacementSurface = PlacementSurface.of_body(shelf)
	var floor_surface: PlacementSurface = PlacementSurface.of_body(floor_body)
	var edge: Vector3 = Vector3(0.5, 0.75, 0.0) # centre sur le bord de l'étagère : instable
	var check: PlacementCheck = PlacementCheck.new()
	_check(PlacementLanding.evaluate_pose(space, check, data, 0.0, edge, shelf_surface) == PlacementLanding.Verdict.UNSTABLE,
			"pose sur le bord : instable (et non refusée)")
	_check(PlacementLanding.evaluate_pose(space, check, data, 0.0, Vector3(0, 0.75, 0), shelf_surface) == PlacementLanding.Verdict.OK,
			"pose centrée : OK")

	# Chute vers le sol.
	var l: PlacementLanding.Landing = _land(data, edge, shelf)
	_check(l.ok and l.surface == floor_surface and l.iterations == 1, "chute vers le sol : atterrit sur le sol en 1 itération")
	# Dégagement horizontal : bord de l'étagère (x = 0,5) + demi-emprise (0,15) + marge (0,02) = 0,67 ; z inchangé.
	_check(l.ok and is_equal_approx(l.center.y, 0.0) and absf(l.center.x - 0.67) < 1e-4 and absf(l.center.z) < 1e-4,
			"chute : dégagée de l'étagère par le plus petit décalage (x = %.3f)" % l.center.x)
	_check(l.ok and not PlacementLanding.is_blocked(space, data, 0.0, l.center), "chute : pose libre, étagère comprise")
	await physics_frame

	# Chute vers un support plus bas (palette large).
	var pallet: StaticBody3D = _support(Vector3(0, 0.15, 0), Vector3(2.0, 0.15, 2.0))
	await physics_frame
	l = _land(data, edge, shelf)
	_check(l.ok and l.surface == PlacementSurface.of_body(pallet) and is_equal_approx(l.center.y, 0.15)
			and not PlacementLanding.is_blocked(space, data, 0.0, l.center), "chute vers un support plus bas : palette, dégagée")
	pallet.free()

	# Cascade : plaque étroite sous l'étagère, puis le sol.
	var plate: StaticBody3D = _support(Vector3(0.5, 0.4, 0.0), Vector3(0.1, 0.02, 0.1))
	await physics_frame
	l = _land(data, edge, shelf)
	_check(l.ok and l.surface == floor_surface and l.iterations == 2, "cascade : plaque instable puis sol (%d itérations)" % l.iterations)
	plate.free()

	# Empilement interdit à l'atterrissage : un MEDIUM tombe sur un SMALL posé -> refus.
	var small_item: TestItem = _item("test_small_1", Vector3(0.5, 0.05, 0.0))
	await physics_frame
	var medium_data: ItemData = _item_data("test_medium_1")
	l = _land(medium_data, Vector3(0.5, 0.75, 0.0), shelf)
	_check(not l.ok, "chute sur un SMALL : MEDIUM, empilement interdit -> refus")
	# Un SMALL sur un SMALL est permis, mais le dessus (0,12 x 0,12) est trop petit pour 0,3 : il retombe jusqu'au sol.
	l = _land(data, edge, shelf)
	_check(l.ok and l.surface == floor_surface and l.iterations == 2, "chute sur un SMALL trop petit : retombe au sol (%d itérations)" % l.iterations)
	small_item.free()

	# Vide sous l'étagère : aucun atterrissage -> refus.
	floor_body.free()
	await physics_frame
	l = _land(data, edge, shelf)
	_check(not l.ok and l.iterations == 1, "aucune surface dessous : refus")
	shelf.free()

	# Itérations : escalier de plaques étroites (0,1 m) sous une origine de même largeur. Chaque atterrissage est
	# instable ; une plaque sur deux recouvre la précédente (dégagement de 0,22 m), puis le sol.
	floor_body = _support(Vector3(0, 0, 0), Vector3(8, 0.2, 8), 1, true)
	var plates: Array[StaticBody3D] = []
	var origin: StaticBody3D = _support(Vector3(0.5, 1.6, 0), Vector3(0.1, 0.02, 0.1))
	for j: int in range(1, 10):
		plates.append(_support(Vector3(0.5 + 0.22 * floori(j / 2.0), 1.6 - 0.15 * j, 0.0), Vector3(0.1, 0.02, 0.1)))
	var start: Vector3 = Vector3(0.5, 1.6, 0.0)
	await physics_frame
	await physics_frame
	l = _land(data, start, origin)
	_check(not l.ok and l.iterations == PlacementLanding.MAX_ITERATIONS, "9 plaques : refus après 8 itérations (%d)" % l.iterations)
	plates.pop_back().free()
	plates.pop_back().free() # il reste 7 plaques : le sol est atteint à la 8e itération
	await physics_frame
	l = _land(data, start, origin)
	_check(l.ok and l.surface == PlacementSurface.of_body(floor_body) and l.iterations == 8, "7 plaques : sol à la 8e itération (%d)" % l.iterations)
	for b: Node in plates + [origin, floor_body]:
		b.free()
	await process_frame

	await _test_landing_clearance()


## Chutes réelles depuis une table, un objet empilé : l'objet finit à côté, sans recouvrir aucun corps.
func _test_landing_clearance() -> void:
	var data: ItemData = ItemData.new() # SMALL 0,3 x 0,3 x 0,1
	data.footprint = Vector2(0.3, 0.3)
	data.height = 0.1
	var floor_body: StaticBody3D = _support(Vector3(0, 0, 0), Vector3(8, 0.2, 8), 1, true)
	var table: StaticBody3D = _support(Vector3(0, 0.75, 0), Vector3(1.2, 0.75, 0.8))
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = (root as Node).get_viewport().world_3d.direct_space_state
	var floor_surface: PlacementSurface = PlacementSurface.of_body(floor_body)
	# Du bord de la table : atterrit à côté (x = 0,6 + 0,15 + 0,02), sur le sol.
	var l: PlacementLanding.Landing = _land(data, Vector3(0.6, 0.75, 0.0), table)
	_check(l.ok and l.surface == floor_surface and absf(l.center.x - 0.77) < 1e-4 and is_equal_approx(l.center.y, 0.0),
			"bord de table : atterrit à côté (x = %.3f)" % l.center.x)
	_check(l.ok and not _overlaps_world(space, data, 0.0, l.center), "bord de table : aucun corps recouvert")
	# Table tournée de 90° (étendue 0,8 en x, 1,2 en z) : objet au bord +z.
	var turned: StaticBody3D = _support(Vector3(3, 0.75, 0), Vector3(1.2, 0.75, 0.8))
	turned.rotation.y = PI / 2.0
	await physics_frame
	l = _land(data, Vector3(3.0, 0.75, 0.6), turned)
	_check(l.ok and l.surface == floor_surface and is_equal_approx(l.center.y, 0.0), "table tournée : atterrit au sol")
	_check(l.ok and not _overlaps_world(space, data, 0.0, l.center), "table tournée : aucun corps recouvert")
	turned.free()

	# Depuis un objet empilé : un MEDIUM posé sur la table, un SMALL au bord de son dessus tombe sur la table, à côté.
	var medium: TestItem = _item("test_medium_1", Vector3(0.0, 0.75 + 0.2, 0.0)) # 0,45 x 0,45 x 0,4 sur la table
	await physics_frame
	await physics_frame
	var small: ItemData = _item_data("test_small_1") # 0,12 x 0,12 x 0,1
	var medium_top: float = 0.75 + 0.4
	l = _land(small, Vector3(0.2, medium_top, 0.0), medium)
	_check(l.ok and l.surface == PlacementSurface.of_body(table) and is_equal_approx(l.center.y, 0.75),
			"depuis un objet empilé : atterrit sur la table")
	_check(l.ok and absf(l.center.x - (0.225 + 0.06 + 0.02)) < 1e-4, "depuis un objet empilé : dégagé de l'objet (x = %.3f)" % l.center.x)
	_check(l.ok and not _overlaps_world(space, small, 0.0, l.center), "depuis un objet empilé : aucun corps recouvert")
	medium.free()
	table.free()
	floor_body.free()
	await process_frame


## Vrai si la boîte de l'objet (couches 1 et 3) recouvre un corps, requête de forme réelle.
func _overlaps_world(space: PhysicsDirectSpaceState3D, data: ItemData, yaw: float, center: Vector3, exclude: Array[RID] = []) -> bool:
	var query: PhysicsShapeQueryParameters3D = PlacementLanding._box_query(data, yaw, center, PlacementLanding.FALL_MASK, exclude)
	return not space.intersect_shape(query, 1).is_empty()


func _test_push_out() -> void:
	var margin: float = 0.02
	var support: PlacementLanding.OrientedRect = PlacementLanding.OrientedRect.make(Vector2.ZERO, Vector2(1.0, 0.6), 0.0)
	# Axe choisi : objet 0,3 x 0,3 sur le bord +x -> dégagement en +x (0,5 + 0,15 + 0,02 - 0,5).
	var body: PlacementLanding.OrientedRect = PlacementLanding.OrientedRect.make(Vector2(0.5, 0.0), Vector2(0.3, 0.3), 0.0)
	var o: Array[Vector2] = PlacementLanding.push_out(body, support, margin)
	_check(not o.is_empty() and o[0].distance_to(Vector2(0.17, 0.0)) < 1e-5, "push_out : axe X, +x (%s)" % [o[0] if not o.is_empty() else "vide"])
	# Axe Z plus court : objet près du bord +z.
	body = PlacementLanding.OrientedRect.make(Vector2(0.0, 0.3), Vector2(0.3, 0.3), 0.0)
	o = PlacementLanding.push_out(body, support, margin)
	_check(not o.is_empty() and o[0].distance_to(Vector2(0.0, 0.17)) < 1e-5, "push_out : axe Z, +z (%s)" % [o[0] if not o.is_empty() else "vide"])
	# Côté opposé : -x.
	body = PlacementLanding.OrientedRect.make(Vector2(-0.5, 0.0), Vector2(0.3, 0.3), 0.0)
	o = PlacementLanding.push_out(body, support, margin)
	_check(not o.is_empty() and o[0].distance_to(Vector2(-0.17, 0.0)) < 1e-5, "push_out : côté -x")
	# Tri par distance croissante, jamais de décalage qui laisse un recouvrement.
	body = PlacementLanding.OrientedRect.make(Vector2(0.4, 0.1), Vector2(0.3, 0.3), 0.0)
	o = PlacementLanding.push_out(body, support, margin)
	var sorted: bool = o.size() >= 2
	for i: int in range(1, o.size()):
		sorted = sorted and o[i].length() >= o[i - 1].length() - PlacementLanding.TIE_EPSILON
	_check(sorted, "push_out : triés par distance croissante (%d candidats)" % o.size())
	var cleared: bool = true
	for c: Vector2 in o:
		var moved: PlacementLanding.OrientedRect = PlacementLanding.OrientedRect.make(body.center + c, body.size, body.yaw)
		cleared = cleared and PlacementLanding.push_out(moved, support, 0.0).is_empty()
	_check(cleared, "push_out : chaque décalage sépare les rectangles")
	# Marge : la distance croît d'autant ; marge nulle = contact exact.
	body = PlacementLanding.OrientedRect.make(Vector2(0.5, 0.0), Vector2(0.3, 0.3), 0.0)
	o = PlacementLanding.push_out(body, support, 0.0)
	_check(not o.is_empty() and o[0].distance_to(Vector2(0.15, 0.0)) < 1e-5, "push_out : sans marge, contact exact")
	o = PlacementLanding.push_out(body, support, 0.1)
	_check(not o.is_empty() and o[0].distance_to(Vector2(0.25, 0.0)) < 1e-5, "push_out : marge 0,1 -> +0,1")
	# Rectangles tournés : objet tourné de 45° et support tourné de 90° (équivalent à 0,6 x 1,0).
	var turned_support: PlacementLanding.OrientedRect = PlacementLanding.OrientedRect.make(Vector2.ZERO, Vector2(1.0, 0.6), PI / 2.0)
	body = PlacementLanding.OrientedRect.make(Vector2(0.0, 0.5), Vector2(0.3, 0.3), 0.0)
	o = PlacementLanding.push_out(body, turned_support, margin)
	_check(not o.is_empty() and o[0].distance_to(Vector2(0.0, 0.17)) < 1e-4, "push_out : support tourné de 90° -> étendue en z (%s)" % [o[0] if not o.is_empty() else "vide"])
	var diamond: PlacementLanding.OrientedRect = PlacementLanding.OrientedRect.make(Vector2(0.6, 0.0), Vector2(0.3, 0.3), PI / 4.0)
	o = PlacementLanding.push_out(diamond, support, margin)
	var half_diag: float = 0.3 * sqrt(2.0) * 0.5
	_check(not o.is_empty() and o[0].distance_to(Vector2(0.5 + half_diag + margin - 0.6, 0.0)) < 1e-4,
			"push_out : objet tourné de 45° (demi-diagonale) (%s)" % [o[0] if not o.is_empty() else "vide"])
	# Axe de l'objet tourné qui gagne : support 1,0 x 1,0, objet 0,2 x 1,0 tourné de 30° (axes obliques).
	var wide: PlacementLanding.OrientedRect = PlacementLanding.OrientedRect.make(Vector2(0.0, 0.0), Vector2(0.4, 0.4), 0.0)
	var slanted: PlacementLanding.OrientedRect = PlacementLanding.OrientedRect.make(Vector2(0.45, 0.0), Vector2(0.4, 0.4), deg_to_rad(30.0))
	o = PlacementLanding.push_out(slanted, wide, margin)
	var slanted_ok: bool = not o.is_empty()
	for c: Vector2 in o:
		slanted_ok = slanted_ok and PlacementLanding.push_out(PlacementLanding.OrientedRect.make(slanted.center + c, slanted.size, slanted.yaw), wide, 0.0).is_empty()
	_check(slanted_ok, "push_out : lacet 30°, tous les candidats séparent")
	# Égalité : objet centré sur le support carré -> quatre décalages de même longueur, ordre fixe, stable.
	var square: PlacementLanding.OrientedRect = PlacementLanding.OrientedRect.make(Vector2.ZERO, Vector2(0.4, 0.4), 0.0)
	body = PlacementLanding.OrientedRect.make(Vector2.ZERO, Vector2(0.2, 0.2), 0.0)
	var first: Array[Vector2] = PlacementLanding.push_out(body, square, margin)
	var second: Array[Vector2] = PlacementLanding.push_out(body, square, margin)
	var expected: Array[Vector2] = [Vector2(0.32, 0.0), Vector2(-0.32, 0.0), Vector2(0.0, 0.32), Vector2(0.0, -0.32)]
	var same: bool = first.size() == expected.size() and first == second
	for i: int in mini(first.size(), expected.size()):
		same = same and first[i].distance_to(expected[i]) < 1e-5
	_check(same, "push_out : égalité, ordre fixe +x, -x, +z, -z (%d candidats)" % first.size())
	# Aucun recouvrement : séparés, ou simplement au contact.
	_check(PlacementLanding.push_out(PlacementLanding.OrientedRect.make(Vector2(2.0, 0.0), Vector2(0.3, 0.3), 0.0), support, margin).is_empty(),
			"push_out : éloignés -> aucun décalage")
	_check(PlacementLanding.push_out(PlacementLanding.OrientedRect.make(Vector2(0.65, 0.0), Vector2(0.3, 0.3), 0.0), support, margin).is_empty(),
			"push_out : au contact -> aucun décalage")
	# Séparés sur la diagonale seulement (axes de l'objet tourné).
	_check(PlacementLanding.push_out(PlacementLanding.OrientedRect.make(Vector2(0.78, 0.48), Vector2(0.3, 0.3), PI / 4.0), support, margin).is_empty(),
			"push_out : séparés par un axe de l'objet tourné -> aucun décalage")


func _aim(player: Player, pos: Vector3, yaw: float, pitch_deg: float) -> void:
	player.global_position = pos
	player.rotation.y = yaw
	player.head.rotation.x = deg_to_rad(pitch_deg)


## Place le joueur en `pos` et oriente la caméra vers `target` (monde).
func _aim_at(player: Player, pos: Vector3, target: Vector3) -> void:
	player.global_position = pos
	var dir: Vector3 = target - player.get_node("Head/Camera3D").global_position
	player.rotation.y = atan2(-dir.x, -dir.z)
	player.head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())


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
	var item: TestItem = room.get_node("TestItems/small_2") # 0,15 m : porteur assez large pour un SMALL de 0,12
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

	var small_1_top: Vector3 = item.global_position + Vector3.UP * item.item_data.height * 0.5
	var table_top: float = table_surface.top_y()

	# Pose bloquée : sur la table, contre l'objet déjà posé (la boîte le chevauche).
	var second: TestItem = room.get_node("TestItems/small_1")
	_hold(carry, second)
	_aim_at(player, Vector3(3.5, 0.05, 0.7), Vector3(item.global_position.x, table_top, item.global_position.z + 0.1))
	await physics_frame
	placement._update_target()
	_check(placement._surface == table_surface and placement._verdict == PlacementController.Verdict.BLOCKED,
			"contre l'objet posé : bloqué (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(carry.held_body() == second and msg.text == "place.blocked", "bloqué : message place.blocked, objet toujours en main")
	_check(second.get_parent() != placed_root and second.collision_layer == 0, "bloqué : aucun changement d'état")

	# Empilement : le raycast lit les objets posés, la surface visée est le dessus de l'objet.
	_aim_at(player, Vector3(3.5, 0.05, 0.7), small_1_top)
	await physics_frame
	placement._update_target()
	_check(placement._surface == PlacementSurface.of_body(item) and placement._verdict == PlacementController.Verdict.OK,
			"SMALL sur SMALL : surface = dessus de l'objet, OK (verdict %d)" % placement._verdict)
	_check(placement._material.albedo_color == PlacementController.COLOR_VALID, "empilement valide : aperçu vert")
	placement.place_held()
	_check(second.get_parent() == placed_root and is_equal_approx(second.global_position.y, small_1_top.y + second.item_data.height * 0.5),
			"empilement : posé sur le dessus (y = %.3f)" % second.global_position.y)
	_check(second.support_surface == PlacementSurface.of_body(item) and item.loads.has(second), "empilement : charge mémorisée par le porteur")
	await physics_frame

	# Reprise refusée tant que le porteur porte une charge, puis autorisée.
	carry.pick_up(item.get_node("Interactable"))
	_check(carry.held_body() == null and msg.text == "carry.supports_object" and item.get_parent() == placed_root,
			"porteur : reprise refusée (carry.supports_object)")
	carry.pick_up(second.get_node("Interactable"))
	_check(carry.held_body() == second and second.support_surface == null and not item.has_loads(), "charge reprise : porteur libéré")
	_aim_at(player, Vector3(-2.0, 0.05, 2.2), Vector3(-2.0, 0.0, 1.5))
	await physics_frame
	placement._update_target()
	placement.place_held() # SMALL reposé au sol, mains libres
	_check(carry.held_body() == null and second.support_surface.is_floor, "SMALL reposé au sol, mains libres")
	await physics_frame
	msg.text = ""
	carry.pick_up(item.get_node("Interactable"))
	_check(carry.held_body() == item and msg.text == "", "porteur sans charge : reprise autorisée")
	carry.inventory.drop_object() # remet l'objet sur la table pour la suite
	item.reparent(placed_root, false)
	item.global_position = small_1_top - Vector3.UP * item.item_data.height * 0.5
	item.collision_layer = 4
	item.visible = true
	item.on_placed(table_surface)

	# Empilement interdit : un MEDIUM sur un SMALL.
	var medium: TestItem = room.get_node("TestItems/medium_1")
	_hold(carry, medium)
	_aim_at(player, Vector3(3.5, 0.05, 0.7), small_1_top)
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.CANNOT_STACK, "MEDIUM sur SMALL : interdit (verdict %d)" % placement._verdict)
	_check(placement._material.albedo_color == PlacementController.COLOR_INVALID, "empilement interdit : aperçu rouge")
	placement.place_held()
	_check(carry.held_body() == medium and msg.text == "place.cannot_stack" and not item.has_loads(),
			"empilement interdit : place.cannot_stack, objet toujours en main")
	# MEDIUM sur LARGE : permis (dessus du LARGE posé au sol).
	var large: TestItem = room.get_node("TestItems/large_1")
	_aim_at(player, Vector3(2.25, 0.05, -2.0), large.global_position + Vector3.UP * large.item_data.height * 0.5)
	await physics_frame
	placement._update_target()
	_check(placement._surface == PlacementSurface.of_body(large) and placement._verdict == PlacementController.Verdict.OK,
			"MEDIUM sur LARGE : permis (verdict %d)" % placement._verdict)

	# Flanc : une face touchée non horizontale ne donne aucune surface (pas de projection sur le plan du dessus).
	_aim_at(player, Vector3(3.5, 0.05, 1.0), Vector3(3.5, 0.35, table_surface.global_position.z + 0.4))
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.NO_SURFACE and placement._surface == null, "flanc de la table : aucune surface visée")
	_check(not placement._preview.visible, "flanc : aucun aperçu")
	placement.place_held()
	_check(carry.held_body() == medium and msg.text == "place.no_surface", "flanc : place.no_surface")

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
	await physics_frame

	# Pose instable : un LARGE sur le plot 0,3 x 0,3 -> aperçu orange, puis chute verticale jusqu'au sol.
	var plot: Node3D = room.get_node("Supports/TestPlot")
	var plot_surface: PlacementSurface = PlacementSurface.of_body(plot)
	placement._yaw = 0.0
	_hold(carry, large)
	_aim_at(player, Vector3(3.5, 0.05, 0.2), plot_surface.global_position)
	await physics_frame
	placement._update_target()
	_check(placement._surface == plot_surface and placement._verdict == PlacementController.Verdict.UNSTABLE,
			"plot trop petit : instable (verdict %d)" % placement._verdict)
	_check(placement._material.albedo_color == PlacementController.COLOR_FALL, "instable : aperçu orange")
	placement.place_held()
	_check(carry.held_body() == null and large.get_parent() == placed_root, "instable : l'objet est posé (chute)")
	_check(msg.text == "place.fell", "instable : message place.fell (%s)" % msg.text)
	_check(large.support_surface == floor_surface and is_equal_approx(large.global_position.y, floor_surface.top_y() + large.item_data.height * 0.5),
			"chute : atterri sur le sol (y = %.3f)" % large.global_position.y)
	_check(large.collision_layer == 4 and large.visible, "chute : collision couche 3 réactivée, visible")
	# Dégagement horizontal : le LARGE ne recouvre plus le plot ni aucun corps des couches 1 et 3.
	await physics_frame
	var space: PhysicsDirectSpaceState3D = (root as Node).get_viewport().world_3d.direct_space_state
	var final_center: Vector3 = large.global_position - Vector3.UP * large.item_data.height * 0.5
	_check(not _overlaps_world(space, large.item_data, large.global_rotation.y, final_center, [large.get_rid()]),
			"chute : le LARGE ne recouvre aucun corps (couches 1 et 3)")
	_check(Vector2(large.global_position.x - plot_surface.global_position.x, large.global_position.z - plot_surface.global_position.z).length() > 0.4 + 0.15,
			"chute : décalé horizontalement hors du plot")
	# Ciblable : un rayon de la caméra vers le dessus de l'objet l'atteint avant tout autre corps.
	var top: Vector3 = large.global_position + Vector3.UP * large.item_data.height * 0.5
	var view_from: Vector3 = Vector3(large.global_position.x, 1.5, large.global_position.z + 1.8)
	var ray: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(view_from, top, PlacementController.AIM_MASK))
	_check(not ray.is_empty() and ray.get("collider") == large, "chute : l'objet est ciblable (rien ne le masque)")
	room.queue_free()


## Meubles libres (P1-E1) : propagation de provides_support, rests_on_declared_support, empilement, déplacement.
func _test_furniture() -> void:
	var room: Node3D = (load("res://rooms/test/greybox.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await physics_frame
	await physics_frame
	var low: TestItem = room.get_node("TestItems/furniture_low")
	var tall: TestItem = room.get_node("TestItems/furniture_tall")
	var medium: TestItem = room.get_node("TestItems/medium_1")
	var small: TestItem = room.get_node("TestItems/small_3")
	var ordinary: TestItem = room.get_node("TestItems/large_1")
	var floor_surface: PlacementSurface = PlacementSurface.of_body(room.get_node("Floor"))
	var table_surface: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestTable"))

	# Propagation de provides_support jusqu'au PlacementSurface.
	_check(low.item_data.validate().is_empty() and tall.item_data.validate().is_empty(), "meubles : ItemData valides")
	_check(low.item_data.provides_support and tall.item_data.provides_support, "meubles : provides_support = true")
	_check(low.item_data.footprint != tall.item_data.footprint and low.item_data.height != tall.item_data.height, "meubles : dimensions distinctes")
	_check(PlacementSurface.of_body(low).is_declared_support and PlacementSurface.of_body(tall).is_declared_support,
			"meuble libre : dessus = support déclaré")
	_check(not PlacementSurface.of_body(ordinary).is_declared_support and not PlacementSurface.of_body(small).is_declared_support,
			"objet ordinaire : dessus non déclaré")
	_check(floor_surface.is_declared_support and table_surface.is_declared_support, "sol et table : supports déclarés")

	# rests_on_declared_support() : quatre cas.
	_check(not small.rests_on_declared_support(), "non posé : faux")
	small.on_placed(floor_surface)
	_check(not small.rests_on_declared_support(), "au sol : faux")
	small.on_picked_up()
	small.on_placed(table_surface)
	_check(small.rests_on_declared_support(), "sur support fixe déclaré : vrai")
	small.on_picked_up()
	small.on_placed(PlacementSurface.of_body(low))
	_check(small.rests_on_declared_support(), "sur meuble libre : vrai")
	small.on_picked_up()
	small.on_placed(PlacementSurface.of_body(ordinary))
	_check(not small.rests_on_declared_support(), "sur objet ordinaire : faux")
	small.on_picked_up()

	# Empilement selon STACK_TABLE inchangée (meuble LARGE).
	var check: PlacementCheck = PlacementCheck.new()
	_check(check.can_stack(small.item_data.category, low.item_data.category) and check.can_stack(medium.item_data.category, low.item_data.category),
			"meuble : porte SMALL et MEDIUM")
	_check(not check.can_stack(ordinary.item_data.category, low.item_data.category) and not check.can_stack(low.item_data.category, medium.item_data.category),
			"meuble : ne porte pas un LARGE ; pas de meuble sur un MEDIUM")

	var player: Player = room.get_node("Player")
	var carry: CarryController = player.get_node("CarryController")
	var placement: PlacementController = player.get_node("PlacementController")
	var msg: Label = player.prompt.get_node("Message")
	var low_top: Vector3 = low.global_position + Vector3.UP * low.item_data.height * 0.5

	# Pose d'un MEDIUM sur le meuble bas.
	_hold(carry, medium)
	_aim_at(player, Vector3(-1.5, 0.05, 4.6), low_top)
	await physics_frame
	placement._update_target()
	_check(placement._surface == PlacementSurface.of_body(low) and placement._verdict == PlacementController.Verdict.OK,
			"MEDIUM sur meuble : OK (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(medium.support_surface == PlacementSurface.of_body(low) and low.loads.has(medium) and medium.rests_on_declared_support(),
			"MEDIUM posé : charge du meuble, posé sur support déclaré")
	await physics_frame

	# Un LARGE ordinaire ne se pose pas sur le meuble (CANNOT_STACK).
	_hold(carry, ordinary)
	_aim_at(player, Vector3(-1.5, 0.05, 4.6), low_top + Vector3(0.0, 0.0, 0.27)) # hors du MEDIUM posé au centre
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.CANNOT_STACK, "LARGE sur meuble : interdit (verdict %d)" % placement._verdict)
	carry.inventory.drop_object()
	carry._refresh_visuals()
	ordinary.reparent(room.get_node("TestItems"), false) # remis à sa place d'origine
	ordinary.global_transform = Transform3D(Basis.IDENTITY, Vector3(2.25, 0.45, -3.4))
	ordinary.visible = true
	ordinary.collision_layer = 4

	# Meuble chargé : non prenable, puis prenable après retrait de la charge.
	carry.pick_up(low.get_node("Interactable"))
	_check(carry.held_body() == null and msg.text == "carry.supports_object" and low.has_loads(), "meuble chargé : non prenable")
	carry.pick_up(medium.get_node("Interactable"))
	_check(carry.held_body() == medium and not low.has_loads(), "charge retirée : le meuble est libéré")
	_aim_at(player, Vector3(-3.0, 0.05, 2.2), Vector3(-3.0, 0.0, 1.5))
	await physics_frame
	placement._update_target()
	placement.place_held()
	_check(carry.held_body() == null and medium.support_surface == floor_surface, "MEDIUM reposé au sol")
	await physics_frame
	msg.text = ""
	carry.pick_up(low.get_node("Interactable"))
	_check(carry.held_body() == low and msg.text == "" and low.support_surface == null, "meuble sans charge : prise à deux mains")

	# Déplacement : pose au sol ailleurs, puis nouvelle charge cohérente.
	_aim_at(player, Vector3(1.0, 0.05, 2.9), Vector3(1.0, 0.0, 2.0))
	await physics_frame
	placement._update_target()
	_check(placement._surface == floor_surface and placement._verdict == PlacementController.Verdict.OK,
			"meuble : pose au sol valide (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(carry.held_body() == null and low.support_surface == floor_surface and low.loads.is_empty() and not low.rests_on_declared_support(),
			"meuble déplacé : au sol, sans charge")
	await physics_frame
	var moved_top: Vector3 = low.global_position + Vector3.UP * low.item_data.height * 0.5
	_hold(carry, small)
	_aim_at(player, Vector3(1.0, 0.05, 2.9), moved_top)
	await physics_frame
	placement._update_target()
	placement.place_held()
	_check(small.support_surface == PlacementSurface.of_body(low) and low.loads.has(small) and small.rests_on_declared_support(),
			"meuble déplacé : porte une nouvelle charge, état cohérent")
	room.queue_free()
	await process_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_failures += 1
