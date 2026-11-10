extends SceneTree
## Scénario de bout en bout de la Phase 1 (P1-E2) dans greybox.tscn. Le contrôleur est forcé actif comme
## dans test_placement.gd (souris non capturée en headless : appels directs, état de visée forcé).
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_phase1_flow.gd

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await _flow()
	print("test_phase1_flow : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _aim_at(player: Player, pos: Vector3, target: Vector3) -> void:
	player.global_position = pos
	var dir: Vector3 = target - player.get_node("Head/Camera3D").global_position
	player.rotation.y = atan2(-dir.x, -dir.z)
	player.head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())


func _top(item: TestItem) -> Vector3:
	return item.global_position + Vector3.UP * item.item_data.height * 0.5


func _flow() -> void:
	var room: Node3D = (load("res://rooms/test/greybox.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await physics_frame
	await physics_frame
	var player: Player = room.get_node("Player")
	var carry: CarryController = player.get_node("CarryController")
	var placement: PlacementController = player.get_node("PlacementController")
	var panel: InventoryPanel = player.get_node("InventoryPanel")
	var placed_root: Node = room.get_node("PlacedObjects")
	var items: Node = room.get_node("TestItems")
	var table: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestTable"))
	var floor_surface: PlacementSurface = PlacementSurface.of_body(room.get_node("Floor"))
	var small_a: TestItem = items.get_node("small_2")
	var small_b: TestItem = items.get_node("small_1")
	var medium: TestItem = items.get_node("medium_1")
	var furniture: TestItem = items.get_node("furniture_low")
	var table_center: Vector3 = Vector3(3.5, table.top_y(), -0.5)
	var standing: Vector3 = Vector3(3.5, 0.05, 0.7)

	# 1. Prendre un SMALL (main).
	carry.pick_up(small_a.get_node("Interactable"))
	_check(carry.held_body() == small_a, "SMALL en main")
	# 2. Prendre un MEDIUM : le SMALL est rangé automatiquement.
	carry.pick_up(medium.get_node("Interactable"))
	_check(carry.held_body() == medium and carry.inventory.belt_ref(0) == small_a and not small_a.visible,
			"MEDIUM en main, SMALL rangé à la ceinture")
	_check(panel.held_text() == medium.item_data.name_key and panel.row_texts()[1].contains(small_a.item_data.name_key),
			"panneau à jour (main et ceinture)")
	# 3. Tourner, 4. poser le MEDIUM sur la table.
	_aim_at(player, standing, table_center)
	await physics_frame
	placement.rotate_by(2)
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.OK, "table : pose du MEDIUM valide (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(carry.held_body() == null and medium.get_parent() == placed_root and medium.support_surface == table,
			"MEDIUM posé sur la table")
	_check(is_equal_approx(medium.global_transform.basis.get_euler().y, deg_to_rad(30.0)), "MEDIUM tourné de 30°")
	await physics_frame
	# 5. Reprendre le MEDIUM, puis le reposer.
	carry.pick_up(medium.get_node("Interactable"))
	_check(carry.held_body() == medium and medium.support_surface == null, "MEDIUM repris")
	placement._update_target()
	placement.place_held()
	_check(carry.held_body() == null and medium.support_surface == table, "MEDIUM reposé sur la table")
	await physics_frame
	# 6. Poser un SMALL sur un objet : le SMALL de la ceinture passe en main, posé sur le dessus du MEDIUM.
	carry.cycle()
	_check(carry.held_body() == small_a, "cycle_item : SMALL en main")
	_aim_at(player, standing, _top(medium))
	await physics_frame
	placement._update_target()
	_check(placement._surface == PlacementSurface.of_body(medium) and placement._verdict == PlacementController.Verdict.OK,
			"SMALL sur MEDIUM : OK (verdict %d)" % placement._verdict)
	placement.place_held()
	_check(small_a.support_surface == PlacementSurface.of_body(medium) and medium.loads.has(small_a), "SMALL posé sur le MEDIUM")
	await physics_frame
	# 7. Faire tomber un objet du bord d'un support (pose instable).
	carry.pick_up(small_b.get_node("Interactable"))
	_check(carry.held_body() == small_b, "autre SMALL en main")
	_aim_at(player, Vector3(4.1, 0.05, 0.7), Vector3(4.095, table.top_y(), -0.5))
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.UNSTABLE, "bord de la table : pose instable (verdict %d)" % placement._verdict)
	placement.place_held()
	var msg: Label = player.prompt.get_node("Message")
	_check(carry.held_body() == null and small_b.get_parent() == placed_root and msg.text == "place.fell",
			"l'objet est tombé (%s)" % msg.text)
	_check(small_b.support_surface != null and small_b.global_position.y < table.top_y(), "objet tombé sous le plateau")
	await physics_frame
	# 8. Reprendre l'objet tombé.
	carry.pick_up(small_b.get_node("Interactable"))
	_check(carry.held_body() == small_b and small_b.support_surface == null, "objet tombé repris")
	_aim_at(player, Vector3(-3.0, 0.05, 2.2), Vector3(-3.0, 0.0, 1.5))
	await physics_frame
	placement._update_target()
	placement.place_held() # mains libres pour le meuble
	_check(carry.held_body() == null and small_b.support_surface == floor_surface, "SMALL posé au sol, mains libres")
	await physics_frame
	# 9. Prendre et déplacer un meuble libre.
	carry.pick_up(furniture.get_node("Interactable"))
	_check(carry.held_body() == furniture, "meuble libre pris")
	_aim_at(player, Vector3(1.0, 0.05, 2.9), Vector3(1.0, 0.0, 2.0))
	await physics_frame
	placement._update_target()
	placement.place_held()
	_check(carry.held_body() == null and furniture.support_surface == floor_surface and furniture.global_position.x > 0.5,
			"meuble déplacé au sol")
	_check(carry.inventory.held() == null and panel.held_text() == "", "fin : main vide, label vide")
	room.queue_free()
	await process_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_failures += 1
