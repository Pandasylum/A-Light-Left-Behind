class_name ProgressIndicator
extends CanvasLayer
## Indicateur provisoire de progression de la pièce (aucune décision d'art) : pourcentage, « surfaces
## a/b », « objets rangés c/d » et la marque « restaurée » une fois le verrou posé. Libellés par
## tr(clé) (clé brute tant qu'aucune table de traduction n'existe). Neutre (pourcentage « en attente »,
## rien d'autre) tant que RoomProgress n'a pas fini le chargement. Une ligne d'axe inactif est masquée.

## RoomProgress affiché (relié à l'entrée dans l'arbre si le chemin est renseigné).
@export var progress_path: NodePath

var progress: RoomProgress

@onready var _percent: Label = $Panel/Rows/Percent
@onready var _surfaces: Label = $Panel/Rows/Surfaces
@onready var _items: Label = $Panel/Rows/Items
@onready var _restored: Label = $Panel/Rows/Restored


func _ready() -> void:
	if not progress_path.is_empty():
		bind(get_node_or_null(progress_path) as RoomProgress)
	else:
		refresh()


## Relie l'indicateur à une progression (null : neutre) et le met à jour.
func bind(room_progress: RoomProgress) -> void:
	if progress != null and progress.changed.is_connected(refresh):
		progress.changed.disconnect(refresh)
	progress = room_progress
	if progress != null:
		progress.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var shown: bool = progress != null and progress.is_evaluated()
	_surfaces.visible = shown and progress.result().cleaning_active
	_items.visible = shown and progress.result().storing_active
	_restored.visible = shown and progress.is_restored()
	if not shown:
		_percent.text = tr("progress.pending")
		return
	_percent.text = "%s %d %%" % [tr("progress.room"), progress.percent()]
	var cleaning: Vector2i = progress.cleaning_counts()
	var storing: Vector2i = progress.storing_counts()
	_surfaces.text = "%s %d/%d" % [tr("progress.surfaces"), cleaning.x, cleaning.y]
	_items.text = "%s %d/%d" % [tr("progress.stored"), storing.x, storing.y]
	_restored.text = tr("progress.restored")
