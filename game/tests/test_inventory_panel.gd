extends SceneTree
## Test du panneau d'inventaire (P1-E2). Lancer : tools/godot.sh --headless --path game --script res://tests/test_inventory_panel.gd

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _item(cat: ItemData.Category, key: String) -> ItemData:
	var d: ItemData = ItemData.new()
	d.id = StringName(key)
	d.name_key = key
	d.category = cat
	return d


func _belt(items: Array[ItemData], capacity: int) -> Array[ItemData]:
	var belt: Array[ItemData] = items.duplicate()
	belt.resize(capacity)
	return belt


func _run() -> void:
	_test_rows()
	await _test_scene()
	print("test_inventory_panel : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_rows() -> void:
	var small: ItemData = _item(ItemData.Category.SMALL, "item.cup")
	var medium: ItemData = _item(ItemData.Category.MEDIUM, "item.box")
	# Main vide, capacité 1.
	var rows: Array[Dictionary] = InventoryPanel.build_rows(null, _belt([], 1))
	_check(rows.size() == 2 and rows[0]["empty"] and rows[1]["empty"], "capacité 1, tout vide : 2 lignes vides")
	_check(rows[0]["text"] == "Main : vide", "main vide : texte (%s)" % rows[0]["text"])
	# Main tenue, clé brute sans traduction.
	rows = InventoryPanel.build_rows(medium, _belt([], 1))
	_check(not rows[0]["empty"] and rows[0]["name"] == "item.box" and rows[0]["category"] == "Moyen", "main tenue : clé brute + catégorie")
	_check(rows[0]["text"] == "Main : item.box (Moyen)", "main tenue : texte (%s)" % rows[0]["text"])
	_check(rows[1]["empty"], "ceinture vide avec main tenue")
	# Capacité 5, ceinture partielle (emplacements 1 et 3 occupés).
	var partial: Array[ItemData] = _belt([small, null, small], 5)
	rows = InventoryPanel.build_rows(small, partial)
	_check(rows.size() == 6, "capacité 5 : 6 lignes")
	_check(not rows[1]["empty"] and rows[2]["empty"] and not rows[3]["empty"] and rows[4]["empty"] and rows[5]["empty"],
			"ceinture partielle : emplacements occupés / vides")
	# Ceinture pleine.
	var full: Array[ItemData] = _belt([small, small, small, small, small], 5)
	rows = InventoryPanel.build_rows(medium, full)
	var all_filled: bool = true
	for r: Dictionary in rows:
		all_filled = all_filled and not r["empty"]
	_check(rows.size() == 6 and all_filled, "ceinture pleine : aucune ligne vide")
	# Capacité 1 pleine.
	rows = InventoryPanel.build_rows(small, _belt([small], 1))
	_check(rows.size() == 2 and not rows[1]["empty"], "capacité 1 pleine : 2 lignes")
	# Clé vide : repli sur l'id.
	var nameless: ItemData = _item(ItemData.Category.SMALL, "")
	nameless.id = &"raw_id"
	_check(InventoryPanel.item_name(nameless) == "raw_id", "clé vide : id")


func _test_scene() -> void:
	var player: Player = (load("res://systems/player/player.tscn") as PackedScene).instantiate()
	player.belt_capacity = 3
	root.add_child(player)
	await physics_frame
	var panel: InventoryPanel = player.get_node("InventoryPanel")
	var carry: CarryController = player.get_node("CarryController")
	_check(panel != null and player.get_node("InteractionPrompt") != null, "panneau instancié dans Player")
	_check(not panel.is_open(), "panneau masqué au départ")
	_check(panel.row_texts().size() == 4 and panel.held_text() == "", "capacité 3 : 4 lignes, label vide")
	panel.toggle()
	_check(panel.is_open(), "toggle : ouvert")
	panel.toggle()
	_check(not panel.is_open(), "toggle : masqué")
	var a: ItemData = _item(ItemData.Category.SMALL, "item.a")
	var b: ItemData = _item(ItemData.Category.SMALL, "item.b")
	carry.inventory.pick_up(a)
	_check(panel.held_text() == "item.a" and panel.get_node("HeldLabel").text == "item.a", "held_changed : label de la main")
	_check(panel.row_texts()[0] == "Main : item.a (Petit)", "held_changed : ligne Main (%s)" % panel.row_texts()[0])
	carry.inventory.pick_up(b)
	_check(panel.row_texts()[1] == "Ceinture 1 : item.b (Petit)", "belt_changed : ligne ceinture (%s)" % panel.row_texts()[1])
	carry.inventory.drop_object()
	_check(panel.held_text() == "" and panel.row_texts()[0] == "Main : vide", "main vidée : label et ligne vides")
	player.queue_free()
	await process_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_failures += 1
