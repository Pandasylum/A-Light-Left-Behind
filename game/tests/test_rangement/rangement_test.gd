extends Node3D
## Scène de vérification NON OFFICIELLE du rangement : instancie greybox.tscn sans la modifier,
## ajoute des zones de test (palette ; moitié gauche de la table ; moitié droite de la table,
## SMALL seulement ; zone qui recoupe le sol autour du meuble bas) et un objet déjà posé sur la
## palette au chargement. Un Label par objet : rangé / non rangé. Zones montrées par un volume translucide.

@export var stored_color: Color = Color(0.45, 0.9, 0.5)
@export var not_stored_color: Color = Color(0.8, 0.8, 0.8)
@export var zone_color: Color = Color(0.3, 0.7, 1.0, 0.15)

var _labels: Dictionary[int, Label] = {}

@onready var _service: StorageService = $StorageService
@onready var _states: VBoxContainer = $Hud/States


func _ready() -> void:
	_service.stored_changed.connect(_show_state)
	for item: TestItem in StorageService.items_under(self):
		var label: Label = Label.new()
		label.name = String(item.name)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_states.add_child(label)
		_labels[item.get_instance_id()] = label
		_show_state(item, _service.is_stored(item))
	for zone: Node in $Zones.get_children():
		_show_volume(zone)


## Texte du Label d'un objet (vide si l'objet n'en a pas).
func state_text(item: TestItem) -> String:
	var label: Label = _labels.get(item.get_instance_id())
	return label.text if label != null else ""


func _show_state(item: TestItem, stored: bool) -> void:
	var label: Label = _labels.get(item.get_instance_id())
	if label == null:
		return
	label.text = "%s : %s" % [label.name, "rangé" if stored else "non rangé"]
	label.modulate = stored_color if stored else not_stored_color


func _show_volume(zone: Node) -> void:
	for child: Node in zone.get_children():
		var shape: CollisionShape3D = child as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D:
			continue
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = (shape.shape as BoxShape3D).size
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = zone_color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = material
		shape.add_child(visual)
