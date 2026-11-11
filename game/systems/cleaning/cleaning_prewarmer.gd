class_name CleaningPrewarmer
extends Node
## Préchauffage asynchrone de la grille fine des faces nettoyables (spike P2-N2).
## Les faces sans grille à moins de radius_m de la cible sont mises en file (les plus proches
## d'abord) ; leur GridJob tourne sur le WorkerThreadPool et son résultat est affecté sur le fil
## principal (CleanableFace.apply_grid), dans la limite d'un budget de temps par image.
## Aucun tampon de face n'est écrit depuis un fil. Une face touchée avant d'être prête se calcule
## en synchrone (CleanableFace.ensure_fine_grid) ; le résultat du fil est alors ignoré.

@export var target: Node3D ## en général le joueur
@export var radius_m: float = 4.0 ## PROVISOIRE
@export_range(1, 16) var max_tasks: int = 2 ## calculs simultanés, PROVISOIRE
@export var scan_interval: float = 0.25 ## s entre deux parcours des faces, PROVISOIRE
@export var apply_budget_usec: int = 2000 ## budget d'affectation par image, PROVISOIRE

## Faces suivies ; vide = toutes les faces du groupe CleanableFace.GROUP.
var faces: Array[CleanableFace] = []

## Mesures.
var prewarmed_count: int = 0 ## grilles affectées depuis un fil
var discarded_count: int = 0 ## résultats ignorés (face déjà prête : repli synchrone entre-temps)
var worst_apply_usec: int = 0 ## pire affectation d'une grille sur le fil principal
var worst_tick_usec: int = 0 ## pire durée de tick() sur le fil principal

var _queue: Array[CleanableFace] = [] # en attente, triées par distance
var _running: Array[Array] = [] # [face, job, identifiant de tâche]
var _done: Array[Array] = [] # [face, job] : calcul terminé, affectation en attente
var _scan_left: float = 0.0


func _process(delta: float) -> void:
	if target != null:
		tick(target.global_position, delta)


func _exit_tree() -> void:
	# Aucune tâche ne doit survivre au nœud.
	for entry: Array in _running:
		WorkerThreadPool.wait_for_task_completion(entry[2])
	_running.clear()
	_done.clear()
	_queue.clear()


## Une étape : collecte des calculs terminés, affectation (budget), parcours, lancement.
func tick(world_position: Vector3, delta: float = 0.0) -> void:
	var t0: int = Time.get_ticks_usec()
	_collect()
	_apply_done(apply_budget_usec)
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = scan_interval
		_scan(world_position)
	_launch()
	worst_tick_usec = maxi(worst_tick_usec, Time.get_ticks_usec() - t0)


## Attend la fin de tous les calculs lancés ou en file et affecte tout (tests, chargement).
func flush() -> void:
	while not (_queue.is_empty() and _running.is_empty()):
		_launch()
		for entry: Array in _running:
			WorkerThreadPool.wait_for_task_completion(entry[2])
			_done.append([entry[0], entry[1]])
		_running.clear()
	_apply_done(-1)


func queue_size() -> int:
	return _queue.size()


func running_count() -> int:
	return _running.size()


func pending_apply_count() -> int:
	return _done.size()


func is_idle() -> bool:
	return _queue.is_empty() and _running.is_empty() and _done.is_empty()


func _tracked() -> Array[CleanableFace]:
	if not faces.is_empty() or not is_inside_tree():
		return faces
	var out: Array[CleanableFace] = []
	out.assign(get_tree().get_nodes_in_group(CleanableFace.GROUP))
	return out


func _scan(world_position: Vector3) -> void:
	var busy: Dictionary = {}
	for entry: Array in _running:
		busy[entry[0]] = true
	for entry: Array in _done:
		busy[entry[0]] = true
	var found: Array[Array] = [] # [distance, face]
	for face: CleanableFace in _tracked():
		if not is_instance_valid(face) or face.has_fine_grid() or busy.has(face):
			continue
		var distance: float = face.distance_to_bounds(world_position)
		if distance < radius_m:
			found.append([distance, face])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_queue.clear()
	for entry: Array in found:
		_queue.append(entry[1])


func _launch() -> void:
	while _running.size() < max_tasks and not _queue.is_empty():
		var face: CleanableFace = _queue.pop_front()
		if not is_instance_valid(face) or face.has_fine_grid():
			continue
		var job: CleanableFace.GridJob = face.make_grid_job() # copie des entrées, fil principal
		var task: int = WorkerThreadPool.add_task(job.run_threaded, false, "CleaningPrewarmer")
		_running.append([face, job, task])


func _collect() -> void:
	var still: Array[Array] = []
	for entry: Array in _running:
		if WorkerThreadPool.is_task_completed(entry[2]):
			WorkerThreadPool.wait_for_task_completion(entry[2]) # libère la tâche, sans attente
			_done.append([entry[0], entry[1]])
		else:
			still.append(entry)
	_running = still


## Affecte les grilles prêtes ; budget_usec < 0 = sans limite. Au moins une par appel.
func _apply_done(budget_usec: int) -> void:
	var t0: int = Time.get_ticks_usec()
	while not _done.is_empty():
		var entry: Array = _done.pop_front()
		if is_instance_valid(entry[0]):
			var face: CleanableFace = entry[0]
			if face.apply_grid(entry[1]):
				prewarmed_count += 1
				worst_apply_usec = maxi(worst_apply_usec, face.grid_apply_usec)
			else:
				discarded_count += 1
		if budget_usec >= 0 and Time.get_ticks_usec() - t0 >= budget_usec:
			break
