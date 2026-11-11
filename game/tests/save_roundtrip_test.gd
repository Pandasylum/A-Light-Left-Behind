extends SceneTree
## Test du SaveService. Lancer : tools/godot.sh --headless --path game --script res://tests/save_roundtrip_test.gd

const SaveServiceScript: GDScript = preload("res://core/save_service.gd")
const TEST_DIR: String = "user://test_saves/"
const E := SaveServiceScript.SaveError
## Un fichier figé par version de format existante (contenu exact écrit par cette version).
## À chaque hausse de FORMAT_VERSION : ajouter ici le fichier de l'ancienne version.
const VERSION_FIXTURES: Dictionary[int, String] = {
	1: r'{"format_version":1,"written_at":"2026-11-10T12:00:00","checksum":"7ae457d308d09a45233a9724bba3f05bd2f00b029b76306b23844a03a5cb7da2","payload":"{\"compteur\":3,\"nom\":\"tour\"}"}',
}
var _svc: Node


func _init() -> void:
	var cases: Array[Callable] = [
		_case_roundtrip, _case_backup_restore, _case_tampered_byte, _case_newer_version,
		_case_truncated_file, _case_invalid_json, _case_unknown_version, _case_missing_section,
		_case_main_deleted, _case_both_unreadable, _case_save_keeps_valid_backup,
		_case_every_version_loads, _case_migration_chain,
	]
	for c: Callable in cases:
		_clean()
		_new_service()
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


## Nouvelle instance : aucun état en mémoire, comme après un redémarrage du jeu.
func _new_service() -> void:
	if _svc != null:
		_svc.free()
	_svc = SaveServiceScript.new()
	_svc.save_dir = TEST_DIR


func _write(file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var f: FileAccess = FileAccess.open(TEST_DIR + file_name, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(file_name: String) -> String:
	return FileAccess.get_file_as_string(TEST_DIR + file_name)


func _has(file_name: String) -> bool:
	return FileAccess.file_exists(TEST_DIR + file_name)


## Deux sauvegardes : principal = « nouvelle », copie de repli = « ancienne ».
func _save_twice(slot: String) -> void:
	_svc.save_slot(slot, {"v": "ancienne"})
	_svc.save_slot(slot, {"v": "nouvelle"})


## Vérifie un repli réussi sur la copie, sans fichier renommé ni état endommagé.
func _expect_fallback(slot: String) -> String:
	var r: Dictionary = _svc.load_slot(slot)
	if not r["ok"] or not r["from_backup"] or r["damaged"] or (r["data"] as Dictionary).get("v") != "ancienne":
		return "repli sur la copie non effectué : %s" % [r]
	if _svc.is_slot_damaged(slot) or _has(slot + ".json.corrompu") or not _has(slot + ".json.bak"):
		return "le repli ne doit ni renommer de fichier ni lever l'état endommagé"
	return ""


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


func _case_truncated_file() -> String:
	_save_twice("tr")
	var text: String = _read("tr.json")
	_write("tr.json", text.substr(0, text.length() / 2))
	return _expect_fallback("tr")


func _case_invalid_json() -> String:
	_save_twice("j")
	_write("j.json", "ceci n'est pas du JSON")
	var err: String = _expect_fallback("j")
	if err != "":
		return err
	# Sans copie de repli : erreur propre, données vides.
	_svc.save_slot("j2", {"v": 1})
	_write("j2.json", "[1, 2")
	var r: Dictionary = _svc.load_slot("j2")
	if r["ok"] or r["error"] != E.INVALID_JSON or not (r["data"] as Dictionary).is_empty() or not r["damaged"]:
		return "JSON invalide sans copie non rejeté proprement : %s" % [r]
	return ""


func _case_unknown_version() -> String:
	for version: Variant in [0, 1.5, -2]:
		_clean()
		_new_service()
		_save_twice("u")
		var env: Dictionary = JSON.parse_string(_read("u.json"))
		env["format_version"] = version
		_write("u.json", JSON.stringify(env))
		var err: String = _expect_fallback("u")
		if err != "":
			return "version %s : %s" % [version, err]
		_svc.save_slot("u2", {"v": 1})
		env = JSON.parse_string(_read("u2.json"))
		env["format_version"] = version
		_write("u2.json", JSON.stringify(env))
		var r: Dictionary = _svc.load_slot("u2")
		if r["ok"] or r["error"] != E.VERSION_UNKNOWN or not (r["data"] as Dictionary).is_empty():
			return "version %s non rejetée comme inconnue : %s" % [version, r]
	return ""


func _case_missing_section() -> String:
	for section: String in ["format_version", "written_at", "checksum", "payload"]:
		_clean()
		_new_service()
		_save_twice("m")
		var env: Dictionary = JSON.parse_string(_read("m.json"))
		env.erase(section)
		_write("m.json", JSON.stringify(env))
		var err: String = _expect_fallback("m")
		if err != "":
			return "section %s : %s" % [section, err]
		_svc.save_slot("m2", {"v": 1})
		env = JSON.parse_string(_read("m2.json"))
		env.erase(section)
		_write("m2.json", JSON.stringify(env))
		var r: Dictionary = _svc.load_slot("m2")
		if r["ok"] or r["error"] != E.INVALID_ENVELOPE or not (r["data"] as Dictionary).is_empty():
			return "section %s manquante non rejetée : %s" % [section, r]
	return ""


func _case_main_deleted() -> String:
	_save_twice("d")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + "d.json"))
	var err: String = _expect_fallback("d")
	if err != "" or not _svc.slot_exists("d"):
		return "principal supprimé : %s" % err
	return ""


