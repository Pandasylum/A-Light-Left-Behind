class_name StorageRules
extends RefCounted
## Règles de rangement (GDD §5), logique pure sans scène.
## Rangé = posé directement sur un support déclaré non-sol ET dans une zone qui accepte la catégorie.
## Zone souple : aucune position ni orientation imposée, seul le point de référence compte.


## Vrai si la zone accepte cette catégorie (zone absente ou catégorie FIXED : jamais).
static func accepts(zone: ZoneData, category: ItemData.Category) -> bool:
	if zone == null or category == ItemData.Category.FIXED:
		return false
	return zone.accepted_categories.has(category)


## Point de référence d'un objet : centre de son emprise, au niveau de sa base
## (`origin` = centre du volume, `up` = axe vertical de l'objet).
static func footprint_center(origin: Vector3, up: Vector3, height: float) -> Vector3:
	return origin - up * height * 0.5


## Vrai si le point, exprimé dans le repère d'une boîte centrée à l'origine, est dans la boîte (bords compris).
static func box_contains(box_size: Vector3, local_point: Vector3) -> bool:
	var half: Vector3 = box_size * 0.5
	return absf(local_point.x) <= half.x and absf(local_point.y) <= half.y and absf(local_point.z) <= half.z


## Décision. `on_declared_support` = TestItem.rests_on_declared_support() (faux pour un objet tenu, au sol
## ou sur le dessus d'un objet ordinaire) ; `zones` = règles des zones dont le volume contient le point
## de référence de l'objet.
static func is_stored(on_declared_support: bool, category: ItemData.Category, zones: Array[ZoneData]) -> bool:
	if not on_declared_support:
		return false
	for zone: ZoneData in zones:
		if accepts(zone, category):
			return true
	return false
