extends SceneTree
## Logique de l'écran-titre (GameFlow) : Continuer / Nouvelle partie / sauvegarde endommagée.
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_menu_flow.gd

const SaveServiceScript: GDScript = preload("res://core/save_service.gd")
const TEST_DIR: String = "user://test_menu_saves/"
var _svc: Node
var _failed: bool = false


func _init() -> void:
	_reset()
	# Aucun fichier : Nouvelle partie, sans confirmation.
	_check(GameFlow.slot_state(_svc) == GameFlow.SlotState.EMPTY, "vide -> EMPTY")
	_check(GameFlow.title_entries(GameFlow.SlotState.EMPTY) == ["menu.new_game", "menu.options", "menu.quit"], "entrées vide")
	_check(not GameFlow.new_game_needs_confirmation(GameFlow.SlotState.EMPTY), "pas de confirmation si vide")
	# Sauvegarde lisible : Continuer remplace Nouvelle partie.
	_svc.save_slot(GameFlow.SLOT_ID, {"v": 1})
	_check(GameFlow.slot_state(_svc) == GameFlow.SlotState.CONTINUABLE, "principal -> CONTINUABLE")
	_check(GameFlow.title_entries(GameFlow.SlotState.CONTINUABLE)[0] == "menu.continue", "Continuer")
	# Principal illisible mais .bak lisible : Continuer.
	_svc.save_slot(GameFlow.SLOT_ID, {"v": 2})
	_write("partie.json", "{illisible")
	_check(GameFlow.slot_state(_svc) == GameFlow.SlotState.CONTINUABLE, ".bak lisible -> CONTINUABLE")
	# Tout illisible : endommagée, fichiers mis de côté, jamais supprimés, Continuer absent.
	_write("partie.json.bak", "{illisible")
	var state: GameFlow.SlotState = GameFlow.slot_state(_svc)
	_check(state == GameFlow.SlotState.DAMAGED, "illisibles -> DAMAGED")
	_check(not GameFlow.title_entries(state).has("menu.continue") and GameFlow.title_entries(state)[0] == "menu.new_game", "Nouvelle partie seule")
	_check(GameFlow.new_game_needs_confirmation(state), "confirmation si endommagée")
	_check(FileAccess.file_exists(TEST_DIR + "partie.json.corrompu"), "principal conservé en .corrompu")
	# Nouvelle session (état en mémoire perdu) : toujours endommagée, via les .corrompu.
	_reset(false)
	_check(GameFlow.slot_state(_svc) == GameFlow.SlotState.DAMAGED, "persistant d'une session à l'autre")
	# Continuer : les données ne sont lues que si demandées.
	_reset()
	_svc.save_slot(GameFlow.SLOT_ID, {"v": 3})
	GameFlow.continue_requested = false
	_check(GameFlow.take_continue_data(_svc).is_empty(), "Nouvelle partie ne charge rien")
	GameFlow.continue_requested = true
	_check(GameFlow.take_continue_data(_svc).get("v") == 3 and not GameFlow.continue_requested, "Continuer charge « partie »")
	_clean()
	_svc.free()
	print("test_menu_flow : ", "ÉCHEC" if _failed else "OK")
	quit(1 if _failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed = true
	print("PASS " if ok else "FAIL ", what)


func _reset(clean: bool = true) -> void:
	if clean:
		_clean()
	if _svc != null:
		_svc.free()
	_svc = SaveServiceScript.new()
	_svc.save_dir = TEST_DIR


func _write(file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var f: FileAccess = FileAccess.open(TEST_DIR + file_name, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean() -> void:
	for f: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR + f)