func _case_both_unreadable() -> String:
	_save_twice("b")
	var main_text: String = _read("b.json").substr(0, 40)
	var bak_text: String = "{ copie corrompue"
	_write("b.json", main_text)
	_write("b.json.bak", bak_text)
	var r: Dictionary = _svc.load_slot("b")
	if r["ok"] or r["error"] != E.INVALID_JSON or not r["damaged"] or not (r["data"] as Dictionary).is_empty():
		return "principal et copie illisibles : résultat inattendu %s" % [r]
	if _has("b.json") or _has("b.json.bak"):
		return "les fichiers illisibles doivent être renommés"
	if _read("b.json.corrompu") != main_text or _read("b.json.bak.corrompu") != bak_text:
		return "les fichiers .corrompu doivent conserver le contenu d'origine"
	if not _svc.is_slot_damaged("b") or _svc.slot_exists("b"):
		return "état endommagé non exposé après la mise de côté"
	# L'état persiste après un redémarrage (aucun état en mémoire), y compris via load_slot.
	_new_service()
	r = _svc.load_slot("b")
	if not _svc.is_slot_damaged("b") or r["error"] != E.NOT_FOUND or not r["damaged"]:
		return "état endommagé perdu après redémarrage : %s" % [r]
	if _svc.is_slot_damaged("jamais_ecrit") or _svc.load_slot("jamais_ecrit")["damaged"]:
		return "un emplacement vierge ne doit pas être signalé endommagé"
	# Une nouvelle corruption ne doit jamais écraser un fichier déjà mis de côté.
	_write("b.json", "deuxième corruption")
	_svc.load_slot("b")
	if _read("b.json.corrompu") != main_text or _read("b.json.corrompu.2") != "deuxième corruption":
		return "un fichier .corrompu existant a été écrasé"
	# Une nouvelle sauvegarde réussit, lève l'état, et ne touche pas aux fichiers mis de côté.
	if _svc.save_slot("b", {"v": "repartie"}) != E.OK or _svc.is_slot_damaged("b"):
		return "nouvelle sauvegarde impossible ou état endommagé conservé"
	r = _svc.load_slot("b")
	if not r["ok"] or r["damaged"] or (r["data"] as Dictionary)["v"] != "repartie":
		return "relecture après nouvelle sauvegarde incorrecte"
	if _read("b.json.corrompu") != main_text or _read("b.json.bak.corrompu") != bak_text:
		return "la nouvelle sauvegarde a modifié les fichiers mis de côté"
	return ""


