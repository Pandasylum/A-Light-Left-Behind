class_name PlacementLanding
extends RefCounted
## Évaluation d'une pose et chute verticale déterministe (règles PROVISOIRES, GDD §15 point 18 ouvert).
## Fonctions statiques, indépendantes du nœud PlacementController : testables avec de vrais corps physiques.
## La chute est une requête de forme (boîte de l'objet) vers le bas, en ignorant le corps du dernier support ;
## l'objet est ensuite dégagé horizontalement de ce support (push_out) avant le contrôle de la pose.

const QUERY_MASK: int = 1 | 2 | 4 ## couches 1 (monde), 2 (joueur), 3 (objets) : contrôle des collisions
const FALL_MASK: int = 1 | 4 ## couches 1 et 3 : ce sur quoi l'objet peut atterrir
const SHRINK: float = 0.001 ## m : boîte de requête réduite
const LIFT: float = 0.002 ## m : boîte de requête soulevée (ne touche pas la surface porteuse)
const PROBE: float = 0.01 ## m : descente supplémentaire de la boîte (après la fraction de contact) pour identifier le corps porteur
const FALL_DISTANCE: float = 30.0 ## m : portée maximale d'une chute
const MAX_ITERATIONS: int = 8 ## atterrissages instables successifs au maximum
const TIE_EPSILON: float = 1e-4 ## m : deux décalages à moins de cet écart sont à égalité (ordre fixe)
const OVERLAP_EPSILON: float = 0.001 ## m : recouvrement vertical minimal avec le support quitté

## Verdict d'une pose sur une surface donnée.
enum Verdict { OK, UNSTABLE, BLOCKED, CANNOT_STACK }

## Rectangle orienté dans le plan XZ (lacet autour de Y, convention Basis(Vector3.UP, yaw)). Vector2 = (x, z).
class OrientedRect extends RefCounted:
	var center: Vector2 = Vector2.ZERO
	var size: Vector2 = Vector2.ONE
	var yaw: float = 0.0

	static func make(rect_center: Vector2, rect_size: Vector2, rect_yaw: float) -> OrientedRect:
		var r: OrientedRect = OrientedRect.new()
		r.center = rect_center
		r.size = rect_size
		r.yaw = rect_yaw
		return r

	## Axe local X, puis local Z, exprimés en (x, z) monde.
	func axis(index: int) -> Vector2:
		return Vector2(cos(yaw), -sin(yaw)) if index == 0 else Vector2(sin(yaw), cos(yaw))

	## Demi-étendue de la projection du rectangle sur l'axe unitaire `u`.
	func radius_on(u: Vector2) -> float:
		return absf(axis(0).dot(u)) * size.x * 0.5 + absf(axis(1).dot(u)) * size.y * 0.5

	static func from_surface(surface: PlacementSurface) -> OrientedRect:
		var p: Vector3 = surface.global_position
		return make(Vector2(p.x, p.z), surface.size, surface.global_rotation.y)


## Résultat d'une chute : si ok, centre de pose (monde, sur la face supérieure) et surface d'arrivée.
class Landing extends RefCounted:
	var ok: bool = false
	var center: Vector3 = Vector3.ZERO
	var surface: PlacementSurface = null
	var iterations: int = 0 ## atterrissages évalués


## Décalages horizontaux (x, z) qui dégagent `body` de `support` : séparation sur les axes des deux rectangles (SAT),
## plus `margin` (marge au bord, PlacementRules). Chaque axe donne un décalage de chaque côté. Triés par distance
## croissante ; à égalité (écart < TIE_EPSILON) l'ordre de génération est conservé (axes de l'objet puis du support,
## X puis Z, sens + puis -) : résultat déterministe. Vide si les rectangles ne se recouvrent pas (ou se touchent).
static func push_out(body: OrientedRect, support: OrientedRect, margin: float) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var dists: Array[float] = []
	var delta: Vector2 = body.center - support.center
	var candidates: Array[Vector2] = []
	for i: int in 4:
		var u: Vector2 = body.axis(i) if i < 2 else support.axis(i - 2)
		var reach: float = body.radius_on(u) + support.radius_on(u)
		var along: float = delta.dot(u)
		if reach - absf(along) <= TIE_EPSILON:
			return offsets ## axe séparateur (ou simple contact) : aucun recouvrement
		# Côté +u : l'objet doit atteindre along = reach + margin ; côté -u : along = -(reach + margin).
		candidates.append(u * (reach + margin - along))
		candidates.append(-u * (reach + margin + along))
	for c: Vector2 in candidates:
		var d: float = c.length()
		var at: int = offsets.size()
		for k: int in offsets.size():
			if dists[k] > d + TIE_EPSILON:
				at = k
				break
		var duplicate: bool = false
		for k: int in offsets.size():
			if offsets[k].distance_to(c) < TIE_EPSILON:
				duplicate = true
				break
		if duplicate:
			continue
		offsets.insert(at, c)
		dists.insert(at, d)
	return offsets


## Surface du corps physique `body` (RID), ou null.
static func surface_of_rid(body: RID) -> PlacementSurface:
	if not body.is_valid():
		return null
	var object: Object = instance_from_id(PhysicsServer3D.body_get_object_instance_id(body))
	return PlacementSurface.of_body(object)


## Vrai si une boîte posée en `center` (monde, bas de l'objet) recouvre le volume du support : recouvrement en XZ
## (emprise avec son lacet, surface avec le sien) et le bas de l'objet est sous le dessus du support.
static func overlaps_support(data: ItemData, yaw: float, center: Vector3, support: PlacementSurface) -> bool:
	if center.y >= support.top_y() - OVERLAP_EPSILON:
		return false
	var body: OrientedRect = OrientedRect.make(Vector2(center.x, center.z), data.footprint, yaw)
	var offsets: Array[Vector2] = push_out(body, OrientedRect.from_surface(support), 0.0)
	return not offsets.is_empty()


