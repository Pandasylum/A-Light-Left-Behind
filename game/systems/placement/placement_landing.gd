class_name PlacementLanding
extends RefCounted
## Évaluation d'une pose et chute verticale déterministe (règles PROVISOIRES, GDD §15 point 18 ouvert).
## Fonctions statiques, indépendantes du nœud PlacementController : testables avec de vrais corps physiques.
## La chute est une requête de forme (boîte de l'objet) vers le bas, en ignorant le corps du dernier support.

const QUERY_MASK: int = 1 | 2 | 4 ## couches 1 (monde), 2 (joueur), 3 (objets) : contrôle des collisions
const FALL_MASK: int = 1 | 4 ## couches 1 et 3 : ce sur quoi l'objet peut atterrir
const SHRINK: float = 0.001 ## m : boîte de requête réduite
const LIFT: float = 0.002 ## m : boîte de requête soulevée (ne touche pas la surface porteuse)
const PROBE: float = 0.01 ## m : descente supplémentaire de la boîte (après la fraction de contact) pour identifier le corps porteur
const FALL_DISTANCE: float = 30.0 ## m : portée maximale d'une chute
const MAX_ITERATIONS: int = 8 ## atterrissages instables successifs au maximum

## Verdict d'une pose sur une surface donnée.
enum Verdict { OK, UNSTABLE, BLOCKED, CANNOT_STACK }

## Résultat d'une chute : si ok, centre de pose (monde, sur la face supérieure) et surface d'arrivée.
class Landing extends RefCounted:
	var ok: bool = false
	var center: Vector3 = Vector3.ZERO
	var surface: PlacementSurface = null
	var iterations: int = 0 ## atterrissages évalués


## ItemData de l'objet qui porte la surface (dessus d'un objet), null pour le sol ou un support déclaré.
static func carrier_data(surface: PlacementSurface) -> ItemData:
	var body: Node = surface.get_parent()
	return body.get("item_data") as ItemData if body != null else null


## Verdict d'une pose : empilement autorisé, puis collisions, puis couverture.
static func evaluate_pose(space: PhysicsDirectSpaceState3D, check: PlacementCheck, data: ItemData, yaw: float,
		center: Vector3, surface: PlacementSurface, exclude: Array[RID] = []) -> Verdict:
	var below: ItemData = carrier_data(surface)
	if below != null and not PlacementCheck.can_stack(data.category, below.category):
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


## Chute verticale depuis une pose instable : l'objet quitte `origin_body` (support d'origine, ignoré) et
## tombe droit ; chaque atterrissage est contrôlé comme une pose (empilement, collisions, couverture).
## Instable : il retombe, en ignorant le corps du dernier support (MAX_ITERATIONS au plus). Collision ou
## empilement interdit, vide, ou itérations épuisées : refus (ok = false). `held` : corps de l'objet (ignoré).
static func resolve(space: PhysicsDirectSpaceState3D, check: PlacementCheck, data: ItemData, yaw: float,
		start: Vector3, origin_body: RID, held: RID) -> Landing:
	var landing: Landing = Landing.new()
	var from: Vector3 = start
	var last_support: RID = origin_body
	for i: int in MAX_ITERATIONS:
		landing.iterations = i + 1
		var exclude: Array[RID] = [held, last_support]
		var surface: PlacementSurface = find_landing_surface(space, data, yaw, from, exclude)
		if surface == null:
			return landing
		var center: Vector3 = Vector3(from.x, surface.top_y(), from.z)
		var verdict: Verdict = evaluate_pose(space, check, data, yaw, center, surface, exclude)
		if verdict == Verdict.OK:
			landing.ok = true
			landing.center = center
			landing.surface = surface
			return landing
		if verdict != Verdict.UNSTABLE:
			return landing
		from = center
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
