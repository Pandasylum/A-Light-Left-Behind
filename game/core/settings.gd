extends Node
## Autoload Settings (sans class_name, conflit Godot) : réglages joueur dans user://settings.cfg.
## Valeurs par défaut, bornes et pas : res://data/settings_defaults.json ; langues : res://data/languages.json ;
## actions de jeu modifiables : res://data/controls_actions.json (pause_menu et ui_* exclues).
## Touches : une seule par action (clavier par physical_keycode, ou bouton de souris), échange si la touche est prise.
## Le fichier ne garde que les écarts aux événements par défaut de l'Input Map ([controls], « key:70 » ou « mouse:2 »).
## Signal changed : touches, sensibilité, inversion, champ de vision (les scripts réagissent, sans interroger en boucle).
## Chargement tolérant (fichier absent/illisible/valeur hors bornes = défaut). Écriture atomique sans thread,
## seulement via save() (fermeture de l'écran Options) et à la sortie de l'arbre (fin du jeu).

const DEFAULTS_PATH := "res://data/settings_defaults.json"
const LANGUAGES_PATH := "res://data/languages.json"
const SETTINGS_PATH := "user://settings.cfg"
const CONTROLS_PATH := "res://data/controls_actions.json"
const VOLUME_KEYS: Array[String] = ["master", "music", "ambience", "effects"]
const TYPE_KEY := "key"
const TYPE_MOUSE := "mouse"
const MOUSE_BUTTON_MAX: int = 9 ## MOUSE_BUTTON_XBUTTON2 ; molette = 4 à 7 (non assignable à la capture, valide au chargement)
const KEYCODE_LIMIT: int = 0x7FFFFF ## exclut KEY_UNKNOWN et les bits de modificateurs

signal changed

var fullscreen: bool = true
var vsync: bool = true
var window_size: Vector2i = Vector2i(1280, 720)
var volumes: Dictionary = {}
var look_sensitivity: float = 1.0 ## multiplicateur de la sensibilité de base du joueur
var invert_y: bool = false
var fov: int = 80 ## degrés (vertical)

var _cfg: Dictionary = {}
var _languages: Array = []
var _language: String = ""
var _language_chosen: bool = false
var _editable: Array = [] ## [{action: StringName, label_key: String}]
var _default_events: Dictionary = {} ## action -> Array[InputEvent] (copie des événements de project.godot)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = _read_json(DEFAULTS_PATH, {}) as Dictionary
	var langs: Variant = _read_json(LANGUAGES_PATH, [])
	_languages = langs as Array if langs is Array else []
	_load_editable_actions()
	_capture_default_events()
	var min_size: Array = _cfg.get("min_window_size", [960, 540])
	get_window().min_size = Vector2i(int(min_size[0]), int(min_size[1]))
	load_settings(SETTINGS_PATH)
	apply_all()


func _exit_tree() -> void:
	save()


## Langues disponibles : Array de {code, name}.
func languages() -> Array:
	return _languages


func language() -> String:
	return _language


func volume_range() -> Dictionary:
	return _cfg.get("volume", {}) as Dictionary


func sensitivity_range() -> Dictionary:
	return (_cfg.get("camera", {}) as Dictionary).get("sensitivity", {}) as Dictionary


func fov_range() -> Dictionary:
	return (_cfg.get("camera", {}) as Dictionary).get("fov", {}) as Dictionary


## Actions de jeu modifiables, dans l'ordre d'affichage : Array de {action: StringName, label_key: String}.
func editable_actions() -> Array:
	return _editable.duplicate()


## Lit le fichier ; toute anomalie donne la valeur par défaut, sans erreur.
func load_settings(path: String) -> void:
	_set_defaults()
	var file: ConfigFile = ConfigFile.new()
	if file.load(path) != OK:
		return
	var fs: Variant = file.get_value("display", "fullscreen", "")
	if fs is bool:
		fullscreen = fs
	var vs: Variant = file.get_value("display", "vsync", "")
	if vs is bool:
		vsync = vs
	var w: Variant = file.get_value("display", "window_width", "")
	var h: Variant = file.get_value("display", "window_height", "")
	if w is int and h is int and w >= get_window().min_size.x and h >= get_window().min_size.y and w <= 16384 and h <= 16384:
		window_size = Vector2i(w, h)
	for key: String in VOLUME_KEYS:
		var v: Variant = file.get_value("audio", key, "")
		if (v is int or v is float) and _volume_valid(float(v)):
			volumes[key] = _snap(float(v))
	var lang: Variant = file.get_value("language", "code", "")
	if lang is String and _has_language(lang):
		_language = lang
		_language_chosen = true
	_load_camera(file)
	_load_controls(file)
	changed.emit()


