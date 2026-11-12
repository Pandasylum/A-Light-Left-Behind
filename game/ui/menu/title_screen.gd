extends Control
## Écran-titre (scène principale). Nouvelle partie / Continuer, Options, Quitter. Habillage provisoire.

const OPTIONS_SCENE: PackedScene = preload("res://ui/menu/options_screen.tscn")

@export_file("*.tscn") var game_scene: String = GameFlow.GAME_SCENE ## scène lancée (PROVISOIRE)

var _state: GameFlow.SlotState = GameFlow.SlotState.EMPTY
var _menu: Control
var _options: Control
var _confirm: ConfirmationDialog


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_state = GameFlow.slot_state(get_node_or_null(^"/root/SaveService"))
	_build()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_menu = center
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	if _state == GameFlow.SlotState.DAMAGED:
		var warning: Label = Label.new()
		warning.text = tr("menu.save_damaged")
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(warning)
	var entries: Array[String] = GameFlow.title_entries(_state)
	var actions: Array[Callable] = [_on_start, _open_options, _on_quit]
	for i: int in entries.size():
		var button: Button = Button.new()
		button.text = tr(entries[i])
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(actions[i])
		box.add_child(button)
		if i == 0:
			button.grab_focus()
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = tr("menu.new_game_confirm_damaged")
	_confirm.ok_button_text = tr("menu.confirm")
	_confirm.cancel_button_text = tr("menu.cancel")
	_confirm.confirmed.connect(_launch.bind(false))
	add_child(_confirm)


func _on_start() -> void:
	if _state == GameFlow.SlotState.CONTINUABLE:
		_launch(true)
	elif GameFlow.new_game_needs_confirmation(_state):
		_confirm.popup_centered()
	else:
		_launch(false)


func _launch(continue_save: bool) -> void:
	GameFlow.continue_requested = continue_save
	get_tree().change_scene_to_file(game_scene)


func _open_options() -> void:
	_menu.visible = false
	_options = OPTIONS_SCENE.instantiate()
	_options.closed.connect(_close_options)
	add_child(_options)


func _close_options() -> void:
	_options.queue_free()
	_menu.visible = true


func _on_quit() -> void:
	get_tree().quit() # aucune sauvegarde depuis l'écran-titre
