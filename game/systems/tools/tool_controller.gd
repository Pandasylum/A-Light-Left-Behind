class_name ToolController
extends Node
## Outils du joueur (enfant de Player) : emplacements dédiés (ToolSlots), au plus un outil en main,
## aucun par défaut. equip_tool sort/range l'outil ; toute prise d'objet le range. Tant que
## use_primary est maintenu avec un outil en main, tire un rayon depuis la caméra (centre de l'écran,
## ou curseur si la caméra est figée par lock_camera) et nettoie les CleanableFace touchées.
## Si le rayon touche d'abord un seau posé, le clic rince l'outil (une fois par appui) au lieu de nettoyer.
## Texte de debug et marqueur provisoires.

## Un outil vient d'être remis dans son emplacement (déclencheur de sauvegarde automatique).
signal tool_stowed
## L'action d'outil en cours (geste continu sur une surface) vient de finir : clic relâché, surface
## quittée, outil rangé ou cancel_action().
signal action_finished

const WORLD_LAYER: int = 1
const BUCKET_LAYER: int = 4 ## couche 3 (valeur de masque)
const MARKER_SIZE: float = 20.0 ## px, marqueur de visée provisoire
const DEBUG_SURFACES: bool = true # temporaire, à retirer avec l'indicateur de pièce
const DEBUG_AIM_REACH_M: float = 5.0 ## portée du rayon de visée du debug des surfaces
const DEBUG_FINISHED_SHOWN_S: float = 2.0 ## durée d'affichage de « Surface finie ! »

var slots: ToolSlots = ToolSlots.new()
## État de l'outil en main (null si aucun outil en main).
var state: ToolState:
	get:
		return slots.held()
var last_stroke_usec: int = 0 ## coût du dernier geste (mesure)
var last_cleaned_area: float = 0.0 ## m² nettoyés par le dernier geste

var _stroking: bool = false
var _rinse_latched: bool = false ## rinçage déjà fait pour l'appui en cours
var _last_point: Vector3 = Vector3.ZERO
var _label: Label
var _marker: Panel
var _finished_msg_until_msec: int = 0 ## fin d'affichage de « Surface finie ! » (debug surfaces)

@onready var _player: Player = get_parent() as Player
@onready var _camera: Camera3D = get_node_or_null(^"../Head/Camera3D") as Camera3D
@onready var _carry: CarryController = get_node_or_null(^"../CarryController") as CarryController
@onready var _sensor: InteractionSensor = get_node_or_null(^"../Head/InteractionSensor") as InteractionSensor
@onready var _prompt: InteractionPrompt = get_node_or_null(^"../InteractionPrompt") as InteractionPrompt


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ToolDebug"
	add_child(layer)
	_label = Label.new()
	_label.name = "Infos"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.position += Vector2(-16.0, 16.0)
	_marker = _build_marker()
	layer.add_child(_marker)
	slots.held_changed.connect(_on_tool_held_changed)
	if _carry != null:
		_carry.held_changed.connect(on_held_item_changed)
	_refresh_label()
	if DEBUG_SURFACES:
		_connect_surfaces.call_deferred() # les surfaces de la pièce sont prêtes après le joueur


func _unhandled_input(event: InputEvent) -> void:
	if not _accepts_input():
		return
	if event.is_action_pressed(&"equip_tool", false):
		toggle_tool()


func _process(_delta: float) -> void:
	_marker.visible = _player != null and _player.camera_locked
	if _marker.visible:
		_marker.position = _marker.get_viewport().get_mouse_position() - _marker.size * 0.5
	if DEBUG_SURFACES:
		_refresh_label()


## Point unique de relâchement : l'outil n'est plus tenu -> le verrou caméra est relâché.
func set_tool_held(held: bool) -> void:
	if not held and _player != null:
		_player.set_camera_locked(false)


## L'objet tenu a changé (prise réussie, changement, dépôt) : l'outil en main retourne dans son
## emplacement et le verrou est relâché. Une prise refusée n'émet rien : l'outil reste en main.
func on_held_item_changed() -> void:
	stow_tool()
	set_tool_held(false)


## Ajoute un emplacement pour cet outil (rangé) et renvoie son index.
func add_tool(tool_data: ToolData) -> int:
	var index: int = slots.add_tool(tool_data)
	_refresh_label()
	return index


## Outil en main (null si aucun).
func held_tool() -> ToolData:
	return state.data if state != null else null


