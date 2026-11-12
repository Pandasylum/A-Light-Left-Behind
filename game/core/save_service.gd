## NB : pas de class_name, Godot interdit qu'il porte le même nom que l'autoload SaveService.
extends Node
## Service de sauvegarde générique : JSON versionné, écriture atomique, copie de repli (.bak),
## migrations entre versions, mise de côté des fichiers illisibles (.corrompu, jamais supprimés).
## Ne connaît pas le contenu des données. Un fichier de sauvegarde est NON FIABLE (import possible).
## En jeu, écrire par save_slot_threaded : une écriture complète bloque jusqu'à ~50 ms (3 images à 60 FPS).
## Toutes les fonctions publiques s'appellent depuis le fil principal.

## Fin d'une écriture mise en file par save_slot_threaded, émis sur le fil principal.
signal save_finished(slot_id: String, error: SaveError)

const FORMAT_VERSION: int = 1
const SLOT_EXTENSION: String = "json"
const BACKUP_SUFFIX: String = ".bak"
const CORRUPT_SUFFIX: String = ".corrompu"
const LOG_PREFIX: String = "[SaveService] "
## Sections obligatoires de l'enveloppe et leur type une fois le JSON relu.
const ENVELOPE_SECTIONS: Dictionary[String, int] = {
	"format_version": TYPE_FLOAT, "written_at": TYPE_STRING, "checksum": TYPE_STRING, "payload": TYPE_STRING,
}

enum SaveError {
	OK,
	INVALID_SLOT_ID,
	INVALID_DATA,
	IO_ERROR,
	NOT_FOUND,
	INVALID_JSON,
	INVALID_ENVELOPE,
	CHECKSUM_MISMATCH,
	VERSION_TOO_NEW,
	VERSION_UNKNOWN,
	MIGRATION_FAILED,
}

## Dossier des sauvegardes (configurable ; les tests utilisent un autre dossier).
var save_dir: String = "user://saves/"
## Version écrite et attendue au chargement (configurable ; les tests simulent une version future).
var format_version: int = FORMAT_VERSION

## Étapes de migration : version de départ -> Callable(données: Dictionary) -> Dictionary (version suivante).
var _migrations: Dictionary[int, Callable] = {}
## Emplacements dont le fichier principal est connu valide (écrit ou chargé par cette instance).
var _verified: Dictionary[String, bool] = {}
## Emplacements dont le dernier chargement a échoué alors que des fichiers existent.
var _damaged: Dictionary[String, bool] = {}
## Écritures en attente du fil de travail : emplacement -> données (la plus récente remplace l'attente).
var _pending: Dictionary[String, Dictionary] = {}
## Résultats à émettre sur le fil principal : [slot_id, SaveError].
var _finished: Array[Array] = []
## Protège _pending, _finished et _worker_running (seul état partagé avec le fil de travail).
var _queue_mutex: Mutex = Mutex.new()
var _worker_running: bool = false
var _thread: Thread


## Déclare l'étape qui fait passer les données de from_version à from_version + 1.
## Toute valeur de retour autre qu'un Dictionary est un échec (MIGRATION_FAILED).
## À chaque hausse de FORMAT_VERSION : une étape déclarée ici (_init) et un fichier figé de
## l'ancienne version dans save_roundtrip_test.gd (VERSION_FIXTURES).
func register_migration(from_version: int, step: Callable) -> void:
	_migrations[from_version] = step


## Écrit l'emplacement de façon atomique et attend la fin de l'écriture (bloque le fil appelant).
## Retourne un SaveError. En jeu, préférer save_slot_threaded.
func save_slot(slot_id: String, data: Dictionary) -> SaveError:
	if not _is_valid_slot_id(slot_id):
		return SaveError.INVALID_SLOT_ID
	flush()
	return _write_slot(slot_id, data)