## Écriture atomique : fichier temporaire puis renommage. Écrase un fichier illisible.
func save(path: String = SETTINGS_PATH) -> bool:
	if not fullscreen and DisplayServer.get_name() != "headless":
		window_size = get_window().size
	var file: ConfigFile = ConfigFile.new()
	file.set_value("display", "fullscreen", fullscreen)
	file.set_value("display", "vsync", vsync)
	file.set_value("display", "window_width", window_size.x)
	file.set_value("display", "window_height", window_size.y)
	for key: String in VOLUME_KEYS:
		file.set_value("audio", key, volumes[key])
	if _language_chosen:
		file.set_value("language", "code", _language)
	file.set_value("camera", "sensitivity", look_sensitivity)
	file.set_value("camera", "invert_y", invert_y)
	file.set_value("camera", "fov", fov)
	for entry: Variant in _editable:
		var action: StringName = (entry as Dictionary)["action"]
		var current: Dictionary = binding_of(action)
		if not current.is_empty() and not _same_binding(current, default_binding_of(action)):
			file.set_value("controls", action, "%s:%d" % [current["type"], current["code"]])
	var tmp: String = path + ".tmp"
	if file.save(tmp) != OK:
		return false
	return DirAccess.rename_absolute(tmp, path) == OK


func apply_all() -> void:
	_apply_language()
	_apply_display()
	for key: String in VOLUME_KEYS:
		_apply_volume(key)


func set_fullscreen(value: bool) -> void:
	if fullscreen == value:
		return
	if value and not fullscreen and DisplayServer.get_name() != "headless":
		window_size = get_window().size
	fullscreen = value
	_apply_display()


func set_vsync(value: bool) -> void:
	vsync = value
	_apply_vsync()


func set_volume(key: String, value: float) -> void:
	if not volumes.has(key):
		return
	var range_: Dictionary = volume_range()
	volumes[key] = _snap(clampf(value, float(range_.get("min", 0)), float(range_.get("max", 100))))
	_apply_volume(key)


func set_look_sensitivity(value: float) -> void:
	var range_: Dictionary = sensitivity_range()
	var snapped_value: float = _snap_float(clampf(value, float(range_.get("min", 0.2)), float(range_.get("max", 3.0))),
			float(range_.get("step", 0.1)))
	if is_equal_approx(snapped_value, look_sensitivity):
		return
	look_sensitivity = snapped_value
	changed.emit()


func set_invert_y(value: bool) -> void:
	if invert_y == value:
		return
	invert_y = value
	changed.emit()


func set_fov(value: float) -> void:
	var range_: Dictionary = fov_range()
	var snapped_value: int = int(snappedf(clampf(value, float(range_.get("min", 70)), float(range_.get("max", 95))),
			float(range_.get("step", 1))))
	if snapped_value == fov:
		return
	fov = snapped_value
	changed.emit()


## Touche actuelle d'une action modifiable : {type: "key"|"mouse", code: int} ({} si aucune).
## Clavier : physical_keycode ; souris : numéro de bouton.
func binding_of(action: StringName) -> Dictionary:
	return _binding_from_events(InputMap.action_get_events(action))


## Touche des événements par défaut de l'Input Map ({} si l'action n'est pas modifiable).
func default_binding_of(action: StringName) -> Dictionary:
	return _binding_from_events(_default_events.get(action, []) as Array)


func is_editable(action: StringName) -> bool:
	for entry: Variant in _editable:
		if (entry as Dictionary)["action"] == action:
			return true
	return false


