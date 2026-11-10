extends SceneTree
## Test des classes de données. Lancer : tools/godot.sh --headless --path game --script res://tests/data_validation_test.gd


func _init() -> void:
	var cases: Array[Callable] = [
		_valid_item, _invalid_item, _furniture_support, _valid_zone, _invalid_zone,
		_valid_room, _invalid_room, _default_rules, _invalid_rules,
	]
	for c: Callable in cases:
		var err: String = c.call()
		if err != "":
			print("FAIL ", c.get_method(), " : ", err)
			quit(1)
			return
		print("PASS ", c.get_method())
	quit(0)


## Renvoie "" si les erreurs attendues sont présentes (ou absentes si expected vide).
func _expect(errors: PackedStringArray, expected: Array[String]) -> String:
	if expected.is_empty():
		return "" if errors.is_empty() else "erreurs inattendues : %s" % [errors]
	for e: String in expected:
		if not errors.has(e):
			return "erreur attendue absente : %s (obtenu %s)" % [e, errors]
	return ""


func _valid_item() -> String:
	var i: ItemData = ItemData.new()
	i.id = &"livre"
	i.tracks_storing = true
	return _expect(i.validate(), [])


func _invalid_item() -> String:
	var i: ItemData = ItemData.new()
	i.footprint = Vector2(0.0, 0.5)
	i.height = 0.0
	i.category = ItemData.Category.FIXED
	i.tracks_storing = true
	return _expect(i.validate(), [
		"id vide", "emprise non strictement positive", "hauteur non strictement positive",
		"un objet FIXED ne suit pas l'axe rangement",
	])


func _furniture_support() -> String:
	var i: ItemData = ItemData.new()
	i.id = &"meuble"
	i.provides_support = true
	for c: ItemData.Category in [ItemData.Category.SMALL, ItemData.Category.FIXED]:
		i.category = c
		var e: String = _expect(i.validate(), ["provides_support exige une catégorie MEDIUM ou LARGE"])
		if e != "":
			return e
	for c: ItemData.Category in [ItemData.Category.MEDIUM, ItemData.Category.LARGE]:
		i.category = c
		var e2: String = _expect(i.validate(), [])
		if e2 != "":
			return e2
	return ""


func _valid_zone() -> String:
	var z: ZoneData = ZoneData.new()
	z.id = &"etagere"
	z.accepted_categories = [ItemData.Category.SMALL, ItemData.Category.MEDIUM]
	return _expect(z.validate(), [])


func _invalid_zone() -> String:
	var z: ZoneData = ZoneData.new()
	var err: String = _expect(z.validate(), ["id vide", "liste de catégories vide"])
	if err != "":
		return err
	z.id = &"x"
	z.accepted_categories = [ItemData.Category.FIXED]
	return _expect(z.validate(), ["la catégorie FIXED ne peut pas être acceptée"])


func _valid_room() -> String:
	var r: RoomData = RoomData.new()
	r.id = &"salon"
	r.active_axes = [RoomData.Axis.CLEANING]
	return _expect(r.validate(), [])


func _invalid_room() -> String:
	return _expect(RoomData.new().validate(), ["id vide", "aucun axe actif"])


func _default_rules() -> String:
	return _expect(PlacementRules.new().validate(), [])


func _invalid_rules() -> String:
	var p: PlacementRules = PlacementRules.new()
	p.rotation_step_degrees = 7.0
	p.edge_margin = -1.0
	p.min_support_coverage = 0.0
	return _expect(p.validate(), [
		"le pas de rotation doit être positif et diviser 360",
		"marge au bord négative", "couverture minimale hors de ]0, 1]",
	])