## Même écriture atomique, sur un fil de travail : sérialisation, écriture, relecture de contrôle et
## rotation de la copie de repli hors du fil principal. Retourne INVALID_SLOT_ID, sinon OK = mise en
## file ; le résultat réel arrive par save_finished. Les données sont copiées (l'appelant peut les
## modifier ensuite). Une écriture encore en attente pour le même emplacement est remplacée par la
## plus récente. Rien n'est perdu en quittant : la file est vidée à la destruction du service.
func save_slot_threaded(slot_id: String, data: Dictionary) -> SaveError:
	if not _is_valid_slot_id(slot_id):
		return SaveError.INVALID_SLOT_ID
	var snapshot: Dictionary = data.duplicate(true)
	_queue_mutex.lock()
	_pending[slot_id] = snapshot
	var start: bool = not _worker_running
	_worker_running = true
	_queue_mutex.unlock()
	if start:
		_join_worker()
		_thread = Thread.new()
		_thread.start(_drain_pending)
	return SaveError.OK


## Attend la fin des écritures en file, puis émet leurs résultats. Appelé d'office avant toute lecture
## ou écriture synchrone d'un emplacement : un fichier n'est jamais lu pendant sa rotation.
func flush() -> void:
	_join_worker()
	_deliver_results()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_join_worker()


func _join_worker() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


## Fil de travail : écrit les emplacements en attente un par un, jusqu'à vider la file.
func _drain_pending() -> void:
	while true:
		_queue_mutex.lock()
		if _pending.is_empty():
			_worker_running = false
			_queue_mutex.unlock()
			return
		var slot_id: String = _pending.keys()[0]
		var data: Dictionary = _pending[slot_id]
		_pending.erase(slot_id)
		_queue_mutex.unlock()
		var error: SaveError = _write_slot(slot_id, data)
		_queue_mutex.lock()
		_finished.append([slot_id, error])
		_queue_mutex.unlock()
		_deliver_results.call_deferred()


func _deliver_results() -> void:
	_queue_mutex.lock()
	var results: Array[Array] = _finished.duplicate()
	_finished.clear()
	_queue_mutex.unlock()
	for result: Array in results:
		save_finished.emit(result[0], result[1])


## Écriture atomique d'un emplacement valide (fil principal ou fil de travail, jamais les deux à la fois).
func _write_slot(slot_id: String, data: Dictionary) -> SaveError:
	var payload: String = JSON.stringify(data, "", true, true)
	if payload.is_empty() or JSON.parse_string(payload) == null:
		return SaveError.INVALID_DATA
	var envelope: Dictionary = {
		"format_version": format_version,
		"written_at": Time.get_datetime_string_from_system(true),
		"checksum": payload.sha256_text(),
		"payload": payload,
	}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir)) != OK:
		return SaveError.IO_ERROR
	var path: String = _slot_path(slot_id)
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return SaveError.IO_ERROR
	f.store_string(JSON.stringify(envelope))
	var write_failed: bool = f.get_error() != OK
	f.close()
	if write_failed:
		DirAccess.remove_absolute(tmp)
		return SaveError.IO_ERROR
	# Relecture et validation complète du temporaire avant toute promotion.
	var check: Dictionary = _read_and_validate(tmp)
	if check["error"] != SaveError.OK:
		DirAccess.remove_absolute(tmp)
		return check["error"] as SaveError
	var bak: String = path + BACKUP_SUFFIX
	# Fichiers d'état inconnu (ni écrits ni chargés par cette instance) : un fichier illisible est mis
	# de côté, jamais promu en copie de repli ni supprimé. Aucune relecture en régime établi.
	if not _verified.has(slot_id):
		for existing: String in [path, bak]:
			if not FileAccess.file_exists(existing):
				continue
			var state: Dictionary = _read_and_validate(existing)
			if state["error"] == SaveError.OK:
				continue
			var aside: String = _set_aside(existing)
			if aside.is_empty():
				DirAccess.remove_absolute(tmp)
				return SaveError.IO_ERROR
			push_warning(LOG_PREFIX + "emplacement « %s » : %s inutilisable (%s), conservé sous %s avant la nouvelle sauvegarde."
					% [slot_id, existing.get_file(), state["detail"], aside.get_file()])
	# La sauvegarde précédente (valide) devient la copie de repli.
	var rotated: bool = false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(path, bak) != OK:
			DirAccess.remove_absolute(tmp)
			return SaveError.IO_ERROR
		rotated = true
	if DirAccess.rename_absolute(tmp, path) != OK:
		# Rollback : on remet l'ancienne sauvegarde en place.
		if rotated:
			DirAccess.rename_absolute(bak, path)
		DirAccess.remove_absolute(tmp)
		return SaveError.IO_ERROR
	_verified[slot_id] = true
	_damaged.erase(slot_id)
	return SaveError.OK


