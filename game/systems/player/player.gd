class_name Player
extends CharacterBody3D
## Joueur à la première personne. Yaw sur Player, pitch sur Head. Valeurs provisoires.

const PITCH_LIMIT: float = deg_to_rad(89.0)
const STEP_MARGIN: float = 0.005 ## m, marge au-dessus de l'arête franchie

@export var walk_speed: float = 2.5 ## m/s
@export var slow_walk_speed: float = 1.2 ## m/s
@export var slow_walk_toggle: bool = true ## true : walk_slow bascule la marche lente ; false : maintenu
@export var mouse_sensitivity: float = 0.002 ## rad/pixel
@export var gravity: float = 9.8 ## m/s²
@export var max_step_height: float = 0.3 ## m, PROVISOIRE ; plus haute marche franchie à pied (0 = désactivé)
@export var step_smooth_time: float = 0.12 ## s, PROVISOIRE ; durée du lissage de la tête après un step-up (0 = aucun)

@export_range(1, 5) var belt_capacity: int = 1 ## emplacements de ceinture (SMALL), 1 au départ, 5 au maximum

@export var fall_limit_y: float = -10.0 ## m ; sous cette hauteur, retour au départ

@onready var head: Node3D = $Head
@onready var sensor: InteractionSensor = $Head/InteractionSensor
@onready var prompt: InteractionPrompt = $InteractionPrompt

## Caméra figée (lock_camera, bascule) : le regard ne tourne plus, le curseur est libre dans la fenêtre.
var camera_locked: bool = false

var _skip_motion: bool = false ## ignore le 1er mouvement après le déverrouillage (pas de saut de caméra)

var _start_position: Vector3
var _step_hold: float = 0.0 ## s restantes sans gravité après un step-up (passage du bord de la marche)
var _head_rest_y: float ## hauteur de repos de Head (locale)
var _head_offset: float = 0.0 ## m, décalage visuel de Head (<= 0) après un step-up, ramené à 0
var _head_rate: float = 0.0 ## m/s, vitesse constante de retour de Head, fixée à chaque step-up
var _slow_walk_on: bool = false ## état de bascule de la marche lente (jamais remis à zéro automatiquement)


func _ready() -> void:
	_start_position = global_position
	_head_rest_y = head.position.y
	sensor.target_changed.connect(prompt.set_target)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _skip_motion:
			_skip_motion = false
		else:
			look_by((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed(&"lock_camera", false):
		set_camera_locked(not camera_locked)
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
	if _step_hold > 0.0:
		_step_hold -= delta
	var grounded: bool = is_on_floor() or _step_hold > 0.0
	velocity.y = 0.0 if grounded else velocity.y - gravity * delta
	if grounded:
		try_step_up(Vector3(velocity.x, 0.0, velocity.z) * delta)
	move_and_slide()
	_smooth_head(delta)
	check_fall()


## Step-up : si le déplacement horizontal `motion` est arrêté par un obstacle vertical (marche) d'au plus
## max_step_height, pose le joueur à la hauteur du dessus de la marche et suspend la gravité le temps de
## passer le bord (_step_hold), sinon la capsule glisserait sur l'arête. Retourne true si le joueur a été relevé.
## Sans effet sans mouvement, sur une pente franchissable, sans sol au-dessus de la marche ou si l'obstacle est trop haut.
func try_step_up(motion: Vector3) -> bool:
	if max_step_height <= 0.0 or motion.length_squared() < 1e-10:
		return false
	var blocked: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	if not PhysicsServer3D.body_test_motion(get_rid(), _motion_params(global_transform, motion), blocked):
		return false
	if blocked.get_collision_normal().y > cos(floor_max_angle) or blocked.get_collision_normal().y < -0.1:
		return false # sol ou pente franchissable, ou plafond : pas une marche
	# Hauteur de l'arête heurtée au-dessus des pieds, plus une marge ; au-delà du maximum : pas franchissable.
	var edge: float = blocked.get_collision_point().y - global_position.y + STEP_MARGIN
	if edge > max_step_height or edge <= STEP_MARGIN:
		return false
	var up: Vector3 = Vector3.UP * edge
	if PhysicsServer3D.body_test_motion(get_rid(), _motion_params(global_transform, up), null):
		return false # tête contre un plafond
	var raised: Transform3D = global_transform.translated(up)
	if PhysicsServer3D.body_test_motion(get_rid(), _motion_params(raised, motion), null):
		return false # toujours bloqué une fois relevé : obstacle plus haut que l'arête mesurée
	global_position.y += edge
	if step_smooth_time > 0.0:
		_head_offset -= edge # la tête reste à sa hauteur d'avant, puis redescend à 0 (_smooth_head)
		_head_rate = absf(_head_offset) / step_smooth_time
		head.position.y = _head_rest_y + _head_offset
	_step_hold = _step_clear_distance() / maxf(motion.length() / get_physics_process_delta_time(), 0.01)
	return true


## Ramène le décalage visuel de Head vers 0 à vitesse constante : le décalage cumulé est résorbé en
## step_smooth_time. N'agit que sur la position de Head (jamais sur le pitch, la descente ni les chutes).
func _smooth_head(delta: float) -> void:
	if _head_offset == 0.0:
		return
	if step_smooth_time <= 0.0:
		_head_offset = 0.0
	else:
		_head_offset = move_toward(_head_offset, 0.0, _head_rate * delta)
	head.position.y = _head_rest_y + _head_offset


## Distance horizontale à parcourir pour passer le bord d'une marche : rayon de la capsule + 0,1 m.
func _step_clear_distance() -> float:
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D")
	var radius: float = 0.3
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		radius = (shape_node.shape as CapsuleShape3D).radius
	return radius + 0.1


func _motion_params(from: Transform3D, motion: Vector3) -> PhysicsTestMotionParameters3D:
	var params: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	params.margin = safe_margin
	return params


## Marche lente active : état de bascule, ou touche maintenue si slow_walk_toggle = false.
func is_slow_walking() -> bool:
	return _slow_walk_on if slow_walk_toggle else Input.is_action_pressed(&"walk_slow")


## Remet le joueur au départ (vitesse nulle) s'il est tombé sous fall_limit_y.
func check_fall() -> void:
	if global_position.y < fall_limit_y:
		global_position = _start_position
		velocity = Vector3.ZERO


## Fige ou libère la rotation de la caméra (bascule C ; relâché par ToolController). Figée : curseur visible, confiné à la fenêtre
## (les outils visent alors au curseur). Sans effet si la souris n'est pas capturée au départ.
func set_camera_locked(locked: bool) -> void:
	if locked == camera_locked or (locked and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		return
	camera_locked = locked
	_skip_motion = not locked ## la recapture peut émettre un grand déplacement relatif
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
