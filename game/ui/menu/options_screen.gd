class_name OptionsScreen
extends Control
## Écran Options : sections Langue, Affichage, Audio, Touches, Souris et caméra (défilant). Même écran depuis
## le titre et la pause ; « closed » rend la main à l'appelant. Échap = Retour (événement consommé : pas de
## pause_menu), sauf pendant la capture d'une touche où Échap l'annule.
## Capture : clic sur le bouton d'une action, puis prochain appui clavier ou bouton de souris (hors molette).
## Réglages appliqués tout de suite par l'autoload Settings, écrits à la fermeture. Habillage provisoire.

signal closed

var _language: OptionButton
var _display_mode: OptionButton
var _vsync: CheckButton
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _key_buttons: Dictionary = {} ## action -> Button
var _reset_controls_button: Button
var _capturing: StringName = &"" ## action en attente d'une touche ("" : pas de capture)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	page.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	_build_language(box)
	_build_display(box)
	_build_audio(box)
	_build_controls(box)
	_build_camera(box)
	var back: Button = Button.new()
	back.text = tr("menu.back")
	back.custom_minimum_size = Vector2(520, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close)
	page.add_child(back)
	Settings.changed.connect(_refresh_controls)
	_language.grab_focus()
	_retranslate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _language != null:
		_retranslate()


## Avant le jeu et le menu pause : consomme Échap pour ne pas déclencher pause_menu.
func _input(event: InputEvent) -> void:
	if _capturing != &"":
		_capture_input(event)
		return
	if event.is_action_pressed(&"ui_cancel", false) or event.is_action_pressed(&"pause_menu", false):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Settings.save()
	closed.emit()


func _build_language(box: VBoxContainer) -> void:
	box.add_child(_section_title("options.section.language"))
	_language = OptionButton.new()
	var langs: Array = Settings.languages()
	for i: int in langs.size():
		var entry: Dictionary = langs[i] as Dictionary
		_language.add_item(str(entry.get("name", entry.get("code", ""))))
		_language.set_item_metadata(i, str(entry.get("code", "")))
		if entry.get("code", "") == Settings.language():
			_language.select(i)
	_language.item_selected.connect(func(i: int) -> void:
		Settings.set_language(str(_language.get_item_metadata(i))))
	box.add_child(_row("options.language", _language))


func _build_display(box: VBoxContainer) -> void:
	box.add_child(_section_title("options.section.display"))
	_display_mode = OptionButton.new()
	_display_mode.add_item("")
	_display_mode.add_item("")
	_display_mode.select(0 if Settings.fullscreen else 1)
	_display_mode.item_selected.connect(func(i: int) -> void: Settings.set_fullscreen(i == 0))
	box.add_child(_row("options.display_mode", _display_mode))
	_vsync = CheckButton.new()
	_vsync.button_pressed = Settings.vsync
	_vsync.toggled.connect(Settings.set_vsync)
	box.add_child(_row("options.vsync", _vsync))