## Charge l'emplacement. Résultat : {ok: bool, error: SaveError, data: Dictionary, from_backup: bool,
## damaged: bool}. En cas d'échec, data est toujours vide. Si le principal est inutilisable (absent,
## tronqué, JSON illisible, version inconnue, section manquante), la copie de repli est chargée et un
## avertissement est consigné. Si aucun fichier n'est utilisable : damaged est vrai, une erreur est
## consignée et les fichiers au contenu invalide sont renommés en .corrompu (jamais supprimés ni écrasés).
func load_slot(slot_id: String) -> Dictionary:
	if not _is_valid_slot_id(slot_id):
		return _result(SaveError.INVALID_SLOT_ID, {}, false)
	flush()
	var path: String = _slot_path(slot_id)
	var main: Dictionary = _read_and_validate(path)
	if main["error"] == SaveError.OK:
		_verified[slot_id] = true
		_damaged.erase(slot_id)
		return _result(SaveError.OK, main["data"] as Dictionary, false)
	_verified.erase(slot_id)
	var bak: Dictionary = _read_and_validate(path + BACKUP_SUFFIX)
	if bak["error"] == SaveError.OK:
		_damaged.erase(slot_id)
		push_warning(LOG_PREFIX + "emplacement « %s » : fichier principal inutilisable (%s), copie de repli chargée."
				% [slot_id, main["detail"]])
		return _result(SaveError.OK, bak["data"] as Dictionary, true)
	if main["error"] == SaveError.NOT_FOUND and bak["error"] == SaveError.NOT_FOUND:
		return _result(SaveError.NOT_FOUND, {}, false, is_slot_damaged(slot_id))
	# Aucun fichier utilisable : sauvegarde endommagée.
	_damaged[slot_id] = true
	var report: PackedStringArray = []
	for entry: Array in [[path, main], [path + BACKUP_SUFFIX, bak]]:
		var file_path: String = entry[0]
		var state: Dictionary = entry[1]
		if state["error"] == SaveError.NOT_FOUND:
			continue
		var line: String = "%s : %s" % [file_path.get_file(), state["detail"]]
		if _is_corrupt(state["error"] as SaveError):
			var aside: String = _set_aside(file_path)
			line += ", conservé sous %s" % aside.get_file() if not aside.is_empty() else ", renommage impossible"
		else:
			line += ", laissé en place"
		report.append(line)
	push_error(LOG_PREFIX + "emplacement « %s » : sauvegarde endommagée, aucun fichier utilisable. %s."
			% [slot_id, " ; ".join(report)])
	# On rapporte l'erreur du principal (sauf s'il n'existe pas et que le .bak existe).
	var error: SaveError = main["error"] as SaveError
	if error == SaveError.NOT_FOUND:
		error = bak["error"] as SaveError
	return _result(error, {}, false, true)


func slot_exists(slot_id: String) -> bool:
	if not _is_valid_slot_id(slot_id):
		return false
	flush()
	var path: String = _slot_path(slot_id)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + BACKUP_SUFFIX)


## État « sauvegarde endommagée », lisible par l'écran-titre : vrai si le dernier chargement a échoué
## alors que des fichiers existent, ou si des fichiers ont été mis de côté (.corrompu) sans sauvegarde
## plus récente (persiste d'une session à l'autre). Ne lit aucun contenu de fichier.
func is_slot_damaged(slot_id: String) -> bool:
	if not _is_valid_slot_id(slot_id):
		return false
	flush()
	if _damaged.has(slot_id):
		return true
	var path: String = _slot_path(slot_id)
	return not slot_exists(slot_id) and (FileAccess.file_exists(path + CORRUPT_SUFFIX)
			or FileAccess.file_exists(path + BACKUP_SUFFIX + CORRUPT_SUFFIX))


