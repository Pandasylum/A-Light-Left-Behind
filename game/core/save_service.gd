## NB : pas de class_name, Godot interdit qu'il porte le même nom que l'autoload SaveService.
extends Node
## Service de sauvegarde générique : JSON versionné, écriture atomique, copie de secours.
## Ne connaît pas le contenu des données. Un fichier de sauvegarde est NON FIABLE (import possible).

const FORMAT_VERSION: int = 1
const SLOT_EXTENSION: String = "json"

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


## Écrit l'emplacement de façon atomique. Retourne un SaveError.
func save_slot(slot_id: String, data: Dictionary) -> SaveError:
	if not _is_valid_slot_id(slot_id):
		return SaveError.INVALID_SLOT_ID
	var payload: String = JSON.stringify(data, "", true, true)
	if payload.is_empty() or JSON.parse_string(payload) == null:
		return SaveError.INVALID_DATA
	var envelope: Dictionary = {
		"format_version": FORMAT_VERSION,
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
	var bak: String = path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(path, bak) != OK:
			DirAccess.remove_absolute(tmp)
			return SaveError.IO_ERROR
	if DirAccess.rename_absolute(tmp, path) != OK:
		# Rollback : on remet l'ancienne sauvegarde en place.
		if FileAccess.file_exists(bak):
			DirAccess.rename_absolute(bak, path)
		DirAccess.remove_absolute(tmp)
		return SaveError.IO_ERROR
	return SaveError.OK


## Charge l'emplacement. Résultat : {ok: bool, error: SaveError, data: Dictionary, from_backup: bool}.
## En cas d'échec, data est toujours vide.
func load_slot(slot_id: String) -> Dictionary:
	if not _is_valid_slot_id(slot_id):
		return _result(SaveError.INVALID_SLOT_ID, {}, false)
	var path: String = _slot_path(slot_id)
	var main: Dictionary = _read_and_validate(path)
	if main["error"] == SaveError.OK:
		return _result(SaveError.OK, main["data"] as Dictionary, false)
	var bak: Dictionary = _read_and_validate(path + ".bak")
	if bak["error"] == SaveError.OK:
		return _result(SaveError.OK, bak["data"] as Dictionary, true)
	# Les deux échouent : on rapporte l'erreur du principal (sauf s'il n'existe pas et que le .bak existe).
	if main["error"] == SaveError.NOT_FOUND and bak["error"] != SaveError.NOT_FOUND:
		return _result(bak["error"] as SaveError, {}, false)
	return _result(main["error"] as SaveError, {}, false)


func slot_exists(slot_id: String) -> bool:
	if not _is_valid_slot_id(slot_id):
		return false
	var path: String = _slot_path(slot_id)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## Point d'extension des migrations : appelé quand 0 < from_version < FORMAT_VERSION.
## Aucune migration pour l'instant ; retourne les données migrées ou {} en cas d'échec.
func _migrate(_data: Dictionary, _from_version: int) -> Dictionary:
	return {}


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


func _result(error: SaveError, data: Dictionary, from_backup: bool) -> Dictionary:
	return {"ok": error == SaveError.OK, "error": error, "data": data, "from_backup": from_backup}


## Lit un fichier et valide JSON, enveloppe, version et checksum. Retourne {error, data}.
func _read_and_validate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": SaveError.NOT_FOUND, "data": {}}
	var text: String = FileAccess.get_file_as_string(path)
	if FileAccess.get_open_error() != OK:
		return {"error": SaveError.IO_ERROR, "data": {}}
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {"error": SaveError.INVALID_JSON, "data": {}}
	var env: Dictionary = json.data as Dictionary
	if not (env.get("format_version") is float) or not (env.get("written_at") is String) \
			or not (env.get("checksum") is String) or not (env.get("payload") is String):
		return {"error": SaveError.INVALID_ENVELOPE, "data": {}}
	var version_f: float = env["format_version"] as float
	if version_f != floorf(version_f) or version_f < 1.0:
		return {"error": SaveError.VERSION_UNKNOWN, "data": {}}
	var version: int = int(version_f)
	if version > FORMAT_VERSION:
		return {"error": SaveError.VERSION_TOO_NEW, "data": {}}
	var payload: String = env["payload"] as String
	if payload.sha256_text() != env["checksum"]:
		return {"error": SaveError.CHECKSUM_MISMATCH, "data": {}}
	var inner: JSON = JSON.new()
	if inner.parse(payload) != OK or not (inner.data is Dictionary):
		return {"error": SaveError.INVALID_ENVELOPE, "data": {}}
	var data: Dictionary = inner.data as Dictionary
	if version < FORMAT_VERSION:
		data = _migrate(data, version)
		if data.is_empty():
			return {"error": SaveError.MIGRATION_FAILED, "data": {}}
	return {"error": SaveError.OK, "data": data}
