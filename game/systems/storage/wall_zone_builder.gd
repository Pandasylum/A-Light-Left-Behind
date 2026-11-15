class_name WallZoneBuilder
extends RefCounted
## Découpe des murs d'une pièce en zones murales « accroché » (Direction 2026-11-15, option A, provisoire).
## Une zone (StorageZone + PlacementSurface murale) par pan de mur libre : intervalle du mur compris entre les coins
## intérieurs, privé des retraits (étagères murales, portes, ouvertures, faces à nettoyer) élargis d'une marge.
## Un pan ne passe jamais un coin. Toutes les valeurs viennent de WallZoneRules. Aucune règle de collision :
## le retrait supprime la zone, un objet n'est donc jamais accroché là (le recouvrement de deux tableaux reste
## refusé par PlacementLanding, inchangé). Repère : celui de la pièce (parent des zones), sol à y = 0.

const EPSILON: float = 0.0001
const NAME_PREFIX: String = "ZoneMurale"

## Plan intérieur d'un mur : point (centre de la face, y = 0), normale horizontale vers la pièce, tangente = axe X local
## de ses zones, étendue libre le long du mur (coin à coin), retraits et pans (abscisses curvilignes le long de la tangente).
class Wall extends RefCounted:
	var name: String = ""
	var point: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.BACK
	var tangent: Vector3 = Vector3.RIGHT
	var span: Vector2 = Vector2.ZERO
	var cuts: Array[Vector2] = []
	var pans: Array[Vector2] = []


## Plan intérieur d'un corps de mur (BoxShape3D, axe fin horizontal), exprimé dans le repère `to_room` ; la normale est
## orientée vers `room_center`. L'étendue n'est pas posée ici (voir fit_spans).
static func wall_of(body: StaticBody3D, to_room: Transform3D, room_center: Vector3) -> Wall:
	var shape_node: CollisionShape3D = null
	for child: Node in body.get_children():
		var candidate: CollisionShape3D = child as CollisionShape3D
		if candidate != null and candidate.shape is BoxShape3D:
			shape_node = candidate
			break
	if shape_node == null:
		return null
	var size: Vector3 = (shape_node.shape as BoxShape3D).size
	var xform: Transform3D = to_room * shape_node.global_transform
	var axis: Vector3 = xform.basis.x if size.x < size.z else xform.basis.z
	var normal: Vector3 = Vector3(axis.x, 0.0, axis.z).normalized()
	if (room_center - xform.origin).dot(normal) < 0.0:
		normal = -normal
	var wall: Wall = Wall.new()
	wall.name = body.name
	wall.normal = normal
	wall.tangent = Vector3(normal.z, 0.0, -normal.x)
	wall.point = Vector3(xform.origin.x, 0.0, xform.origin.z) + normal * minf(size.x, size.z) * 0.5
	return wall


## Étendue libre de chaque mur : d'un coin intérieur à l'autre, soit les plans des murs qui lui sont perpendiculaires.
static func fit_spans(walls: Array[Wall]) -> void:
	for wall: Wall in walls:
		var low: float = INF
		var high: float = -INF
		for other: Wall in walls:
			if absf(other.normal.dot(wall.normal)) > 0.01:
				continue
			var s: float = (other.point - wall.point).dot(wall.tangent)
			low = minf(low, s)
			high = maxf(high, s)
		wall.span = Vector2(low, high) if low < high else Vector2.ZERO


## Boîte englobante, dans le repère `to_room`, des volumes BoxShape3D d'un corps (étagère murale, ouverture) ; boîte
## vide (taille nulle) si le corps n'en a pas.
static func box_of_body(body: Node3D, to_room: Transform3D) -> AABB:
	var total: AABB = AABB()
	var found: bool = false
	for child: Node in body.get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node == null or not shape_node.shape is BoxShape3D:
			continue
		var size: Vector3 = (shape_node.shape as BoxShape3D).size
		var box: AABB = (to_room * shape_node.global_transform) * AABB(-size * 0.5, size)
		total = box if not found else total.merge(box)
		found = true
	return total