## Applique les étapes déclarées de from_version jusqu'à format_version.
## Retourne les données migrées, ou null si une étape manque ou échoue.
func _migrate(data: Dictionary, from_version: int) -> Variant:
	var current: Dictionary = data
	for version: int in range(from_version, format_version):
		if not _migrations.has(version):
			return null
		var migrated: Variant = _migrations[version].call(current)
		if not (migrated is Dictionary):
			return null
		current = migrated as Dictionary
	return current


## Vrai si l'erreur prouve un contenu invalide. IO_ERROR, VERSION_TOO_NEW et MIGRATION_FAILED n'en sont
## pas : le fichier peut être intact (lisible plus tard ou par une autre version), il reste en place.
func _is_corrupt(error: SaveError) -> bool:
	return error in [SaveError.INVALID_JSON, SaveError.INVALID_ENVELOPE, SaveError.CHECKSUM_MISMATCH,
			SaveError.VERSION_UNKNOWN]


## Renomme un fichier illisible en .corrompu sans jamais écraser un fichier existant (.corrompu.2, ...).
## Retourne le nouveau chemin, ou "" si le renommage échoue (le fichier reste alors en place).
func _set_aside(path: String) -> String:
	var target: String = path + CORRUPT_SUFFIX
	var n: int = 2
	while FileAccess.file_exists(target):
		target = "%s%s.%d" % [path, CORRUPT_SUFFIX, n]
		n += 1
	return target if DirAccess.rename_absolute(path, target) == OK else ""


func _slot_path(slot_id: String) -> String:
	return save_dir.path_join(slot_id + "." + SLOT_EXTENSION)


func _is_valid_slot_id(slot_id: String) -> bool:
	if slot_id.is_empty() or slot_id.length() > 64:
		return false
	for i in slot_id.length():
		var c: String = slot_id[i]
		var ok: bool = (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" or c == "-"
		if not ok:
			return false
	return true


func _result(error: SaveError, data: Dictionary, from_backup: bool, damaged: bool = false) -> Dictionary:
	return {"ok": error == SaveError.OK, "error": error, "data": data, "from_backup": from_backup, "damaged": damaged}


func _invalid(error: SaveError, detail: String) -> Dictionary:
	return {"error": error, "data": {}, "detail": detail}


## Lit un fichier et valide JSON, enveloppe, version et checksum, puis migre les données si besoin.
## Retourne {error, data, detail} ; detail = motif lisible pour le journal.
func _read_and_validate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _invalid(SaveError.NOT_FOUND, "fichier absent")
	var text: String = FileAccess.get_file_as_string(path)
	if FileAccess.get_open_error() != OK:
		return _invalid(SaveError.IO_ERROR, "lecture impossible")
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return _invalid(SaveError.INVALID_JSON, "JSON illisible, fichier tronqué ou altéré")
	var env: Dictionary = json.data as Dictionary
	for section: String in ENVELOPE_SECTIONS:
		if typeof(env.get(section)) != ENVELOPE_SECTIONS[section]:
			return _invalid(SaveError.INVALID_ENVELOPE, "section « %s » manquante ou invalide" % section)
	var version_f: float = env["format_version"] as float
	if version_f != floorf(version_f) or version_f < 1.0:
		return _invalid(SaveError.VERSION_UNKNOWN, "version de format inconnue (%s)" % version_f)
	var version: int = int(version_f)
	if version > format_version:
		return _invalid(SaveError.VERSION_TOO_NEW,
				"version de format %d plus récente que celle du jeu (%d)" % [version, format_version])
	var payload: String = env["payload"] as String
	if payload.sha256_text() != env["checksum"]:
		return _invalid(SaveError.CHECKSUM_MISMATCH, "somme de contrôle incorrecte, contenu altéré")
	var inner: JSON = JSON.new()
	if inner.parse(payload) != OK or not (inner.data is Dictionary):
		return _invalid(SaveError.INVALID_ENVELOPE, "section « payload » illisible")
	var data: Dictionary = inner.data as Dictionary
	if version < format_version:
		var migrated: Variant = _migrate(data, version)
		if not (migrated is Dictionary):
			return _invalid(SaveError.MIGRATION_FAILED,
					"migration impossible de la version %d vers la version %d" % [version, format_version])
		data = migrated as Dictionary
	return {"error": SaveError.OK, "data": data, "detail": ""}
