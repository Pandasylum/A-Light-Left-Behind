extends SceneTree
## Test de CarryInventory. Lancer : tools/godot.sh --headless --path game --script res://tests/test_carry.gd

const R := CarryInventory.Result
const C := ItemData.Category

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _item(cat: ItemData.Category, n: String = "x") -> ItemData:
	var d: ItemData = ItemData.new()
	d.id = StringName(n)
	d.category = cat
	return d


func _run() -> void:
	# Tableau de cas : [description, état initial (main, nb ceinture), objet pris, résultat, main finale, ceinture finale]
	var cases: Array = [
		["FIXED, main vide", -1, 0, C.FIXED, R.FIXED, -1, 0],
		["FIXED, main SMALL", C.SMALL, 0, C.FIXED, R.FIXED, C.SMALL, 0],
		["SMALL, main vide -> main", -1, 0, C.SMALL, R.OK, C.SMALL, 0],
		["SMALL, main SMALL -> ceinture", C.SMALL, 0, C.SMALL, R.OK, C.SMALL, 1],
		["SMALL, ceinture pleine", C.SMALL, 5, C.SMALL, R.BELT_FULL, C.SMALL, 5],
		["SMALL, main MEDIUM", C.MEDIUM, 0, C.SMALL, R.HANDS_FULL, C.MEDIUM, 0],
		["SMALL, main LARGE", C.LARGE, 0, C.SMALL, R.HANDS_FULL, C.LARGE, 0],
		["MEDIUM, main vide", -1, 0, C.MEDIUM, R.OK, C.MEDIUM, 0],
		["MEDIUM, main SMALL", C.SMALL, 0, C.MEDIUM, R.HANDS_FULL, C.SMALL, 0],
		["MEDIUM, main MEDIUM", C.MEDIUM, 0, C.MEDIUM, R.HANDS_FULL, C.MEDIUM, 0],
		["LARGE, main vide", -1, 0, C.LARGE, R.OK, C.LARGE, 0],
		["LARGE, main SMALL", C.SMALL, 0, C.LARGE, R.HANDS_FULL, C.SMALL, 0],
		["LARGE, main LARGE (un seul)", C.LARGE, 0, C.LARGE, R.HANDS_FULL, C.LARGE, 0],
	]
	for c: Array in cases:
		var inv: CarryInventory = CarryInventory.new()
		if c[1] != -1:
			inv.pick_up(_item(c[1]))
		for i: int in c[2]:
			inv.add_to_belt(_item(C.SMALL))
		var res: CarryInventory.Result = inv.pick_up(_item(c[3]))
		_check(res == c[4], "%s : résultat" % c[0])
		var held_cat: int = inv.held().category if inv.held() != null else -1
		_check(held_cat == c[5], "%s : main" % c[0])
		_check(inv.belt_count() == c[6], "%s : ceinture" % c[0])

	# MEDIUM / LARGE jamais à la ceinture
	var inv: CarryInventory = CarryInventory.new()
	_check(inv.add_to_belt(_item(C.MEDIUM)) == R.NOT_STOWABLE, "MEDIUM -> NOT_STOWABLE")
	_check(inv.add_to_belt(_item(C.LARGE)) == R.NOT_STOWABLE, "LARGE -> NOT_STOWABLE")
	_check(inv.add_to_belt(_item(C.FIXED)) == R.FIXED, "FIXED ceinture -> FIXED")
	_check(inv.belt_count() == 0, "ceinture restée vide")

	# Capacité : 6 SMALL (main + ceinture), le 7e refusé
	inv = CarryInventory.new()
	for i: int in 6:
		_check(inv.pick_up(_item(C.SMALL, "s%d" % i)) == R.OK, "SMALL %d accepté" % i)
	_check(inv.held() != null and inv.belt_count() == 5, "main + 5 ceinture")
	_check(inv.pick_up(_item(C.SMALL)) == R.BELT_FULL, "7e SMALL refusé")

	# Dépôt
	var dropped: ItemData = inv.drop_object()
	_check(dropped != null and inv.held() == null, "drop vide la main")
	_check(inv.drop_object() == null, "drop main vide -> null")
	_check(inv.pick_up(_item(C.SMALL)) == R.OK, "place libre après dépôt")

	# Cycle : échange dans l'ordre
	inv = CarryInventory.new()
	var a: ItemData = _item(C.SMALL, "a")
	var b: ItemData = _item(C.SMALL, "b")
	var d: ItemData = _item(C.SMALL, "d")
	inv.pick_up(a)
	inv.pick_up(b)
	inv.pick_up(d) # main a ; ceinture [b, d]
	_check(inv.cycle_item() == R.OK and inv.held() == b and inv.belt_item(0) == a, "cycle 1 : échange avec b")
	_check(inv.cycle_item() == R.OK and inv.held() == d and inv.belt_item(1) == b, "cycle 2 : échange avec d")
	_check(inv.cycle_item() == R.OK and inv.held() == a and inv.belt_item(0) == d, "cycle 3 : bouclage sur a")
	_check(inv.belt_count() == 2, "cycle conserve le total")
	# Main vide : prend le prochain occupé
	inv.drop_object()
	var before: int = inv.belt_count()
	_check(inv.cycle_item() == R.OK and inv.held() != null and inv.belt_count() == before - 1, "main vide : prend le suivant")
	# Sans objet à la ceinture : sans effet
	inv = CarryInventory.new()
	inv.pick_up(a)
	_check(inv.cycle_item() == R.OK and inv.held() == a, "ceinture vide : sans effet")
	# Main MEDIUM : sans effet + message
	inv = CarryInventory.new()
	var m: ItemData = _item(C.MEDIUM)
	inv.pick_up(m)
	_check(inv.cycle_item() == R.HANDS_FULL and inv.held() == m, "cycle avec MEDIUM : HANDS_FULL, inchangé")

	# Signaux
	inv = CarryInventory.new()
	var counts: Array[int] = [0, 0]
	inv.held_changed.connect(func(_i: ItemData) -> void: counts[0] += 1)
	inv.belt_changed.connect(func(_s: int, _i: ItemData) -> void: counts[1] += 1)
	inv.pick_up(a)
	inv.pick_up(b)
	_check(counts[0] == 1 and counts[1] == 1, "signaux held_changed / belt_changed")

	print("test_carry : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("ÉCHEC : ", label)