## Sort l'outil de l'emplacement donné (par défaut : l'emplacement sélectionné) et le place en main.
## Refusé si l'emplacement n'existe pas ou si la main porte un objet (tool.hand_occupied).
func take_out(index: int = ToolSlots.NONE) -> bool:
	if index == ToolSlots.NONE:
		index = slots.selected_index
	if slots.state_at(index) == null:
		return false
	if _carry != null and _carry.held_data() != null:
		if _prompt != null:
			_prompt.show_message("tool.hand_occupied")
		return false
	return slots.take_out(index)


## Range l'outil en main dans son emplacement (sans effet si aucun).
func stow_tool() -> void:
	if slots.stow():
		tool_stowed.emit()


## Vrai tant qu'un geste continu est en cours (une sauvegarde automatique attend sa fin).
func is_action_active() -> bool:
	return _stroking


## Interrompt proprement le geste en cours : chaque pas déjà appliqué est complet (faces et salissure
## cohérentes), le prochain contact démarre un nouveau geste. Sans effet si aucun geste n'est en cours.
func cancel_action() -> void:
	_set_stroking(false)


## Action equip_tool : range l'outil en main, sinon sort l'outil sélectionné.
func toggle_tool() -> void:
	if state != null:
		stow_tool()
	else:
		take_out()


## Rince l'outil en main. Renvoie false sans outil en main.
func rinse() -> bool:
	if state == null:
		return false
	state.rinse()
	_refresh_label()
	return true


## Clic sur un seau : rince l'outil en main au seau donné. Refusé (false) sans outil en main, si
## le corps n'est pas un seau ou si le seau est porté (il doit être posé).
func rinse_at(bucket: Node) -> bool:
	if state == null or not (bucket is Bucket):
		return false
	if _carry != null and _carry.held_body() == bucket:
		return false
	return rinse()


func _physics_process(delta: float) -> void:
	if not Input.is_action_pressed(&"use_primary"):
		_rinse_latched = false
	if state == null or _camera == null or not _is_active():
		_set_stroking(false)
		return
	var from: Vector3 = _camera.global_position
	var direction: Vector3 = -_camera.global_basis.z
	if _player != null and _player.camera_locked:
		var cursor: Vector2 = _camera.get_viewport().get_mouse_position()
		from = _camera.project_ray_origin(cursor)
		direction = _camera.project_ray_normal(cursor)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from, from + direction * state.data.reach_m, WORLD_LAYER | BUCKET_LAYER)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	apply_aim_hit(hit, delta)


## Traite le premier objet touché par le rayon de visée (clic maintenu, outil en main) : un seau
## posé rince une fois par appui et ne nettoie rien derrière lui ; tout autre objet nettoie.
func apply_aim_hit(hit: Dictionary, delta: float) -> void:
	if hit.is_empty():
		_set_stroking(false)
		return
	var collider: Object = hit.get("collider")
	if collider is Bucket:
		_set_stroking(false)
		if not _rinse_latched and rinse_at(collider as Bucket):
			_rinse_latched = true
		return
	var point: Vector3 = hit["position"]
	stroke(_last_point if _stroking else point, point, delta)
	_last_point = point
	_stroking = true


## Applique un geste monde from -> to pendant delta secondes : nettoie les faces à portée du geste
## (y compris à travers les coutures) et salit l'outil de l'aire nettoyée. Renvoie cette aire (m²).
func stroke(from: Vector3, to: Vector3, delta: float) -> float:
	if state == null or delta <= 0.0:
		return 0.0
	var tool: ToolData = state.data
	var t0: int = Time.get_ticks_usec()
	var amount: float = state.effective_efficiency() * delta
	var reach_box: AABB = AABB(from, Vector3.ZERO).expand(to).grow(tool.radius_m)
	var cleaned: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(CleanableFace.GROUP):
		var face: CleanableFace = node as CleanableFace
		if face == null or face.is_finished() or not reach_box.intersects(face.world_bounds()):
			continue
		# Grille fine avant la mesure : sans elle, l'aire restante n'est qu'une estimation grossière.
		face.ensure_fine_grid()
		var before: float = face.remaining_dirty_area()
		if face.clean_stroke(from, to, tool.radius_m, amount, tool.layers):
			cleaned += maxf(0.0, before - face.remaining_dirty_area())
	state.add_cleaned_area(cleaned)
	last_cleaned_area = cleaned
	last_stroke_usec = Time.get_ticks_usec() - t0
	_refresh_label()
	return cleaned


## Section « outils » d'une sauvegarde (clé ToolSlots.SAVE_KEY des données du SaveService).
func export_tools() -> Dictionary:
	return slots.export_state()


## Restaure les outils depuis la section « outils » ({} = aucun outil ; voir ToolSlots.import_state).
func import_tools(section: Dictionary, catalog: Array[ToolData]) -> bool:
	var ok: bool = slots.import_state(section, catalog)
	_refresh_label()
	return ok


