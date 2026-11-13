extends Node
## Autoload Settings (sans class_name, conflit Godot) : réglages joueur dans user://settings.cfg.
## Valeurs par défaut, bornes et pas : res://data/settings_defaults.json ; langues : res://data/languages.json.
## Chargement tolérant (fichier absent/illisible/valeur hors bornes = défaut). Écriture atomique sans thread,
## seulement via save() (fermeture de l'écran Options) et à la sortie de l'arbre (fin du jeu).

const DEFAULTS_PATH := "res://data/settings_defaults.json"
const LANGUAGES_PATH := "res://data/languages.json"
const SETTINGS_PATH := "user://settings.cfg"
const VOLUME_KEYS: Array[String] = ["master", "music", "ambience", "effects"]

var fullscreen: bool = true
var vsync: bool = true
var window_size: Vector2i = Vector2i(1280, 720)
var volumes: Dictionary = {}

var _cfg: Dictionary = {}
var _languages: Array = []
var _language: String = ""
var _language_chosen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = _read_json(DEFAULTS_PATH, {}) as Dictionary
	var langs: Variant = _read_json(LANGUAGES_PATH, [])
	_languages = langs as Array if langs is Array else []
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
	_language = _system_language()
	_language_chosen = false


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
