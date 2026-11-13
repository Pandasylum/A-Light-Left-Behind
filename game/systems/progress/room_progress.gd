class_name RoomProgress
extends Node
## Progression de restauration d'une pièce (GDD §5 et §6) : nœud de la scène de pièce (pas d'autoload).
## Lit RoomData (axes actifs), les compteurs de CleaningSurface (room_surfaces, count_in_room,
## finished_count_in_room) et l'état « rangé » de StorageService (is_stored, stored_changed), puis
## délègue TOUT le calcul à ProgressFormula (seul fichier de la formule). Expose les compteurs par
## axe, le pourcentage (calculé en direct, même après le verrou) et le verrou « restaurée » ; émet
## `changed` seulement quand quelque chose change.
## Verrou « restaurée » : booléen par pièce (clé = id de RoomData), posé au premier passage à complet,
## jamais retiré. Le poser en jeu émet `lock_posed` (déclencheur de l'Autosave) ; le poser au
## chargement ne déclenche rien. Section « progression » : ProgressSave.
## Chargement : tant que StorageService n'a pas émis room_evaluated (après l'import du nettoyage et la
## restauration de la disposition et du portage), RoomProgress reste neutre (is_evaluated() faux).
## La scène de jeu applique la section « progression » par import_state, comme les autres sections ;
## sans cet appel, le verrou reste à faux (RoomProgress ne lit jamais l'emplacement lui-même).

## Un compteur, le pourcentage, l'état d'évaluation ou le verrou a changé (jamais pour rien).
signal changed
## Le verrou vient d'être posé pendant la partie (jamais au chargement) ; id = id de la pièce.
signal lock_posed(room_id: StringName)

@export var room_data: RoomData
## Racine de la pièce : ses CleaningSurface sont comptées.
@export var room_path: NodePath = ^".."
## StorageService de la pièce (état « rangé » et liste des objets). Vide : aucun objet compté.
@export var storage_path: NodePath

var _storage: StorageService
var _evaluated: bool = false
var _locks: Dictionary = {} ## id de pièce (String) -> true
var _result: ProgressFormula.Result


func _ready() -> void:
	if room_data == null:
		push_warning("RoomProgress : aucune RoomData, progression toujours à 0.")
	_storage = get_node_or_null(storage_path) as StorageService if not storage_path.is_empty() else null
	if _storage != null:
		_storage.stored_changed.connect(_on_stored_changed)
		_storage.room_evaluated.connect(finish_loading)
	watch_surfaces()


## Relie la fin de chaque surface de la pièce (idempotent) ; à rappeler pour une surface ajoutée plus tard.
func watch_surfaces() -> void:
	var room: Node = get_node_or_null(room_path)
	if room == null:
		return
	for surface: CleaningSurface in CleaningSurface.room_surfaces(room):
		if not surface.surface_finished.is_connected(_on_surface_finished):
			surface.surface_finished.connect(_on_surface_finished)


## Fin du chargement (appelée sur StorageService.room_evaluated) : premier calcul. Un verrou manquant
## alors que la pièce est complète est posé sans émettre lock_posed (aucune demande de sauvegarde).
func finish_loading() -> void:
	if _evaluated:
		return
	_evaluated = true
	watch_surfaces()
	_update(false)


## Recalcule (à appeler après un changement que RoomProgress ne peut pas observer, par exemple un
## import de nettoyage en cours de partie). Sans effet avant la fin du chargement.
func refresh() -> void:
	if _evaluated:
		_update(true)


func is_evaluated() -> bool:
	return _evaluated


## Compteurs de l'axe nettoyage : x = surfaces finies, y = surfaces.
func cleaning_counts() -> Vector2i:
	return Vector2i(_result.cleaning_done, _result.cleaning_total) if _result != null else Vector2i.ZERO


## Compteurs de l'axe rangement : x = objets suivis rangés, y = objets suivis.
func storing_counts() -> Vector2i:
	return Vector2i(_result.storing_done, _result.storing_total) if _result != null else Vector2i.ZERO


## Résultat du dernier calcul (null avant la fin du chargement).
func result() -> ProgressFormula.Result:
	return _result


## Pourcentage affiché (entier arrondi vers le bas ; 100 seulement si complet ; 0 avant le chargement).
func percent() -> int:
	return _result.percent if _result != null else 0


## Vrai si tout est fait en ce moment (en direct : peut redevenir faux après le verrou).
func is_complete() -> bool:
	return _result != null and _result.complete


## Verrou « restaurée » de cette pièce.
func is_restored() -> bool:
	return room_data != null and _locks.has(String(room_data.id))


## Section « progression » (clé ProgressSave.SAVE_KEY des données du SaveService).
func export_state() -> Dictionary:
	return ProgressSave.make_section(_locks)


## Restaure les verrous depuis la section ({} = absente = aucune pièce restaurée). Section illisible ou
## version inconnue : ignorée avec un avertissement (false). Ne déclenche jamais de sauvegarde.
func import_state(section: Variant) -> bool:
	var plan: ProgressSave.Plan = ProgressSave.parse(section)
	if not plan.accepted:
		push_warning("RoomProgress : section « %s » ignorée (%s)." % [ProgressSave.SAVE_KEY, plan.error])
		return false
	var added: bool = false
	for id: Variant in plan.restored:
		if not _locks.has(id):
			_locks[id] = true
			added = true
	if added and _evaluated:
		_update(false, true)
	return true


func _on_surface_finished(_surface: CleaningSurface) -> void:
	refresh()


func _on_stored_changed(_item: TestItem, _stored: bool) -> void:
	refresh()


## Calcule, pose le verrou au premier passage à complet, émet changed si quelque chose a changé.
func _update(announce_lock: bool, force_changed: bool = false) -> void:
	var result: ProgressFormula.Result = _compute()
	var lock_new: bool = false
	if result.complete and room_data != null and not is_restored():
		_locks[String(room_data.id)] = true
		lock_new = true
	var different: bool = force_changed or lock_new or not result.same_as(_result)
	_result = result
	if different:
		changed.emit()
	if lock_new and announce_lock:
		lock_posed.emit(room_data.id)


func _compute() -> ProgressFormula.Result:
	var axes: Array = room_data.active_axes if room_data != null else []
	var room: Node = get_node_or_null(room_path)
	var surfaces_total: int = CleaningSurface.count_in_room(room) if room != null else 0
	var surfaces_done: int = CleaningSurface.finished_count_in_room(room) if room != null else 0
	var datas: Array = []
	var stored: Array = []
	if _storage != null:
		for item: TestItem in _storage.tracked_items():
			datas.append(item.item_data)
			stored.append(_storage.is_stored(item))
	return ProgressFormula.compute(axes, surfaces_done, surfaces_total, datas, stored)
