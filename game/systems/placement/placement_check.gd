class_name PlacementCheck
extends RefCounted
## Vérification pure du support d'un objet posé sur une PlacementSurface : l'empreinte est échantillonnée
## (grille régulière) ; un échantillon est soutenu s'il tombe dans la surface réduite de la marge au bord.
## Marge et couverture minimale viennent de PlacementRules (valeurs provisoires).

enum Status { OK, UNSUPPORTED, POSTURE_REFUSED }

const SAMPLES_PER_AXIS: int = 10

## Règle d'empilement PROVISOIRE (GDD §15 point 18 ouvert) : catégorie du dessus -> catégories du dessous
## acceptées. À modifier ici seulement. Une catégorie absente de la table ne se pose jamais sur un objet ;
## FIXED n'est jamais porté et ne porte pas.
const STACK_TABLE: Dictionary = {
	ItemData.Category.SMALL: [ItemData.Category.SMALL, ItemData.Category.MEDIUM, ItemData.Category.LARGE],
	ItemData.Category.MEDIUM: [ItemData.Category.LARGE],
	ItemData.Category.LARGE: [],
	ItemData.Category.FIXED: [],
}

## Résultat d'une vérification.
class Outcome extends RefCounted:
	var status: Status = Status.UNSUPPORTED
	var coverage: float = 0.0 ## part de l'empreinte soutenue, dans [0, 1]

var rules: PlacementRules


## Vrai si un objet de catégorie `top` peut être posé sur un objet de catégorie `bottom` (fonction pure).
static func can_stack(top: ItemData.Category, bottom: ItemData.Category) -> bool:
	var allowed: Array = STACK_TABLE.get(top, [])
	return allowed.has(bottom)


## Vrai si l'objet supporte la posture (fonction pure). Hors zone la posture est à plat ; une zone peut
## imposer ACCROCHE (ZoneData.postures_imposees).
static func supports_posture(data: ItemData, posture: ItemData.Posture) -> bool:
	return data.postures_supportees.has(posture)


func _init(placement_rules: PlacementRules = null) -> void:
	rules = placement_rules if placement_rules != null else PlacementRules.new()


## Cas général : objet, lacet monde, centre de pose (monde), surface (dans l'arbre). La posture est celle que la
## surface impose (zone) ; la forme de pose en est dérivée (PoseShape). Posture non supportée : POSTURE_REFUSED.
func evaluate(data: ItemData, yaw: float, center: Vector3, surface: PlacementSurface) -> Outcome:
	var posture: ItemData.Posture = surface.posture_for(data.category)
	if not supports_posture(data, posture):
		var refused: Outcome = Outcome.new()
		refused.status = Status.POSTURE_REFUSED
		return refused
	var shape: PoseShape = PoseShape.of(data, posture)
	return evaluate_local(shape.footprint, surface.to_local_yaw(yaw), surface.to_local_xz(center), surface.size)


## Version pure, en repère local de la surface : lacet local, centre (x, z) local, étendue de la surface.
func evaluate_local(footprint: Vector2, local_yaw: float, local_center: Vector2, surface_size: Vector2) -> Outcome:
	var outcome: Outcome = Outcome.new()
	var limit: Vector2 = surface_size * 0.5 - Vector2(rules.edge_margin, rules.edge_margin)
	var supported: int = 0
	if limit.x > 0.0 and limit.y > 0.0:
		var n: int = SAMPLES_PER_AXIS
		for ix: int in n:
			for iz: int in n:
				# Centre de cellule dans l'empreinte, puis rotation du lacet (Y) et translation.
				var sx: float = ((ix + 0.5) / n - 0.5) * footprint.x
				var sz: float = ((iz + 0.5) / n - 0.5) * footprint.y
				var p: Vector3 = Basis(Vector3.UP, local_yaw) * Vector3(sx, 0.0, sz)
				if absf(p.x + local_center.x) <= limit.x and absf(p.z + local_center.y) <= limit.y:
					supported += 1
	outcome.coverage = float(supported) / float(SAMPLES_PER_AXIS * SAMPLES_PER_AXIS)
	outcome.status = Status.OK if outcome.coverage >= rules.min_support_coverage else Status.UNSUPPORTED
	return outcome
