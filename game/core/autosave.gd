class_name Autosave
extends Node
## Sauvegarde automatique sur événements (décision de Direction du 12/11/2026) : un seul emplacement,
## aucun intervalle fixe, aucune sauvegarde manuelle. Déclencheurs : outil rangé
## (ToolController.tool_stowed), fin d'une surface à nettoyer (CleaningSurface.surface_finished),
## dépôt validé d'un objet (RoomLayout.item_deposited, chute comprise), fermeture du jeu,
## request_save() pour les déclencheurs à venir.
## Un déclencheur reçu pendant une action d'outil attend sa fin. L'export des faces est étalé sur
## plusieurs images (budget export_budget_usec, liste de faces figée au départ) : l'encodage zstd +
## base64 des 188 faces du tour coûte 12 à 16 ms d'un bloc sur le fil principal, 0,6 ms au pire par
## face. Un déclencheur reçu avant la fin de l'export le reprend du début : une seule écriture, aucun
## état perdu. Écriture par SaveService.save_slot_threaded ; résultat relayé par save_completed.
## Avec un RoomLayout branché, la disposition des objets et le portage du joueur sont figés en une
## seule image au début de l'export (de nouveau s'il est repris du début) et écrits dans la section
## « disposition ».
## Avec un RoomProgress branché, la pose du verrou « restaurée » (RoomProgress.lock_posed, jamais au
## chargement) est un déclencheur de plus, et sa section « progression » est écrite à chaque sauvegarde.

## Fin de l'écriture de l'emplacement (SaveError du SaveService), émis sur le fil principal.
signal save_completed(error: int)

const SLOT_ID: String = "partie"
const CLEANING_KEY: String = "nettoyage"
const OK_RESULT: int = 0 ## SaveError.OK du SaveService
const NOT_CONFIGURED: int = -1 ## setup() non appelé, ou pièce/outils/service libérés : rien n'est écrit
const WRITE_PENDING: int = -2 ## écriture en file, résultat pas encore reçu
const LOG_PREFIX: String = "[Autosave] "

enum Phase { IDLE, WAITING, EXPORTING }

## Temps d'export par image sur le fil principal, en µs (provisoire). Dépassement maximal : une face.
@export var export_budget_usec: int = 2000
## Intercepte la fermeture de la fenêtre pour sauvegarder avant de quitter.
@export var handle_quit: bool = true
## Disposition de la pièce (nœud RoomLayout), branchée par setup(). Vide : aucune section « disposition ».
@export var layout_path: NodePath
## Progression de la pièce (nœud RoomProgress), branchée par setup(). Vide : aucune section « progression ».
@export var progress_path: NodePath

var room_root: Node
var tools: ToolController
var service: Node
var layout: RoomLayout ## facultatif (watch_layout) : sans lui, les données écrites sont inchangées
var progress: RoomProgress ## facultatif (watch_progress) : sans lui, les données écrites sont inchangées
var slot_id: String = SLOT_ID
var last_error: int = OK_RESULT ## résultat de la dernière écriture (WRITE_PENDING tant qu'elle est en file)

# Mesures et compteurs (tests, HUD de debug).
var triggers_received: int = 0
var writes_requested: int = 0
var skipped_faces: int = 0 ## faces libérées entre le début de l'export et leur tour
var export_frames: int = 0 ## images utilisées par le dernier export
var worst_step_usec: int = 0 ## pire image d'export sur le fil principal (écriture en file comprise)

var _phase: Phase = Phase.IDLE
var _faces: Array = [] # liste figée au début de l'export (non typée : une face peut être libérée)
var _index: int = 0
var _entries: Dictionary = {}
var _stale: bool = false # une action d'outil a eu lieu depuis le début de l'export en cours
var _layout_section: Dictionary = {} # disposition figée au début de l'export
var _layout_frozen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS ## l'export étalé continue pendant la pause
	if handle_quit:
		get_tree().auto_accept_quit = false
	set_process(_phase != Phase.IDLE)


func _exit_tree() -> void:
	if handle_quit:
		get_tree().auto_accept_quit = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and handle_quit:
		save_and_wait()
		get_tree().quit()


