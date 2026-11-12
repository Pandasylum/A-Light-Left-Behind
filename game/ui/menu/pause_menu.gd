class_name PauseMenu
extends CanvasLayer
## Menu pause (action « pause »). Arrête le jeu, restaure le curseur système, rend la caméra comme
## avant à la reprise. Retour au menu et Quitter sauvegardent d'abord (Autosave.save_and_wait :
## le bouton Quitter n'émet pas la fermeture de fenêtre). Habillage provisoire.

const OPTIONS_SCENE: PackedScene = preload("res://ui/menu/options_screen.tscn")

var _root: Control
var _menu: Control
var _options: Control
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_menu = CenterContainer.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_menu)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 12)
	_menu.add_child(box)
	var entries: Array = [["menu.resume", resume], ["menu.options", _open_options],
			["menu.main_menu", _to_main_menu], ["menu.quit", _quit]]
	for entry: Array in entries:
		var button: Button = Button.new()
		button.text = tr(entry[0])
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(entry[1])
		box.add_child(button)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


## Traité avant le jeu (_input) pour que le Player ne voie pas la touche.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause", false):
		return
	get_viewport().set_input_as_handled()
	if is_open():
		if _options == null:
			resume()
	else:
		pause()


func pause() -> void:
	if is_open():
		return
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_root.visible = true
	(_menu.get_child(0).get_child(0) as Button).grab_focus()


func resume() -> void:
	if not is_open():
		return
	_root.visible = false
	get_tree().paused = false
	var player: Player = _find_player()
	if player != null:
		player.restore_mouse_mode(_prev_mouse_mode)
	else:
		Input.mouse_mode = _prev_mouse_mode


func _find_player() -> Player:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var found: Array[Node] = scene.find_children("*", "Player", true, false)
	return found[0] as Player if not found.is_empty() else null


func _find_autosave() -> Autosave:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var found: Array[Node] = scene.find_children("*", "Autosave", true, false)
	return found[0] as Autosave if not found.is_empty() else null


func _save() -> void:
	var autosave: Autosave = _find_autosave()
	if autosave != null:
		autosave.save_and_wait()


func _to_main_menu() -> void:
	_save()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(GameFlow.TITLE_SCENE)


func _quit() -> void:
	_save()
	get_tree().quit()


func _open_options() -> void:
	_menu.visible = false
	_options = OPTIONS_SCENE.instantiate()
	_options.closed.connect(_close_options)
	_root.add_child(_options)


func _close_options() -> void:
	_options.queue_free()
	_options = null
	_menu.visible = true
