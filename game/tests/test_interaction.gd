extends SceneTree
## Test d'interaction. Lancer : tools/godot.sh --headless --path game --script res://tests/test_interaction.gd

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var p: Player = (load("res://systems/player/player.tscn") as PackedScene).instantiate()
	root.add_child(p)
	var sensor: InteractionSensor = p.sensor
	# Le mode souris CAPTURED est ignoré en headless : sous-classe de test forçant l'état.
	var fake: GDScript = GDScript.new()
	fake.source_code = "extends InteractionSensor\nvar captured: bool = true\nfunc _is_active() -> bool:\n\treturn captured\n"
	fake.reload()
	var fsensor: InteractionSensor = fake.new()
	root.add_child(fsensor)

	var with_it: StaticBody3D = StaticBody3D.new()
	var it: Interactable = Interactable.new()
	it.prompt_key = "some.key"
	with_it.add_child(it)
	var without: StaticBody3D = StaticBody3D.new()
	root.add_child(with_it)
	root.add_child(without)

	_check(sensor.resolve_target(with_it) == it, "corps avec Interactable -> cible")
	_check(sensor.resolve_target(without) == null, "corps sans Interactable -> null")
	_check(sensor.resolve_target(null) == null, "aucun corps -> null")

	# target_changed uniquement au changement
	var emitted: Array[int] = [0]
	sensor.target_changed.connect(func(_t: Interactable) -> void: emitted[0] += 1)
	sensor.set_target(it)
	sensor.set_target(it)
	_check(emitted[0] == 1, "target_changed émis une fois pour une même cible")
	sensor.set_target(null)
	_check(emitted[0] == 2, "target_changed émis au retour à null")

	# interacted
	var got: Array = [null]
	it.interacted.connect(func(who: Node) -> void: got[0] = who)
	it.interact(p)
	_check(got[0] == p, "signal interacted émis avec le joueur")

	# trigger_interact : actif si souris capturée, ignoré sinon
	fsensor.set_target(it)
	got[0] = null
	fsensor.trigger_interact()
	_check(got[0] != null, "interact appelé sur la cible (souris capturée)")
	fsensor.set("captured", false)
	got[0] = null
	fsensor.trigger_interact()
	_check(got[0] == null, "action ignorée souris non capturée")

	# indice du HUD
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	p.prompt.set_target(it)
	_check(p.prompt.hint.visible and p.prompt.hint.text == "some.key", "indice = clé si pas de traduction")
	p.prompt.set_target(null)
	_check(not p.prompt.hint.visible, "indice masqué sans cible")

	# chute
	p.global_position = Vector3(3, 0.05, 2)
	p._start_position = Vector3(0, 0.05, 0)
	p.velocity = Vector3(0, -20, 0)
	p.global_position = Vector3(3, -11, 2)
	p.check_fall()
	_check(p.global_position.is_equal_approx(Vector3(0, 0.05, 0)) and p.velocity == Vector3.ZERO, "remise au départ après chute")
	p.global_position = Vector3(3, -5, 2)
	p.check_fall()
	_check(p.global_position.y == -5.0, "pas de remise au-dessus de la limite")

	print("test_interaction : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_failures += 1