## Texte de debug : salissure et efficacité effective de l'outil en main ; "Outil : rangé" si
## aucun n'est en main ; "" sans emplacement.
func debug_text() -> String:
	var tool_text: String = _tool_debug_text()
	if not DEBUG_SURFACES:
		return tool_text
	var lines: Array[String] = []
	if tool_text != "":
		lines.append(tool_text)
	lines.append_array(_surfaces_debug_lines())
	return "\n".join(lines)


func _tool_debug_text() -> String:
	if state == null:
		return "Outil : rangé" if slots.count() > 0 else ""
	return "Outil : %s\nSalissure : %d %%\nEfficacité : %.2f (%d %%)\nDernier geste : %.2f ms" % [
		state.data.id, roundi(state.soil * 100.0), state.effective_efficiency(),
		roundi(state.efficiency_factor() * 100.0), last_stroke_usec / 1000.0]


# --- Debug des surfaces (temporaire, DEBUG_SURFACES) ---

func _connect_surfaces() -> void:
	for node: Node in get_tree().get_nodes_in_group(CleaningSurface.GROUP):
		if not node.is_connected(&"surface_finished", _on_surface_finished):
			node.connect(&"surface_finished", _on_surface_finished)


func _on_surface_finished(_surface: CleaningSurface) -> void:
	_finished_msg_until_msec = Time.get_ticks_msec() + roundi(DEBUG_FINISHED_SHOWN_S * 1000.0)


func _surfaces_debug_lines() -> Array[String]:
	var surfaces: Array[Node] = get_tree().get_nodes_in_group(CleaningSurface.GROUP)
	var done: int = 0
	for node: Node in surfaces:
		if (node as CleaningSurface).is_finished():
			done += 1
	var lines: Array[String] = ["Surfaces terminées : %d / %d" % [done, surfaces.size()]]
	var aimed: CleaningSurface = _aimed_surface(surfaces)
	if aimed == null:
		lines.append("Surface visée : aucune")
	else:
		lines.append("Surface visée : %s — sale restant %.3f m² / seuil %.3f m² — terminée : %s" % [
				aimed.name, aimed.remaining_dirty_area(), aimed.threshold(),
				"oui" if aimed.is_finished() else "non"])
	if Time.get_ticks_msec() < _finished_msg_until_msec:
		lines.append("Surface finie !")
	return lines


## Surface visée par le centre de l'écran (ou le curseur si la caméra est verrouillée) : la surface
## dont une face a la boîte la plus proche du point touché (null si rien n'est visé).
func _aimed_surface(surfaces: Array[Node]) -> CleaningSurface:
	if _camera == null or not _camera.is_inside_tree():
		return null
	var from: Vector3 = _camera.global_position
	var direction: Vector3 = -_camera.global_basis.z
	if _player != null and _player.camera_locked:
		var cursor: Vector2 = _camera.get_viewport().get_mouse_position()
		from = _camera.project_ray_origin(cursor)
		direction = _camera.project_ray_normal(cursor)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from, from + direction * DEBUG_AIM_REACH_M, WORLD_LAYER)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var point: Vector3 = hit["position"]
	var best: CleaningSurface = null
	var best_distance: float = 0.05 ## m, tolérance de la boîte de face
	for node: Node in surfaces:
		var surface: CleaningSurface = node as CleaningSurface
		for face: CleanableFace in surface.faces:
			if face == null:
				continue
			var d: float = face.distance_to_bounds(point)
			if d <= best_distance:
				best_distance = d
				best = surface
	return best


func _is_active() -> bool:
	return Input.is_action_pressed(&"use_primary") and _accepts_input()


func _accepts_input() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (_player != null and _player.camera_locked)


func _set_stroking(value: bool) -> void:
	if _stroking == value:
		return
	_stroking = value
	if not value:
		action_finished.emit()


func _on_tool_held_changed() -> void:
	_set_stroking(false)
	set_tool_held(state != null)
	_refresh_label()


func _refresh_label() -> void:
	if _label != null:
		_label.text = debug_text()
		_label.visible = _label.text != ""


## Marqueur de visée provisoire (anneau, sans asset) : remplace le curseur système masqué pendant
## le verrouillage de caméra.
func _build_marker() -> Panel:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	style.border_color = Color(1.0, 1.0, 1.0, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(roundi(MARKER_SIZE * 0.5))
	var marker: Panel = Panel.new()
	marker.name = "AimMarker"
	marker.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_theme_stylebox_override(&"panel", style)
	marker.visible = false
	return marker