## Binding assignable : touche clavier (hors Échap, réservée à pause_menu) ou bouton de souris 1 à 9.
func is_binding_valid(binding: Dictionary) -> bool:
	var code: Variant = binding.get("code", null)
	if not code is int:
		return false
	match binding.get("type", ""):
		TYPE_KEY:
			return code > 0 and code < KEYCODE_LIMIT and code != KEY_ESCAPE
		TYPE_MOUSE:
			return code >= MOUSE_BUTTON_LEFT and code <= MOUSE_BUTTON_MAX
	return false


## Assigne une touche à une action modifiable. Si une autre action l'a déjà, elle reçoit l'ancienne touche
## de celle-ci (échange). Retourne false (rien ne change) si l'action ou la touche est invalide.
func set_binding(action: StringName, binding: Dictionary) -> bool:
	if not is_editable(action) or not is_binding_valid(binding):
		return false
	if _same_binding(binding_of(action), binding):
		return true
	_assign(action, binding)
	changed.emit()
	return true


## Remet les événements par défaut de toutes les actions modifiables (ne touche pas aux autres réglages).
func reset_controls() -> void:
	_restore_default_events()
	changed.emit()


## Un choix du joueur : seul cas où la langue est écrite dans le fichier.
func set_language(code: String) -> void:
	if not _has_language(code) or code == _language:
		return
	_language = code
	_language_chosen = true
	_apply_language()


func _set_defaults() -> void:
	fullscreen = bool(_cfg.get("fullscreen", true))
	vsync = bool(_cfg.get("vsync", true))
	var ws: Array = _cfg.get("window_size", [1280, 720])
	window_size = Vector2i(int(ws[0]), int(ws[1]))
	volumes = {}
	var defaults: Dictionary = volume_range().get("defaults", {}) as Dictionary
	for key: String in VOLUME_KEYS:
		volumes[key] = int(defaults.get(key, 100))
	var camera: Dictionary = _cfg.get("camera", {}) as Dictionary
	look_sensitivity = float(sensitivity_range().get("default", 1.0))
	invert_y = bool(camera.get("invert_y", false))
	fov = int(fov_range().get("default", 80))
	_restore_default_events()
	_language = _system_language()
	_language_chosen = false


func _load_camera(file: ConfigFile) -> void:
	var s_range: Dictionary = sensitivity_range()
	var s: Variant = file.get_value("camera", "sensitivity", "")
	if (s is int or s is float) and _in_range(float(s), s_range, 0.2, 3.0):
		look_sensitivity = _snap_float(float(s), float(s_range.get("step", 0.1)))
	var inv: Variant = file.get_value("camera", "invert_y", "")
	if inv is bool:
		invert_y = inv
	var f_range: Dictionary = fov_range()
	var f: Variant = file.get_value("camera", "fov", "")
	if (f is int or f is float) and _in_range(float(f), f_range, 70.0, 95.0):
		fov = int(snappedf(float(f), float(f_range.get("step", 1))))


## Applique les écarts du fichier un par un, avec la règle d'échange : la table finale reste sans doublon.
## Action inconnue/non modifiable ou touche invalide : ignorée (défaut conservé).
func _load_controls(file: ConfigFile) -> void:
	if not file.has_section("controls"):
		return
	for key: String in file.get_section_keys("controls"):
		var action: StringName = StringName(key)
		if not is_editable(action):
			continue
		var binding: Dictionary = _parse_binding(file.get_value("controls", key, ""))
		if not binding.is_empty():
			_assign(action, binding)


func _parse_binding(value: Variant) -> Dictionary:
	if not value is String:
		return {}
	var parts: PackedStringArray = (value as String).split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return {}
	var binding: Dictionary = {"type": parts[0], "code": parts[1].to_int()}
	return binding if is_binding_valid(binding) else {}


## Arrondi au pas, sans bruit de virgule flottante (1.7000000000000002 -> 1.7).
func _snap_float(v: float, step: float) -> float:
	return String.num(snappedf(v, step), 4).to_float()


func _in_range(v: float, range_: Dictionary, fallback_min: float, fallback_max: float) -> bool:
	return v >= float(range_.get("min", fallback_min)) - 0.000001 and v <= float(range_.get("max", fallback_max)) + 0.000001


