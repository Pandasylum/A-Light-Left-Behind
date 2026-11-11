extends Node3D
## Scène de vérification des outils du joueur (NON OFFICIELLE) : tour d'essai instanciée telle
## quelle, éponge dans son emplacement (rangée au départ : equip_tool la sort), seau ramassable et
## objet de test posés au sol. Le sol du tour reçoit une surface de pose pour pouvoir les reposer.

const FLOOR_SIZE: Vector2 = Vector2(10.0, 10.0) ## emprise du sol du spike
const FLOOR_TOP_Y: float = 0.1 ## face supérieure, dans le repère du corps Floor

@export var tool: ToolData

@onready var _tour: Node3D = $Tour


func _ready() -> void:
	# Le pinceau de test du spike écoute aussi use_primary : on coupe son _physics_process
	# (il ne fait que cela), sans modifier le spike.
	_tour.set_physics_process(false)
	var surface: PlacementSurface = PlacementSurface.new()
	surface.name = "PlacementSurface"
	surface.size = FLOOR_SIZE
	surface.is_floor = true
	surface.position = Vector3(0.0, FLOOR_TOP_Y, 0.0)
	_tour.get_node(^"Floor").add_child(surface)
	($Tour/Player/ToolController as ToolController).add_tool(tool)
	await get_tree().physics_frame
	_drop_to_floor($Bucket as TestItem)
	_drop_to_floor($TestItem as TestItem)


## Pose l'objet sur ce qui se trouve sous lui (rayon vertical, couche monde) ; son origine est au
## centre du volume. La surface de pose du corps touché, s'il en a une, devient sa surface porteuse.
func _drop_to_floor(item: TestItem) -> void:
	var top: Vector3 = item.global_position + Vector3.UP
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 4.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	item.global_position = (hit["position"] as Vector3) + Vector3.UP * item.item_data.height * 0.5
	var surface: PlacementSurface = PlacementSurface.of_body(hit["collider"])
	if surface != null:
		item.on_placed(surface)
