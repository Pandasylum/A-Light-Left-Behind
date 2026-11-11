extends SceneTree
## Mesure de la montée de l'escalier hélicoïdal de cleaning_tour.tscn (défaut 1).
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_stairs.gd

const TOUR: String = "res://tests/test_cleaning/cleaning_tour.tscn"
const STEP_HEIGHT: float = 0.18
const RADIUS: float = 1.25 ## m, milieu des marches (noyau 0,5 – mur 2,0)

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var tour: Node3D = (load(TOUR) as PackedScene).instantiate()
	root.add_child(tour)
	var player: Player = tour.get_node("Player")
	var cam: Camera3D = player.get_node("Head/Camera3D")
	# Le joueur est piloté ici par l'entrée simulée ; la souris n'est pas capturée en headless.
	var angle: float = deg_to_rad(-20.0)
	player.global_position = Vector3(RADIUS * cos(angle), 0.0, -RADIUS * sin(angle))
	player.velocity = Vector3.ZERO
	player.slow_walk_toggle = false
	await _frames(30) # pose au sol
	print("Départ : pos %s, au sol %s" % [player.global_position, player.is_on_floor()])
	var y0: float = player.global_position.y
	Input.action_press(&"move_forward")
	var max_y: float = y0
	var reached: int = 0
	for i: int in 600:
		var p: Vector3 = player.global_position
		var a: float = atan2(-p.z, p.x)
		# Cap tangent à l'hélice (angle croissant), recentré sur le rayon médian.
		var tangent: Vector3 = Vector3(-sin(a), 0.0, -cos(a))
		var radial_error: float = Vector2(p.x, p.z).length() - RADIUS
		var heading: Vector3 = (tangent - Vector3(cos(a), 0.0, -sin(a)) * radial_error * 2.0).normalized()
		player.rotation.y = atan2(-heading.x, -heading.z)
		await physics_frame
		max_y = maxf(max_y, player.global_position.y)
		var step_reached: int = int((player.global_position.y - y0) / STEP_HEIGHT + 0.5)
		reached = maxi(reached, step_reached)
		if i % 60 == 0:
			print("t=%d angle %.1f° y %.3f au sol %s" % [i, rad_to_deg(a), player.global_position.y, player.is_on_floor()])
	Input.action_release(&"move_forward")
	print("MESURE : hauteur gagnée %.3f m (%d marches), angle final %.1f°" % [
		max_y - y0, reached, rad_to_deg(atan2(-player.global_position.z, player.global_position.x))])
	_check(reached >= 20, "le joueur monte au moins 20 des 24 marches (%d)" % reached)
	tour.free()
	await _test_blocks()
	quit(1 if _failures > 0 else 0)



func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _check(ok: bool, label: String) -> void:
	print(("OK    " if ok else "ECHEC ") + label)
	if not ok:
		_failures += 1


## Régression : un muret de 0,25 m est franchi, un de 0,5 m (> max_step_height) ne l'est pas.
func _test_blocks() -> void:
	for case: Array in [[0.25, true], [0.5, false]]:
		var world: Node3D = Node3D.new()
		root.add_child(world)
		_add_box(world, Vector3(20, 1, 20), Vector3(0, -0.5, 0))
		_add_box(world, Vector3(4, case[0], 0.5), Vector3(0, case[0] / 2.0, -2.0))
		var player: Player = (load("res://systems/player/player.tscn") as PackedScene).instantiate()
		world.add_child(player)
		player.global_position = Vector3(0, 0.0, 0.0)
		await _frames(10)
		Input.action_press(&"move_forward")
		await _frames(180)
		Input.action_release(&"move_forward")
		var crossed: bool = player.global_position.z < -2.5
		_check(crossed == case[1], "muret de %.2f m : franchi = %s (z %.2f, y %.3f)" % [case[0], crossed, player.global_position.z, player.global_position.y])
		world.free()


func _add_box(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)