func _process(_delta: float) -> void:
	advance()


## Branche la pièce (racine des CleanableFace, repère de leurs id), les outils du joueur et le
## service de sauvegarde (par défaut : l'autoload SaveService).
func setup(room: Node, tool_controller: ToolController, save_service: Node = null) -> void:
	room_root = room
	tools = tool_controller
	service = save_service if save_service != null else get_node_or_null(^"/root/SaveService")
	if tools != null and not tools.tool_stowed.is_connected(request_save):
		tools.tool_stowed.connect(request_save)
		tools.action_finished.connect(_on_action_finished)
	if service != null and not service.is_connected(&"save_finished", _on_save_finished):
		service.connect(&"save_finished", _on_save_finished)
	if room != null:
		for surface: CleaningSurface in CleaningSurface.room_surfaces(room):
			watch_surface(surface)
	if layout == null and not layout_path.is_empty():
		watch_layout(get_node_or_null(layout_path) as RoomLayout)
	if progress == null and not progress_path.is_empty():
		watch_progress(get_node_or_null(progress_path) as RoomProgress)


## Relie la fin d'une surface à nettoyer à request_save() (idempotent). setup() l'applique à toutes
## les surfaces de la pièce ; à appeler pour une surface ajoutée plus tard.
func watch_surface(surface: CleaningSurface) -> void:
	if not surface.surface_finished.is_connected(_on_surface_finished):
		surface.surface_finished.connect(_on_surface_finished)


## Branche la disposition de la pièce (idempotent) : son dépôt validé devient un déclencheur et sa
## section est écrite à chaque sauvegarde.
func watch_layout(room_layout: RoomLayout) -> void:
	layout = room_layout
	if layout != null and not layout.item_deposited.is_connected(_on_item_deposited):
		layout.item_deposited.connect(_on_item_deposited)


## Branche la progression de la pièce (idempotent) : la pose du verrou « restaurée » devient un
## déclencheur et sa section est écrite à chaque sauvegarde.
func watch_progress(room_progress: RoomProgress) -> void:
	progress = room_progress
	if progress != null and not progress.lock_posed.is_connected(_on_lock_posed):
		progress.lock_posed.connect(_on_lock_posed)


func is_configured() -> bool:
	return is_instance_valid(room_root) and is_instance_valid(tools) and is_instance_valid(service)


## Vrai tant qu'un déclencheur attend ou qu'un export est en cours (l'écriture en file ne compte pas).
func is_busy() -> bool:
	return _phase != Phase.IDLE


## Déclencheur de sauvegarde. Ne coûte rien à l'appel : l'export commence à l'image suivante, ou à
## la fin de l'action d'outil en cours. Les déclencheurs reçus d'ici la fin de l'export sont
## fusionnés en une seule écriture ; un export déjà commencé est repris du début (l'état postérieur
## au premier déclencheur n'est jamais perdu).
## Ignoré pendant la restauration de la disposition (RoomLayout.restoring) : comme pour le
## chargement des surfaces, aucun déclencheur au chargement (outil rangé par la remise en main comprise).
func request_save() -> void:
	if is_instance_valid(layout) and layout.restoring:
		return
	triggers_received += 1
	_faces.clear()
	_entries = {}
	_layout_section = {}
	_layout_frozen = false
	_phase = Phase.WAITING
	set_process(true)


## Sauvegarde immédiate et bloquante, pour quitter la partie : fermeture du jeu, futur retour au
## menu principal. Annule proprement l'action d'outil en cours, termine l'export d'un coup, met
## l'écriture en file puis attend sa fin. Retourne le SaveError de l'écriture (0 = OK), ou
## NOT_CONFIGURED si rien n'a pu être écrit.
func save_and_wait() -> int:
	if not is_configured():
		_reset()
		return NOT_CONFIGURED
	tools.cancel_action()
	# Export en cours repris tel quel, sauf si une action d'outil a pu modifier une face déjà exportée.
	if _phase != Phase.EXPORTING or _stale:
		_begin_export()
	else:
		_freeze_layout() # export repris tel quel : la disposition écrite est celle de la sortie
	_export_slice(-1)
	var queued: int = _write()
	if queued != OK_RESULT:
		return queued
	service.call(&"flush")
	return last_error