func _build_audio(box: VBoxContainer) -> void:
	box.add_child(_section_title("options.section.audio"))
	var range_: Dictionary = Settings.volume_range()
	for key: String in Settings.VOLUME_KEYS:
		var slider: HSlider = HSlider.new()
		slider.min_value = float(range_.get("min", 0))
		slider.max_value = float(range_.get("max", 100))
		slider.step = float(range_.get("step", 5))
		slider.value = float(Settings.volumes[key])
		slider.custom_minimum_size = Vector2(180, 0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var label: Label = Label.new()
		label.custom_minimum_size = Vector2(56, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.text = "%d %%" % int(slider.value)
		slider.value_changed.connect(func(v: float) -> void:
			Settings.set_volume(key, v)
			label.text = "%d %%" % int(v))
		_sliders[key] = slider
		_value_labels[key] = label
		var holder: HBoxContainer = HBoxContainer.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(slider)
		holder.add_child(label)
		box.add_child(_row("options.volume." + key, holder))


func _build_controls(box: VBoxContainer) -> void:
	box.add_child(_section_title("options.section.controls"))
	for entry: Variant in Settings.editable_actions():
		var action: StringName = (entry as Dictionary)["action"]
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(200, 0)
		button.pressed.connect(_begin_capture.bind(action))
		_key_buttons[action] = button
		box.add_child(_row(str((entry as Dictionary)["label_key"]), button))
	_reset_controls_button = Button.new()
	_reset_controls_button.pressed.connect(func() -> void:
		_capturing = &""
		Settings.reset_controls())
	box.add_child(_reset_controls_button)


func _build_camera(box: VBoxContainer) -> void:
	box.add_child(_section_title("options.section.camera"))
	var sens_range: Dictionary = Settings.sensitivity_range()
	box.add_child(_slider_row("options.mouse_sensitivity", sens_range, Settings.look_sensitivity,
			"%.1f", Settings.set_look_sensitivity))
	var invert: CheckButton = CheckButton.new()
	invert.button_pressed = Settings.invert_y
	invert.toggled.connect(Settings.set_invert_y)
	box.add_child(_row("options.invert_y", invert))
	box.add_child(_slider_row("options.fov", Settings.fov_range(), float(Settings.fov), "%d°", Settings.set_fov))


## Ligne « libellé, curseur, valeur » ; bornes et pas viennent de `range_` (settings_defaults.json).
func _slider_row(key: String, range_: Dictionary, value: float, format: String, setter: Callable) -> HBoxContainer:
	var slider: HSlider = HSlider.new()
	slider.min_value = float(range_.get("min", 0))
	slider.max_value = float(range_.get("max", 100))
	slider.step = float(range_.get("step", 1))
	slider.value = value
	slider.custom_minimum_size = Vector2(180, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label: Label = Label.new()
	label.custom_minimum_size = Vector2(56, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.text = format % slider.value
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		label.text = format % v)
	var holder: HBoxContainer = HBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(slider)
	holder.add_child(label)
	return _row(key, holder)


func _begin_capture(action: StringName) -> void:
	_capturing = action
	_refresh_controls()


## Pendant la capture : Échap annule ; première touche ou premier bouton de souris (hors molette) pressé est assigné.
## Les relâchements (dont celui du clic qui a lancé la capture) et les répétitions sont ignorés.
func _capture_input(event: InputEvent) -> void:
	var binding: Dictionary = {}
	if event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed or key.echo:
			return
		get_viewport().set_input_as_handled()
		if key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE:
			_capturing = &""
			_refresh_controls()
			return
		binding = {"type": Settings.TYPE_KEY, "code": int(key.physical_keycode)}
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if not button.pressed or button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
				MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return
		get_viewport().set_input_as_handled()
		binding = {"type": Settings.TYPE_MOUSE, "code": int(button.button_index)}
	else:
		return
	var action: StringName = _capturing
	if Settings.set_binding(action, binding):
		_capturing = &""
		_refresh_controls()


func _refresh_controls() -> void:
	for action: StringName in _key_buttons:
		var button: Button = _key_buttons[action]
		button.text = tr("controls.press_key") if action == _capturing else binding_text(Settings.binding_of(action))


## Texte d'une touche : libellé de la disposition du clavier courant (WASD donne ZQSD sur AZERTY),
## clé de traduction pour les boutons de souris.
func binding_text(binding: Dictionary) -> String:
	var code: int = int(binding.get("code", 0))
	match binding.get("type", ""):
		Settings.TYPE_KEY:
			var physical: Key = code as Key
			var label: Key = KEY_NONE
			if DisplayServer.get_name() != "headless": # le serveur sans affichage ne connaît pas la disposition
				label = DisplayServer.keyboard_get_label_from_physical(physical)
			var text: String = OS.get_keycode_string(label if label != KEY_NONE else physical)
			return text if not text.is_empty() else "?"
		Settings.TYPE_MOUSE:
			return tr("controls.mouse.%d" % code)
	return tr("controls.unbound")


func _section_title(key: String) -> Label:
	var label: Label = Label.new()
	label.text = key
	label.add_theme_font_size_override("font_size", 22)
	return label


func _row(key: String, control: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = key
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _retranslate() -> void:
	_display_mode.set_item_text(0, tr("options.display_mode.fullscreen"))
	_display_mode.set_item_text(1, tr("options.display_mode.windowed"))
	_reset_controls_button.text = tr("controls.reset")
	_refresh_controls()
