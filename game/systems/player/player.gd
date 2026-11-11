class_name Player
extends CharacterBody3D
## Joueur à la première personne. Yaw sur Player, pitch sur Head. Valeurs provisoires.

const PITCH_LIMIT: float = deg_to_rad(89.0)

@export var walk_speed: float = 2.5 ## m/s
@export var slow_walk_speed: float = 1.2 ## m/s
@export var slow_walk_toggle: bool = true ## true : walk_slow bascule la marche lente ; false : maintenu
@export var mouse_sensitivity: float = 0.002 ## rad/pixel
@export var gravity: float = 9.8 ## m/s²

@export_range(1, 5) var belt_capacity: int = 1 ## emplacements de ceinture (SMALL), 1 au départ, 5 au maximum

@export var fall_limit_y: float = -10.0 ## m ; sous cette hauteur, retour au départ

@onready var head: Node3D = $Head
@onready var sensor: InteractionSensor = $Head/InteractionSensor
@onready var prompt: InteractionPrompt = $InteractionPrompt

## Caméra figée (lock_camera maintenu) : le regard ne tourne plus, le curseur est libre dans la fenêtre.
var camera_locked: bool = false

var _start_position: Vector3
var _slow_walk_on: bool = false ## état de bascule de la marche lente (jamais remis à zéro automatiquement)


func _ready() -> void:
	_start_position = global_position
	sensor.target_changed.connect(prompt.set_target)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_by((event as InputEventMouseMotion).relative)
	elif event.is_action(&"lock_camera"):
		if not event.is_echo():
			set_camera_locked(event.is_pressed())
	elif slow_walk_toggle and event.is_action_pressed(&"walk_slow", false):
		_slow_walk_on = not _slow_walk_on
	elif event.is_action_pressed(&"pause_menu"):
		camera_locked = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not camera_locked:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var horizontal: Vector3 = compute_horizontal_velocity(input_dir, is_slow_walking())
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	check_fall()


## Marche lente active : état de bascule, ou touche maintenue si slow_walk_toggle = false.
func is_slow_walking() -> bool:
	return _slow_walk_on if slow_walk_toggle else Input.is_action_pressed(&"walk_slow")


## Remet le joueur au départ (vitesse nulle) s'il est tombé sous fall_limit_y.
func check_fall() -> void:
	if global_position.y < fall_limit_y:
		global_position = _start_position
		velocity = Vector3.ZERO


## Fige ou libère la rotation de la caméra. Figée : curseur visible, confiné à la fenêtre
## (les outils visent alors au curseur). Sans effet si la souris n'est pas capturée au départ.
func set_camera_locked(locked: bool) -> void:
	if locked == camera_locked or (locked and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		return
	camera_locked = locked
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED if locked else Input.MOUSE_MODE_CAPTURED


## Applique une rotation souris (en pixels) : yaw sur Player, pitch sur Head.
func look_by(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x - relative.y * mouse_sensitivity, -PITCH_LIMIT, PITCH_LIMIT)


## Vitesse horizontale monde à partir de l'entrée (x = droite, y = arrière) et de l'orientation.
func compute_horizontal_velocity(input_dir: Vector2, slow: bool) -> Vector3:
	var speed: float = slow_walk_speed if slow else walk_speed
	var direction: Vector3 = global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	return direction * speed
