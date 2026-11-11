class_name Bucket
extends TestItem
## Seau de rinçage : objet libre MEDIUM (prise, port et pose : règles de TestItem), exclu du 100 %
## (son ItemData ne suit aucun axe). Le rinçage passe par ToolController.rinse_at (action
## rinse_tool, seau posé), jamais par la prise. Forme provisoire : cylindre aux dimensions de l'ItemData.


func _ready() -> void:
	super()
	if item_data == null:
		return
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = minf(item_data.footprint.x, item_data.footprint.y) * 0.5
	mesh.bottom_radius = mesh.top_radius * 0.8
	mesh.height = item_data.height
	($MeshInstance3D as MeshInstance3D).mesh = mesh
