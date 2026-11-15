class_name HangPose
extends RefCounted
## Pose « accroché » d'un objet contre une surface murale (Direction 2026-11-15, provisoire), fonctions pures.
## L'objet est posé face arrière contre le mur : ancrage au centre de la face arrière de sa boîte englobante
## (point du mur), orientation imposée par la normale du mur. Axes de l'objet accroché : Y local = normale
## (face avant vers la pièce), Z local = vers le bas, X local = le long du mur. La forme de pose est PoseShape
## (ACCROCHE) : largeur footprint.x, épaisseur height, hauteur footprint.y.


## Lacet (autour de Y) de la boîte de pose et de l'objet tombé à plat : son axe Z local suit la normale.
static func yaw_of(normal: Vector3) -> float:
	return atan2(normal.x, normal.z)


## Orientation de l'objet accroché pour une normale de mur horizontale.
static func basis_for(normal: Vector3) -> Basis:
	var y_axis: Vector3 = Vector3(normal.x, 0.0, normal.z).normalized()
	var z_axis: Vector3 = Vector3.DOWN
	return Basis(y_axis.cross(z_axis), y_axis, z_axis)


## Transform de l'objet accroché : l'origine est le centre de la boîte englobante, à demi-épaisseur du point d'ancrage.
static func transform_for(anchor: Vector3, normal: Vector3, data: ItemData) -> Transform3D:
	return Transform3D(basis_for(normal), anchor + normal * data.height * 0.5)


## Centre de pose (bas de la boîte de pose, convention de PlacementLanding) de la boîte accrochée au point d'ancrage.
static func box_center(anchor: Vector3, normal: Vector3, data: ItemData) -> Vector3:
	var shape: PoseShape = PoseShape.of(data, ItemData.Posture.ACCROCHE)
	return anchor + normal * shape.footprint.y * 0.5 - Vector3.UP * shape.height * 0.5


## Point de départ d'une chute : l'objet tombe à plat, dégagé du mur d'une marge, à la hauteur où il pendait.
static func fall_start(anchor: Vector3, normal: Vector3, data: ItemData, margin: float) -> Vector3:
	var shape: PoseShape = PoseShape.of(data, ItemData.Posture.ACCROCHE)
	var start: Vector3 = anchor + normal * (data.footprint.y * 0.5 + margin)
	start.y = anchor.y - shape.height * 0.5
	return start