## Fichier des actions modifiables : action absente de l'Input Map, pause_menu, ui_* ou doublon = ignorée.
func _load_editable_actions() -> void:
	_editable = []
	var parsed: Variant = _read_json(CONTROLS_PATH, {})
	var list: Variant = (parsed as Dictionary).get("actions", []) if parsed is Dictionary else []
	if not list is Array:
		return
	for entry: Variant in list as Array:
		if not entry is Dictionary:
			continue
		var action: StringName = StringName(str((entry as Dictionary).get("action", "")))
		var label_key: String = str((entry as Dictionary).get("label_key", ""))
		if action == &"" or label_key.is_empty() or action == &"pause_menu" or String(action).begins_with("ui_") \
				or not InputMap.has_action(action) or is_editable(action):
			continue
		_editable.append({"action": action, "label_key": label_key})


func _capture_default_events() -> void:
	_default_events = {}
	for entry: Variant in _editable:
		var action: StringName = (entry as Dictionary)["action"]
		var copies: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			copies.append(event.duplicate())
		_default_events[action] = copies


func _restore_default_events() -> void:
	for action: StringName in _default_events:
		_erase_key_and_mouse_events(action)
		for event: InputEvent in _default_events[action] as Array:
			InputMap.action_add_event(action, event.duplicate())


## Échange compris, sans signal.
func _assign(action: StringName, binding: Dictionary) -> void:
	var old: Dictionary = binding_of(action)
	if _same_binding(old, binding):
		return
	for entry: Variant in _editable:
		var other: StringName = (entry as Dictionary)["action"]
		if other != action and _same_binding(binding_of(other), binding):
			_set_events(other, old)
	_set_events(action, binding)


## Remplace tous les événements clavier et souris de l'action par la touche donnée ({} : aucune).
func _set_events(action: StringName, binding: Dictionary) -> void:
	_erase_key_and_mouse_events(action)
	if binding.is_empty():
		return
	if binding["type"] == TYPE_KEY:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = binding["code"] as Key
		InputMap.action_add_event(action, key)
	else:
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = binding["code"] as MouseButton
		InputMap.action_add_event(action, mouse)


func _erase_key_and_mouse_events(action: StringName) -> void:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			InputMap.action_erase_event(action, event)


func _binding_from_events(events: Array) -> Dictionary:
	for event: Variant in events:
		if event is InputEventKey and (event as InputEventKey).physical_keycode != 0:
			return {"type": TYPE_KEY, "code": int((event as InputEventKey).physical_keycode)}
		if event is InputEventMouseButton:
			return {"type": TYPE_MOUSE, "code": int((event as InputEventMouseButton).button_index)}
	return {}


func _same_binding(a: Dictionary, b: Dictionary) -> bool:
	return a.get("type", "") == b.get("type", "") and a.get("code", -1) == b.get("code", -1)


## Langue du système si prise en charge, sinon repli.
func _system_language() -> String:
	var os_lang: String = OS.get_locale_language()
	if _has_language(os_lang):
		return os_lang
	return str(_cfg.get("fallback_language", "en"))


func _has_language(code: String) -> bool:
	for entry: Variant in _languages:
		if entry is Dictionary and (entry as Dictionary).get("code", "") == code:
			return true
	return false


func _volume_valid(v: float) -> bool:
	var range_: Dictionary = volume_range()
	return v >= float(range_.get("min", 0)) and v <= float(range_.get("max", 100))


func _snap(v: float) -> int:
	var step: float = maxf(float(volume_range().get("step", 5)), 1.0)
	return int(roundf(v / step) * step)


func _apply_language() -> void:
	TranslationServer.set_locale(_language)


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win: Window = get_window()
	if fullscreen:
		win.mode = Window.MODE_FULLSCREEN # plein écran sans bordure, pas exclusif
	else:
		win.mode = Window.MODE_WINDOWED
		win.unresizable = false
		win.size = window_size
		win.move_to_center()
	_apply_vsync()


func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _apply_volume(key: String) -> void:
	var buses: Dictionary = volume_range().get("buses", {}) as Dictionary
	var idx: int = AudioServer.get_bus_index(str(buses.get(key, "")))
	if idx < 0:
		return
	var value: int = int(volumes[key])
	AudioServer.set_bus_mute(idx, value <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(value / 100.0) if value > 0 else -80.0)


func _read_json(path: String, fallback: Variant) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return fallback
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed != null else fallback
