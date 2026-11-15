class_name TestItem
extends StaticBody3D
## Objet de test ramassable. Le cube suit l'ItemData (x, z = emprise ; hauteur = height).

## Émis après une pose (chute comprise) ou une reprise : la surface porteuse a changé (écouté par le rangement).
signal support_changed(item: TestItem)

@export var item_data: ItemData
## Réglages de placement (épaisseur minimale du collider). Vide : valeurs par défaut de PlacementRules.
@export var placement_rules: PlacementRules = null

## Surface de pose porteuse (null tant que l'objet n'est pas posé ; vidée à la reprise).
var support_surface: PlacementSurface = null
## Objets posés sur le dessus de celui-ci (mis à jour à la pose et à la reprise).
var loads: Array[Node3D] = []
## Identifiant stable pour la sauvegarde de la disposition : chemin d'origine depuis la racine de la
## pièce (comme surface_id des CleaningSurface), attribué une fois par RoomLayout. Vide = non suivi.
var layout_id: String = ""
## Vrai quand la place de l'objet vient de la sauvegarde : au chargement, sa surface porteuse n'est
## plus cherchée (ni par le StorageService, ni par la pose initiale de la scène).
var placement_restored: bool = false


func _ready() -> void:
	if item_data == null:
		return
	var size: Vector3 = cube_size(item_data)
	# Boîte visuelle de test, sauf si la scène fournit déjà son visuel (nœud « Visuel », ex. un .glb).
	var box_node: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if box_node != null and not has_node("Visuel"):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		box_node.mesh = mesh
	# Collider : épaisseur minimale en donnée (PlacementRules). Un objet plus mince garde son visuel ; son collider
	# est épaissi vers l'avant (+Y local), face arrière et dessous inchangés.
	var thickness: float = collider_thickness(item_data, placement_rules)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(size.x, thickness, size.z)
	var collision: CollisionShape3D = $CollisionShape3D
	collision.shape = shape
	collision.position = Vector3(0.0, (thickness - item_data.height) * 0.5, 0.0)
	# Dessus de l'objet : surface de pose (suit la rotation du corps), emprise = taille de l'ItemData, à la face
	# supérieure du collider.
	var top: PlacementSurface = $PlacementSurface
	top.position = Vector3(0.0, thickness - item_data.height * 0.5, 0.0)
	top.size = item_data.footprint
	top.is_declared_support = item_data.provides_support


static func cube_size(data: ItemData) -> Vector3:
	return Vector3(data.footprint.x, data.height, data.footprint.y)


## Épaisseur du collider : hauteur de l'objet, au moins `collider_min_thickness` (rules vide : valeurs par défaut).
static func collider_thickness(data: ItemData, rules: PlacementRules = null) -> float:
	var active: PlacementRules = rules if rules != null else PlacementRules.new()
	return maxf(data.height, active.collider_min_thickness)


## Vrai si au moins un objet est posé dessus (l'objet ne peut alors pas être pris).
func has_loads() -> bool:
	for load_body: Node3D in loads:
		if is_instance_valid(load_body):
			return true
	return false


## Appelé à la pose : mémorise la surface porteuse et s'ajoute aux charges du porteur (dessus d'un objet).
func on_placed(surface: PlacementSurface) -> void:
	support_surface = surface
	var carrier: Node = surface.get_parent()
	if carrier != null and carrier.get(&"loads") != null and not (carrier.get(&"loads") as Array).has(self):
		(carrier.get(&"loads") as Array).append(self)
	support_changed.emit(self)


## Appelé à la reprise : plus de surface porteuse, retiré des charges du porteur.
func on_picked_up() -> void:
	_leave_carrier()
	support_surface = null
	support_changed.emit(self)


## Chargement : surface porteuse sauvegardée, par le chemin de la pose (on_placed), sans contrôle de
## pose ni chute. L'objet est déjà à sa position ; il quitte d'abord, sans signal, un porteur précédent.
func restore_support(surface: PlacementSurface) -> void:
	_leave_carrier()
	placement_restored = true
	on_placed(surface)


## Se retire des charges du porteur actuel (dessus d'un objet), s'il y en a un.
func _leave_carrier() -> void:
	if not is_instance_valid(support_surface):
		return
	var carrier: Node = support_surface.get_parent()
	if carrier != null and carrier.get(&"loads") != null:
		(carrier.get(&"loads") as Array).erase(self)


## Vrai si l'objet est posé sur une surface qui n'est pas le sol et qui est un support déclaré
## (installation fixe ou meuble libre). Utilisé par le rangement (StorageService).
func rests_on_declared_support() -> bool:
	return support_surface != null and not support_surface.is_floor and support_surface.is_declared_support
