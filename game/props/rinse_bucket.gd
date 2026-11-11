class_name RinseBucket
extends StaticBody3D
## Seau de rinçage minimal (couche 3) : interagir en tenant un outil remet sa salissure à 0.
## Geste court, sans animation ni eau simulée (provisoire).


func _ready() -> void:
	($Interactable as Interactable).interacted.connect(_on_interacted)


func _on_interacted(player: Node) -> void:
	var controller: ToolController = player.get_node_or_null(^"ToolController") as ToolController
	if controller != null:
		controller.rinse()
