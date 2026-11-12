class_name CleaningSurface
extends Node
## Surface à nettoyer (GDD §4 et §15 point 30 ; TECHNICAL.md « Surfaces à nettoyer ») : zone
## reconnaissable par le joueur (face de mur, panneau de noyau, marche) qui regroupe plusieurs
## CleanableFace. Unité du futur 100 % de la pièce : chaque surface vaut 1.
## À NE PAS CONFONDRE avec PlacementSurface (surface de pose, rangement).
## Aire géométrique = somme des aires des faces ; aire sale restante = somme des
## remaining_dirty_area() des faces (calcul des faces inchangé).
## Terminée quand l'aire sale restante passe du dessus au dessous du seuil
## min(seuil_surface_max_m2, seuil_surface_fraction × aire géométrique) ; vérifié à chaque geste
## qui modifie une de ses faces (signal CleanableFace.stroked), jamais par polling.
## Aucun état sauvegardé : après un chargement, « terminée » se recalcule depuis les faces.

## Fin de surface : émis une seule fois, au passage sous le seuil pendant un geste, après que toutes
## les faces ont été terminées (reste effacé). Jamais émis pour
## une surface terminée d'office (propre ou déjà sous le seuil au départ) ni au chargement.
signal surface_finished(surface: CleaningSurface)

const GROUP: StringName = &"cleaning_surfaces"
const DEBUG_LOG: bool = true # temporaire, à retirer avec le retour visuel
## Voile de fin de surface (Direction 2026-11-12, valeurs provisoires) : shader d'Art en next_pass.
const VEIL_DURATION: float = 1.4
const VEIL_PEAK: float = 0.12

@export var faces: Array[CleanableFace] = []
## Constantes du seuil (CleaningParams par défaut si absent).
@export var params: CleaningParams

var _finished: bool = false
var veil_tween: Tween ## voile en cours (null sinon) ; un seul par surface
var _veil_materials: Dictionary = {} ## CleanableFace -> ShaderMaterial du voile


func _ready() -> void:
	add_to_group(GROUP)
	if params == null:
		params = CleaningParams.new()
	for face: CleanableFace in faces:
		if face == null:
			continue
		face.stroked.connect(_on_face_stroked)
		face.state_imported.connect(refresh)
		if not face.is_node_ready(): # face plus bas dans l'arbre : son aire sale n'est pas encore mesurée
			face.ready.connect(refresh, CONNECT_ONE_SHOT)
	refresh()


## Identifiant stable : chemin du nœud depuis la racine de la pièce (comme les faces).
func surface_id(room_root: Node) -> String:
	return String(room_root.get_path_to(self))


## Aire géométrique de la surface (m²) : somme des aires des faces.
func geometric_area() -> float:
	var total: float = 0.0
	for face: CleanableFace in faces:
		if is_instance_valid(face):
			total += face.face_area()
	return total


## Aire encore sale (m²) : somme des remaining_dirty_area() des faces.
func remaining_dirty_area() -> float:
	var total: float = 0.0
	for face: CleanableFace in faces:
		if is_instance_valid(face):
			total += face.remaining_dirty_area()
	return total


## Seuil de fin (m²).
func threshold() -> float:
	return minf(params.seuil_surface_max_m2, params.seuil_surface_fraction * geometric_area())


## Vrai si la surface est terminée (par un geste, d'office au départ ou d'après un chargement).
func is_finished() -> bool:
	return _finished


## Recalcule « terminée » depuis les faces, sans signal : état de départ et après un chargement
## (appelé sur CleanableFace.state_imported, donc après import_room).
func refresh() -> void:
	_finished = remaining_dirty_area() <= threshold()


func _on_face_stroked() -> void:
	if _finished or remaining_dirty_area() > threshold():
		return
	_finished = true
	var area_at_finish: float = remaining_dirty_area() # avant finish_now (log temporaire)
	# Le reste se finit automatiquement (GDD §4) : chaque face passe par la fin de geste existante,
	# état propre écrit de façon synchrone avant l'émission (l'Autosave exporte des faces propres).
	for face: CleanableFace in faces:
		if is_instance_valid(face):
			face.finish_now()
	if DEBUG_LOG:
		print("surface finie : ", get_path(), " aire=", area_at_finish, " seuil=", threshold())
	_play_veil()
	surface_finished.emit(self)


## Voile de fin : un seul tween linéaire écrit le même progress sur le matériau de chaque face
## (marche : dessus et contremarche synchronisés), puis next_pass est retiré. Une fin survenant
## pendant un voile en cours est ignorée (pas d'empilement).
func _play_veil() -> void:
	if (veil_tween != null and veil_tween.is_valid()) or not is_inside_tree():
		return
	var valid: Array[CleanableFace] = []
	for face: CleanableFace in faces:
		if is_instance_valid(face) and face.face_material() != null and face.world_projection() != null:
			valid.append(face)
	var sweep: Dictionary = FinSurfaceSweep.compute(valid)
	_veil_materials.clear()
	for face: CleanableFace in valid:
		var material: ShaderMaterial = FinSurfaceSweep.make_material(face, sweep[face], VEIL_PEAK)
		material.set_shader_parameter(&"edge_boost", 0.0)
		face.face_material().next_pass = material
		_veil_materials[face] = material
	veil_tween = create_tween()
	veil_tween.tween_method(_set_veil_progress, 0.0, 1.0, VEIL_DURATION)
	veil_tween.tween_callback(_end_veil)


func _set_veil_progress(value: float) -> void:
	for material: ShaderMaterial in _veil_materials.values():
		material.set_shader_parameter(&"progress", value)


func _end_veil() -> void:
	for key: Variant in _veil_materials:
		# Face libérée pendant le voile : rien à retirer.
		var face: CleanableFace = key as CleanableFace if is_instance_valid(key) else null
		if face != null and face.face_material() != null and face.face_material().next_pass == _veil_materials[key]:
			face.face_material().next_pass = null
	_veil_materials.clear()
	veil_tween = null


# --- Accès pour le futur 100 % de la pièce (le pourcentage n'est pas calculé ici) ---

## Surfaces sous room_root, dans l'ordre de l'arbre.
static func room_surfaces(room_root: Node) -> Array[CleaningSurface]:
	var out: Array[CleaningSurface] = []
	for node: Node in room_root.find_children("*", "CleaningSurface", true, false):
		out.append(node as CleaningSurface)
	return out


## Nombre de surfaces sous room_root.
static func count_in_room(room_root: Node) -> int:
	return room_surfaces(room_root).size()


## Nombre de surfaces terminées sous room_root (terminées d'office comprises).
static func finished_count_in_room(room_root: Node) -> int:
	var count: int = 0
	for surface: CleaningSurface in room_surfaces(room_root):
		if surface.is_finished():
			count += 1
	return count