## Une sauvegarde par-dessus un principal illisible ne doit pas détruire la copie de repli valide.
func _case_save_keeps_valid_backup() -> String:
	# Cas 1 : chargement (repli) puis sauvegarde, dans la même session.
	_save_twice("k")
	_write("k.json", "tronqué")
	var err: String = _expect_fallback("k")
	if err != "":
		return err
	if _svc.save_slot("k", {"v": "troisième"}) != E.OK:
		return "sauvegarde après repli impossible"
	if _read("k.json.corrompu") != "tronqué":
		return "le principal illisible doit être mis de côté, pas promu en copie de repli"
	_write("k.json", "tronqué de nouveau")
	var r: Dictionary = _svc.load_slot("k")
	if not r["ok"] or not r["from_backup"] or (r["data"] as Dictionary).get("v") != "ancienne":
		return "copie de repli valide perdue : %s" % [r]
	# Cas 2 : sauvegarde sans chargement préalable (nouvelle instance), principal et copie illisibles.
	_clean()
	_new_service()
	_save_twice("k")
	_write("k.json", "principal illisible")
	_write("k.json.bak", "copie illisible")
	_new_service()
	if _svc.save_slot("k", {"v": "quatrième"}) != E.OK:
		return "sauvegarde par-dessus des fichiers illisibles impossible"
	if _read("k.json.corrompu") != "principal illisible" or _read("k.json.bak.corrompu") != "copie illisible":
		return "fichiers illisibles supprimés ou écrasés par la sauvegarde"
	r = _svc.load_slot("k")
	if not r["ok"] or r["from_backup"] or (r["data"] as Dictionary)["v"] != "quatrième":
		return "relecture incorrecte après sauvegarde par-dessus des fichiers illisibles"
	# Cas 3 : régime établi, la sauvegarde précédente devient la copie de repli.
	_svc.save_slot("k", {"v": "cinquième"})
	r = JSON.parse_string(JSON.parse_string(_read("k.json.bak"))["payload"])
	if r.get("v") != "quatrième":
		return "la sauvegarde précédente n'est pas conservée comme copie de repli"
	return ""


## Chaque version de format existante se charge avec la version courante (migrations réelles).
func _case_every_version_loads() -> String:
	for version: int in range(1, SaveServiceScript.FORMAT_VERSION + 1):
		if not VERSION_FIXTURES.has(version):
			return "aucun fichier figé pour la version de format %d" % version
		_clean()
		_new_service()
		_write("v.json", VERSION_FIXTURES[version])
		var r: Dictionary = _svc.load_slot("v")
		if not r["ok"] or r["from_backup"] or r["damaged"]:
			return "fichier de version %d non chargé : %s" % [version, r]
		var d: Dictionary = r["data"]
		if d.get("nom") != "tour" or d.get("compteur") != 3:
			return "données de la version %d mal migrées : %s" % [version, d]
	return ""


## Mécanisme de migration : étapes enchaînées depuis chaque version existante vers une version future.
func _case_migration_chain() -> String:
	var future: int = SaveServiceScript.FORMAT_VERSION + 2
	var step: Callable = func(data: Dictionary) -> Dictionary:
		var out: Dictionary = data.duplicate(true)
		out["etapes"] = int(out.get("etapes", 0)) + 1
		return out
	for version: int in VERSION_FIXTURES:
		_clean()
		_new_service()
		_svc.format_version = future
		for from: int in range(SaveServiceScript.FORMAT_VERSION, future):
			_svc.register_migration(from, step)
		_write("g.json", VERSION_FIXTURES[version])
		var r: Dictionary = _svc.load_slot("g")
		var d: Dictionary = r["data"]
		if not r["ok"] or d.get("nom") != "tour" or d.get("etapes") != future - SaveServiceScript.FORMAT_VERSION:
			return "version %d non migrée par toutes les étapes : %s" % [version, r]
		# Après migration, la sauvegarde s'écrit dans la version courante et se relit sans migration.
		if _svc.save_slot("g", d) != E.OK or int(JSON.parse_string(_read("g.json"))["format_version"]) != future:
			return "réécriture dans la version courante incorrecte"
		if _read("g.json.bak") != VERSION_FIXTURES[version]:
			return "le fichier d'origine doit rester intact comme copie de repli"
		if (_svc.load_slot("g")["data"] as Dictionary).get("etapes") != d["etapes"]:
			return "un fichier à la version courante ne doit pas être migré"
	# Étape manquante ou en échec : erreur propre, fichier intact laissé en place (pas .corrompu).
	for broken: Variant in [null, func(_data: Dictionary) -> Variant: return null]:
		_clean()
		_new_service()
		_svc.format_version = SaveServiceScript.FORMAT_VERSION + 1
		if broken != null:
			_svc.register_migration(SaveServiceScript.FORMAT_VERSION, broken as Callable)
		_write("g.json", VERSION_FIXTURES[SaveServiceScript.FORMAT_VERSION])
		var r: Dictionary = _svc.load_slot("g")
		if r["ok"] or r["error"] != E.MIGRATION_FAILED or not r["damaged"] or not (r["data"] as Dictionary).is_empty():
			return "échec de migration non rejeté proprement : %s" % [r]
		if not _has("g.json") or _has("g.json.corrompu") or not _svc.is_slot_damaged("g"):
			return "un fichier intact non migrable doit rester en place et être signalé"
	return ""