## ItemData de l'objet qui porte la surface (dessus d'un objet), null pour le sol ou un support déclaré.
static func carrier_data(surface: PlacementSurface) -> ItemData:
	var body: Node = surface.get_parent()
	return body.get("item_data") as ItemData if body != null else null


## Verdict d'une pose : empilement autorisé, puis collisions, puis couverture.
static func evaluate_pose(space: PhysicsDirectSpaceState3D, check: PlacementCheck, data: ItemData, yaw: float,
		center: Vector3, surface: PlacementSurface, exclude: Array[RID] = []) -> Verdict:
	var below: ItemData = carrier_data(surface)
	if below != null and (not below.can_support_items or not PlacementCheck.can_stack(data.category, below.category)):
		return Verdict.CANNOT_STACK
	if is_blocked(space, data, yaw, center, exclude):
		return Verdict.BLOCKED
	if check.evaluate(data, yaw, center, surface).status != PlacementCheck.Status.OK:
		return Verdict.UNSTABLE
	return Verdict.OK


## Vrai si une boîte de l'emprise de l'objet, à ce lacet et centre de pose, touche un corps des couches 1, 2 ou 3
## (hors `exclude`). Boîte réduite et soulevée de quelques mm pour ne pas détecter la surface porteuse.
static func is_blocked(space: PhysicsDirectSpaceState3D, data: ItemData, yaw: float, center: Vector3,
		exclude: Array[RID] = []) -> bool:
	var query: PhysicsShapeQueryParameters3D = _box_query(data, yaw, center, QUERY_MASK, exclude)
	return not space.intersect_shape(query, 1).is_empty()


## Surface sur laquelle l'objet atterrit en tombant droit depuis `center` (hors `exclude`), ou null s'il
## ne rencontre rien (vide) ou démarre en collision. La boîte tombe jusqu'au contact (cast_motion), puis le corps
## porteur est identifié par une sonde au point de contact ; le plus haut gagne.
static func find_landing_surface(space: PhysicsDirectSpaceState3D, data: ItemData, yaw: float, center: Vector3,
		exclude: Array[RID] = []) -> PlacementSurface:
	var query: PhysicsShapeQueryParameters3D = _box_query(data, yaw, center, FALL_MASK, exclude)
	query.motion = Vector3.DOWN * FALL_DISTANCE
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() < 2 or fractions[0] >= 1.0 or fractions[1] <= 0.0:
		return null
	query.transform.origin += Vector3.DOWN * (FALL_DISTANCE * fractions[1] + PROBE)
	query.motion = Vector3.ZERO
	var best: PlacementSurface = null
	for hit: Dictionary in space.intersect_shape(query, 8):
		var candidate: PlacementSurface = PlacementSurface.of_body(hit.get("collider"))
		if candidate != null and (best == null or candidate.top_y() > best.top_y()):
			best = candidate
	return best


## Chute verticale depuis une pose instable : l'objet quitte `origin_body` (support d'origine) et tombe droit
## en ignorant le corps du dernier support. Chaque itération : chute verticale, dégagement horizontal du support
## quitté s'il est recouvert (push_out, décalages par distance croissante), puis contrôle comme une pose
## (empilement, collisions avec TOUS les corps hors l'objet, couverture). Premier décalage valide retenu ; sinon, le
## premier décalage seulement instable fait retomber l'objet (MAX_ITERATIONS au plus). Collision ou empilement
## interdit, vide, ou itérations épuisées : refus (ok = false). `held` : corps de l'objet (ignoré).
static func resolve(space: PhysicsDirectSpaceState3D, check: PlacementCheck, data: ItemData, yaw: float,
		start: Vector3, origin_body: RID, held: RID) -> Landing:
	var landing: Landing = Landing.new()
	var from: Vector3 = start
	var last_support: RID = origin_body
	for i: int in MAX_ITERATIONS:
		landing.iterations = i + 1
		var surface: PlacementSurface = find_landing_surface(space, data, yaw, from, [held, last_support])
		if surface == null:
			return landing
		var center: Vector3 = Vector3(from.x, surface.top_y(), from.z)
		var left: PlacementSurface = surface_of_rid(last_support)
		var offsets: Array[Vector2] = [Vector2.ZERO]
		if left != null and overlaps_support(data, yaw, center, left):
			offsets = push_out(OrientedRect.make(Vector2(center.x, center.z), data.footprint, yaw),
					OrientedRect.from_surface(left), check.rules.edge_margin)
		var fall_from: Vector3 = Vector3.INF
		for offset: Vector2 in offsets:
			var pose: Vector3 = center + Vector3(offset.x, 0.0, offset.y)
			var verdict: Verdict = evaluate_pose(space, check, data, yaw, pose, surface, [held])
			if verdict == Verdict.OK:
				landing.ok = true
				landing.center = pose
				landing.surface = surface
				return landing
			if verdict == Verdict.CANNOT_STACK:
				return landing
			if verdict == Verdict.UNSTABLE and fall_from == Vector3.INF:
				fall_from = pose
		if fall_from == Vector3.INF:
			return landing
		from = fall_from
		last_support = (surface.get_parent() as CollisionObject3D).get_rid()
	return landing


static func _box_query(data: ItemData, yaw: float, center: Vector3, mask: int, exclude: Array[RID]) -> PhysicsShapeQueryParameters3D:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(data.footprint.x - SHRINK, data.height - SHRINK, data.footprint.y - SHRINK)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP, yaw), center + Vector3.UP * (data.height * 0.5 + LIFT))
	query.collision_mask = mask
	query.exclude = exclude
	return query
