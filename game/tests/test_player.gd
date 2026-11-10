extends SceneTree
## Test du joueur. Lancer : tools/godot.sh --headless --path game --script res://tests/test_player.gd

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var scene: PackedScene = load("res://systems/player/player.tscn")
	var p: Player = scene.instantiate()
	root.add_child(p)

	_check(p is CharacterBody3D and p.name == &"Player", "racine CharacterBody3D nommée Player")
	var shape_node: CollisionShape3D = p.get_node_or_null("CollisionShape3D")
	_check(shape_node != null and shape_node.shape is CapsuleShape3D, "CollisionShape3D capsule")
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		var cap: CapsuleShape3D = shape_node.shape
		_check(is_equal_approx(cap.height, 1.8) and is_equal_approx(cap.radius, 0.3), "capsule 1,8 m / rayon 0,3 m")
	var head: Node3D = p.get_node_or_null("Head")
	_check(head != null and is_equal_approx(head.position.y, 1.6), "Head à 1,6 m")
	_check(p.get_node_or_null("Head/Camera3D") is Camera3D, "Camera3D sous Head")
	_check(is_equal_approx(p.walk_speed, 2.5), "marche 2,5")
	_check(is_equal_approx(p.slow_walk_speed, 1.2), "marche lente 1,2")
	_check(is_equal_approx(p.mouse_sensitivity, 0.002), "sensibilité 0,002")

	# Logique de déplacement (appel direct, sans entrée réelle).
	var v: Vector3 = p.compute_horizontal_velocity(Vector2(0, -1), false)
	_check(v.is_equal_approx(Vector3(0, 0, -2.5)), "avant = -Z à 2,5 m/s (obtenu %s)" % v)
	v = p.compute_horizontal_velocity(Vector2(0, -1), true)
	_check(v.is_equal_approx(Vector3(0, 0, -1.2)), "marche lente 1,2 m/s (obtenu %s)" % v)
	p.rotate_y(PI / 2.0)
	v = p.compute_horizontal_velocity(Vector2(0, -1), false)
	_check(v.is_equal_approx(Vector3(-2.5, 0, 0)), "orientation suivie (obtenu %s)" % v)

	# Regard : pitch limité à ±89°, yaw sur Player.
	p.look_by(Vector2(0, -100000))
	_check(is_equal_approx(p.head.rotation.x, deg_to_rad(89.0)), "pitch max 89°")
	p.look_by(Vector2(0, 200000))
	_check(is_equal_approx(p.head.rotation.x, deg_to_rad(-89.0)), "pitch min -89°")
	var yaw_before: float = p.rotation.y
	p.look_by(Vector2(100, 0))
	_check(not is_equal_approx(p.rotation.y, yaw_before), "yaw sur Player")

	print("test_player : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_failures += 1
