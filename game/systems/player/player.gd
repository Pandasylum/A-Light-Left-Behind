class_name Player
extends CharacterBody3D
## Joueur à la première personne. Yaw sur Player, pitch sur Head. Valeurs provisoires.

const PITCH_LIMIT: float = deg_to_rad(89.0)

@export var walk_speed: float = 2.5 ## m/s
@export var slow_walk_speed: float = 1.2 ## m/s
@export var mouse_sensitivity: float = 0.002 ## rad/pixel
@export var gravity: float = 9.8 ## m/s²

@export var fall_limit_y: float = -10.0 ## m ; sous cette hauteur, retour au départ

@onready var head: Node3D = $Head
@onready var sensor: InteractionSensor = $Head/InteractionSensor
@onready var prompt: InteractionPrompt = $InteractionPrompt

var _start_position: Vector3


func _ready() -> void:
	_start_position = global_position
	sensor.target_changed.connect(prompt.set_target)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_by((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed(&"pause_menu"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var horizontal: Vector3 = compute_horizontal_velocity(input_dir, Input.is_action_pressed(&"walk_slow"))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	check_fall()


## Remet le joueur au départ (vitesse nulle) s'il est tombé sous fall_limit_y.
func check_fall() -> void:
	if global_position.y < fall_limit_y:
		global_position = _start_position
		velocity = Vector3.ZERO


## Applique une rotation souris (en pixels) : yaw sur Player, pitch sur Head.
func look_by(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x - relative.y * mouse_sensitivity, -PITCH_LIMIT, PITCH_LIMIT)


## Vitesse horizontale monde à partir de l'entrée (x = droite, y = arrière) et de l'orientation.
func compute_horizontal_velocity(input_dir: Vector2, slow: bool) -> Vector3:
	var speed: float = slow_walk_speed if slow else walk_speed
	var direction: Vector3 = global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	return direction * speed
