class_name PoseShape
extends RefCounted
## Forme de pose d'un objet dans une posture : emprise sur la surface (x = largeur, y = profondeur) et hauteur,
## en mètres. Dérivée de la forme à plat de l'ItemData (footprint, height), qui reste la référence.
## ACCROCHE : largeur = footprint.x, hauteur = footprint.y, profondeur = height (Direction 2026-11-15, provisoire).

var footprint: Vector2 = Vector2.ONE
var height: float = 1.0


static func of(data: ItemData, posture: ItemData.Posture) -> PoseShape:
	var shape: PoseShape = PoseShape.new()
	if posture == ItemData.Posture.ACCROCHE:
		shape.footprint = Vector2(data.footprint.x, data.height)
		shape.height = data.footprint.y
	else:
		shape.footprint = data.footprint
		shape.height = data.height
	return shape
