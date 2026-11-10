extends SceneTree
## Test du SaveService. Lancer : tools/godot.sh --headless --path game --script res://tests/save_roundtrip_test.gd

const SaveServiceScript: GDScript = preload("res://core/save_service.gd")
const TEST_DIR: String = "user://test_saves/"
var _svc: Node


func _init() -> void:
	_svc = SaveServiceScript.new()
	_svc.save_dir = TEST_DIR
	var cases: Array[Callable] = [
		_case_roundtrip, _case_backup_restore, _case_tampered_byte, _case_newer_version,
	]
	for c: Callable in cases:
		_clean()
		var err: String = c.call()
		if err != "":
			print("FAIL ", c.get_method(), " : ", err)
			_clean()
			quit(1)
			return
		print("PASS ", c.get_method())
	_clean()
	_svc.free()
	quit(0)


func _clean() -> void:
	var abs_dir: String = ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir.path_join(f))
		DirAccess.remove_absolute(abs_dir)


func _case_roundtrip() -> String:
	var data: Dictionary = {
		"floats": [0.1, 1.0 / 3.0, -0.0001], "int": 42, "text": "Lumière éteinte à l'étage — ça va",
		"nested": {"a": [1, 2, {"b": [true, null, "é"]}], "pos": [1.5, 2.25, -3.0]},
	}
	if _svc.save_slot("slot1", data) != SaveServiceScript.SaveError.OK:
		return "save a échoué"
	if not _svc.slot_exists("slot1") or _svc.slot_exists("autre"):
		return "slot_exists incorrect"
	var r: Dictionary = _svc.load_slot("slot1")
	if not r["ok"] or r["from_backup"]:
		return "load a échoué ou from_backup levé"
	var d: Dictionary = r["data"]
	var fl: Array = d["floats"]
	if fl[0] != 0.1 or fl[1] != 1.0 / 3.0 or fl[2] != -0.0001:
		return "flottants altérés : %s" % [fl]
	if int(d["int"]) != 42 or d["text"] != data["text"]:
		return "entier ou texte altéré"
	var inner: Dictionary = (d["nested"] as Dictionary)
	var arr: Array = inner["a"]
	if int(arr[0]) != 1 or ((arr[2] as Dictionary)["b"] as Array)[2] != "é" or inner["pos"] != [1.5, 2.25, -3.0]:
		return "imbrication altérée"
	return ""


func _case_backup_restore() -> String:
	_svc.save_slot("s", {"v": "ancienne"})
	_svc.save_slot("s", {"v": "nouvelle"})
	var path: String = TEST_DIR + "s.json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ corrompu")
	f.close()
	var r: Dictionary = _svc.load_slot("s")
	if not r["ok"] or not r["from_backup"]:
		return "restauration depuis .bak non effectuée"
	if (r["data"] as Dictionary)["v"] != "ancienne":
		return "mauvaises données de secours"
	return ""


func _case_tampered_byte() -> String:
	_svc.save_slot("t", {"hp": 10, "nom": "abc"})
	var path: String = TEST_DIR + "t.json"
	var text: String = FileAccess.get_file_as_string(path)
	var idx: int = text.find("abc")
	if idx < 0:
		return "motif introuvable"
	text = text.substr(0, idx) + "abd" + text.substr(idx + 3)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var r: Dictionary = _svc.load_slot("t")
	if r["ok"] or r["error"] != SaveServiceScript.SaveError.CHECKSUM_MISMATCH or not (r["data"] as Dictionary).is_empty():
		return "octet modifié non rejeté proprement"
	return ""


func _case_newer_version() -> String:
	_svc.save_slot("n", {"x": 1})
	var path: String = TEST_DIR + "n.json"
	var env: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	env["format_version"] = SaveServiceScript.FORMAT_VERSION + 1
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(env))
	f.close()
	var r: Dictionary = _svc.load_slot("n")
	if r["ok"] or r["error"] != SaveServiceScript.SaveError.VERSION_TOO_NEW or not (r["data"] as Dictionary).is_empty():
		return "version plus récente non rejetée"
	return ""