## Retrait d'une boîte monde (étagère murale, ouverture, face à nettoyer) sur ce mur : vide si la boîte n'est pas à
## `reach` ou moins du plan du mur (distance le long de la normale, une boîte qui traverse le plan compte).
static func cut_of_box(wall: Wall, bounds: AABB, reach: float) -> Array[Vector2]:
	var cut: Array[Vector2] = []
	var near: float = INF
	var far: float = -INF
	var low: float = INF
	var high: float = -INF
	for i: int in 8:
		var offset: Vector3 = bounds.get_endpoint(i) - wall.point
		near = minf(near, offset.dot(wall.normal))
		far = maxf(far, offset.dot(wall.normal))
		low = minf(low, offset.dot(wall.tangent))
		high = maxf(high, offset.dot(wall.tangent))
	if near <= reach and far >= -reach:
		cut.append(Vector2(low, high))
	return cut


## Retrait d'une porte (repère ponctuel) sur ce mur : ± `half_width` autour de son repère, vide si elle n'est pas à
## `reach` ou moins du plan du mur.
static func cut_of_door(wall: Wall, door: Vector3, half_width: float, reach: float) -> Array[Vector2]:
	var cut: Array[Vector2] = []
	var offset: Vector3 = door - wall.point
	if absf(offset.dot(wall.normal)) <= reach:
		var s: float = offset.dot(wall.tangent)
		cut.append(Vector2(s - half_width, s + half_width))
	return cut


## Pans libres : `span` privée des retraits, chacun élargi de `margin` de chaque côté (fonction pure).
## Les pans sont rendus dans l'ordre croissant ; un pan de longueur nulle est écarté.
static func pans_of(span: Vector2, cuts: Array[Vector2], margin: float) -> Array[Vector2]:
	var widened: Array[Vector2] = []
	for cut: Vector2 in cuts:
		widened.append(Vector2(cut.x - margin, cut.y + margin))
	widened.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var pans: Array[Vector2] = []
	var cursor: float = span.x
	for cut: Vector2 in widened:
		if cut.y <= cursor:
			continue
		if cut.x > span.y:
			break
		if cut.x - cursor > EPSILON:
			pans.append(Vector2(cursor, cut.x))
		cursor = maxf(cursor, cut.y)
	if span.y - cursor > EPSILON:
		pans.append(Vector2(cursor, span.y))
	return pans


## Calcule retraits et pans de chaque mur. `boxes` : boîtes monde des retraits (étagères, ouvertures, faces à
## nettoyer) ; `doors` : repères monde des portes (retrait de ± rules.door_half_width).
static func plan(walls: Array[Wall], boxes: Array[AABB], doors: Array[Vector3], rules: WallZoneRules) -> void:
	fit_spans(walls)
	for wall: Wall in walls:
		wall.cuts = []
		for bounds: AABB in boxes:
			wall.cuts.append_array(cut_of_box(wall, bounds, rules.cut_reach))
		for door: Vector3 in doors:
			wall.cuts.append_array(cut_of_door(wall, door, rules.door_half_width, rules.cut_reach))
		wall.pans = pans_of(wall.span, wall.cuts, rules.cut_margin)


## Crée une zone par pan sous `parent` (repère de la pièce) : StorageZone (zone_data) orientée selon la normale du mur,
## volume largeur du pan × plage de hauteur × épaisseur centré sur le plan du mur, et PlacementSurface murale enfant.
## Nom : ZoneMurale<mur><numéro du pan>, stable d'un lancement à l'autre (chemin de sauvegarde des objets accrochés).
static func build(parent: Node3D, walls: Array[Wall], rules: WallZoneRules, zone_data: ZoneData) -> Array[StorageZone]:
	var zones: Array[StorageZone] = []
	var middle: float = (rules.height_min + rules.height_max) * 0.5
	for wall: Wall in walls:
		for index: int in wall.pans.size():
			var pan: Vector2 = wall.pans[index]
			var zone: StorageZone = StorageZone.new()
			zone.name = "%s%s%d" % [NAME_PREFIX, wall.name, index]
			zone.zone_data = zone_data
			var shape: CollisionShape3D = CollisionShape3D.new()
			shape.name = "CollisionShape3D"
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(pan.y - pan.x, rules.height_span(), rules.thickness)
			shape.shape = box
			zone.add_child(shape)
			var surface: PlacementSurface = PlacementSurface.new()
			surface.name = "PlacementSurface"
			surface.size = Vector2(pan.y - pan.x, rules.height_span())
			surface.is_floor = false
			surface.is_wall = true
			surface.zone = zone
			zone.add_child(surface)
			zone.transform = Transform3D(Basis(Vector3.UP, atan2(wall.normal.x, wall.normal.z)),
					wall.point + wall.tangent * (pan.x + pan.y) * 0.5 + Vector3.UP * middle)
			parent.add_child(zone)
			zones.append(zone)
	return zones
