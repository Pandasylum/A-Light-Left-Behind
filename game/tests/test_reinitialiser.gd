extends Node
## « Réinitialiser la partie » : SaveService.reset_slot et écran Options (titre / pause), emplacement temporaire.
## Scène (et non --script) : l'écran Options a besoin de l'autoload Settings.
## Lancer : tools/godot.sh --headless --path game res://tests/test_reinitialiser.tscn

const SaveServiceScript: GDScript = preload("res://core/save_service.gd")
const OPTIONS_SCENE: PackedScene = preload("res://ui/menu/options_screen.tscn")
const TITLE_SCENE: PackedScene = preload("res://ui/menu/title_screen.tscn")
const TEST_DIR: String = "user://test_reset_saves/"
const R := SaveServiceScript.ResetResult
var _svc: Node
var _failed: bool = false


func _ready() -> void:
	_run.call_deferred() # la racine est occupée pendant _ready


func _run() -> void:
	_clean()
	_svc = SaveServiceScript.new()
	_svc.save_dir = TEST_DIR
	_case_service()
	_case_options()
	_case_quit_from_title()
	_clean()
	_svc.free()
	print("RESULTAT : ", "ECHEC" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL "), what)
	_failed = _failed or not ok


func _has(file_name: String) -> bool:
	return FileAccess.file_exists(TEST_DIR + file_name)


func _write(file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var f: FileAccess = FileAccess.open(TEST_DIR + file_name, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		dir.remove(f)


## Deux écritures valides : principal + .bak.
func _two_saves() -> void:
	_svc.save_slot("partie", {"a": 1})
	_svc.save_slot("partie", {"a": 2})


func _case_service() -> void:
	_clean()
	_check(_svc.reset_slot("partie") == R.NOTHING and not _svc.slot_exists("partie"), "aucun fichier : rien à faire")
	_two_saves()
	_write("settings.cfg", "[x]\na=1\n")
	_check(_has("partie.json") and _has("partie.json.bak") and _svc.slot_exists("partie"), "deux fichiers présents")
	_check(_svc.reset_slot("partie") == R.DELETED, "fichiers lisibles : supprimés")
	_check(not _has("partie.json") and not _has("partie.json.bak") and not _svc.slot_exists("partie"), "principal et .bak absents")
	_check(_has("settings.cfg") and FileAccess.get_file_as_string(TEST_DIR + "settings.cfg") == "[x]\na=1\n", "settings.cfg intact")
	_check(not _has("partie.json.corrompu"), "aucun .corrompu créé pour des fichiers lisibles")
	# Principal illisible + .bak lisible : principal conservé en .corrompu, .bak supprimé.
	_clean()
	_two_saves()
	_write("partie.json", "{ tronqué")
	_check(_svc.reset_slot("partie") == R.KEPT_CORRUPT, "principal illisible : conservé")
	_check(not _has("partie.json") and _has("partie.json.corrompu") and not _has("partie.json.bak"), "principal -> .corrompu, .bak lisible supprimé")
	_check(FileAccess.get_file_as_string(TEST_DIR + "partie.json.corrompu") == "{ tronqué", "contenu du .corrompu conservé")
	# Un .corrompu existant n'est jamais écrasé.
	_clean()
	_write("partie.json.corrompu", "ancien")
	_write("partie.json", "nouveau illisible")
	_check(_svc.reset_slot("partie") == R.KEPT_CORRUPT, "illisible avec .corrompu existant")
	_check(FileAccess.get_file_as_string(TEST_DIR + "partie.json.corrompu") == "ancien", ".corrompu existant non écrasé")
	_check(FileAccess.get_file_as_string(TEST_DIR + "partie.json.corrompu.2") == "nouveau illisible", "nouveau renommé en .corrompu.2")
	# .bak illisible seul.
	_clean()
	_write("partie.json.bak", "x")
	_check(_svc.reset_slot("partie") == R.KEPT_CORRUPT and _has("partie.json.bak.corrompu") and not _has("partie.json.bak"), ".bak illisible conservé")
	_check(_svc.reset_slot("zz zz") == R.NOTHING, "emplacement invalide : rien")


func _find_reset_button(options: Node) -> Button:
	for b: Node in options.find_children("*", "Button", true, false):
		if (b as Button).text == "options.reset_game" or (b as Button).text == tr("options.reset_game"):
			return b as Button
	return null


func _open(from_title: bool) -> Control:
	var options: Control = OPTIONS_SCENE.instantiate()
	options.set("opened_from_title", from_title)
	options.set("save_service", _svc)
	options.set("slot_id", "partie")
	get_tree().root.add_child(options)
	return options


func _case_options() -> void:
	_clean()
	_two_saves()
	var pause: Control = _open(false)
	_check(_find_reset_button(pause) == null, "pause : aucun bouton Réinitialiser")
	pause.free()
	var title: Control = _open(true)
	var button: Button = _find_reset_button(title)
	_check(button != null and not button.disabled, "titre avec sauvegarde : bouton actif")
	title.free()
	_svc.reset_slot("partie")
	title = _open(true)
	button = _find_reset_button(title)
	_check(button != null and button.disabled, "titre sans sauvegarde : bouton grisé")
	title.free()
	# Confirmation : annulation par défaut, rien n'est supprimé avant la validation.
	_two_saves()
	title = _open(true)
	title.call("_ask_reset")
	_check((title.get("_reset_confirm") as ConfirmationDialog).visible, "alerte affichée")
	_check((title.get("_reset_confirm") as ConfirmationDialog).get_cancel_button().has_focus() or (title.get("_reset_confirm") as ConfirmationDialog).get_cancel_button().is_visible_in_tree(), "Annuler présent")
	_check(_has("partie.json"), "rien supprimé avant validation")
	var closed: Array[bool] = [false]
	title.closed.connect(func() -> void: closed[0] = true)
	title.call("_do_reset")
	_check(closed[0] and title.get("save_was_reset") and not _svc.slot_exists("partie"), "validation : supprimé, écran fermé")
	title.free()


## Point 3 : le titre n'a ni Autosave ni interception de fermeture ; quitter n'écrit rien.
func _case_quit_from_title() -> void:
	_clean()
	var screen: Node = TITLE_SCENE.instantiate()
	get_tree().root.add_child(screen)
	_check(screen.find_children("*", "Autosave", true, false).is_empty(), "titre : aucun Autosave")
	_check(get_tree().auto_accept_quit, "titre : fermeture non interceptée")
	screen.free()
	_check(not _has("partie.json"), "aucun fichier de sauvegarde créé")
