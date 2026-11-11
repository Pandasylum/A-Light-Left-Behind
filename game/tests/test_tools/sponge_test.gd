extends Node3D
## Scène de vérification de l'éponge (NON OFFICIELLE) : tour d'essai instanciée telle quelle,
## joueur du tour équipé de l'outil, seau de rinçage posé au sol.

@export var tool: ToolData

@onready var _tour: Node3D = $Tour
@onready var _bucket: Node3D = $RinseBucket


func _ready() -> void:
	# Le pinceau de test du spike écoute aussi use_primary : on coupe son _physics_process
	# (il ne fait que cela), sans modifier le spike.
	_tour.set_physics_process(false)
	($Tour/Player/ToolController as ToolController).equip(tool)
	await get_tree().physics_frame
	_drop_bucket()


## Pose le seau sur le sol sous sa position (rayon vertical, couche monde).
func _drop_bucket() -> void:
	var top: Vector3 = _bucket.global_position + Vector3.UP
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 4.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_bucket.global_position = hit["position"]