## Travail d'une image (appelé par _process) : attend la fin de l'action d'outil, puis exporte les
## faces dans la limite du budget et met l'écriture en file après la dernière.
func advance() -> void:
	if _phase == Phase.IDLE:
		set_process(false)
		return
	if not is_configured():
		push_warning(LOG_PREFIX + "pièce, outils ou service indisponibles : sauvegarde abandonnée.")
		_reset()
		return
	if tools.is_action_active():
		return
	var t0: int = Time.get_ticks_usec()
	if _phase == Phase.WAITING:
		_begin_export()
	_export_slice(export_budget_usec)
	export_frames += 1
	if _index >= _faces.size():
		_write()
	worst_step_usec = maxi(worst_step_usec, Time.get_ticks_usec() - t0)


func _begin_export() -> void:
	_faces.assign(room_root.find_children("*", "CleanableFace", true, false))
	_entries = {}
	_index = 0
	_stale = false
	export_frames = 0
	_phase = Phase.EXPORTING
	_freeze_layout()


## Fige la disposition de la pièce en une seule image (instantané cohérent malgré l'export étalé).
func _freeze_layout() -> void:
	_layout_frozen = is_instance_valid(layout)
	_layout_section = layout.export_state() if _layout_frozen else {}


## Exporte les faces suivantes de la liste figée jusqu'à épuiser le budget (< 0 : sans limite).
## Chaque face est vérifiée avant son export : libérée ou sortie de la pièce, elle est ignorée.
func _export_slice(budget_usec: int) -> void:
	var t0: int = Time.get_ticks_usec()
	while _index < _faces.size():
		var item: Variant = _faces[_index]
		_index += 1
		if _is_exportable(item):
			var entry: Dictionary = (item as CleanableFace).export_state(room_root)
			if not entry.is_empty():
				_entries[entry["id"]] = entry
		else:
			skipped_faces += 1
		if budget_usec >= 0 and Time.get_ticks_usec() - t0 >= budget_usec:
			return


func _is_exportable(item: Variant) -> bool:
	if not is_instance_valid(item) or not (item is CleanableFace):
		return false
	var face: CleanableFace = item as CleanableFace
	return not face.is_queued_for_deletion() and room_root.is_ancestor_of(face)


## Met l'écriture en file (faces exportées + outils, état des outils lu à cet instant).
func _write() -> int:
	var data: Dictionary = {CLEANING_KEY: _entries, ToolSlots.SAVE_KEY: tools.export_tools()}
	if _layout_frozen:
		data[LayoutState.SAVE_KEY] = _layout_section
	if is_instance_valid(progress):
		data[ProgressSave.SAVE_KEY] = progress.export_state() # verrous : jamais retirés, lus à l'écriture
	_reset()
	writes_requested += 1
	last_error = WRITE_PENDING
	var queued: int = service.call(&"save_slot_threaded", slot_id, data)
	if queued != OK_RESULT:
		_on_save_finished(slot_id, queued)
	return queued


func _reset() -> void:
	_phase = Phase.IDLE
	_faces.clear()
	_entries = {}
	_index = 0
	_stale = false
	_layout_section = {}
	_layout_frozen = false
	set_process(false)


func _on_surface_finished(_surface: CleaningSurface) -> void:
	request_save()


func _on_item_deposited(_item: TestItem) -> void:
	request_save()


func _on_lock_posed(_room_id: StringName) -> void:
	request_save()


func _on_action_finished() -> void:
	if _phase == Phase.EXPORTING:
		_stale = true


func _on_save_finished(finished_slot: String, error: int) -> void:
	if finished_slot != slot_id:
		return
	last_error = error
	if error != OK_RESULT:
		push_error(LOG_PREFIX + "échec de l'écriture de l'emplacement « %s » (SaveError %d)." % [slot_id, error])
	save_completed.emit(error)
