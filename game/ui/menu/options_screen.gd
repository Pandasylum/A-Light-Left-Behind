class_name OptionsScreen
extends Control
## Écran Options : sections Langue, Affichage, Audio. Même écran depuis le titre et la pause ;
## « closed » rend la main à l'appelant. Échap = Retour (événement consommé : pas de pause_menu).
## Réglages appliqués tout de suite par l'autoload Settings, écrits à la fermeture. Habillage provisoire.

signal closed

var _language: OptionButton
var _display_mode: OptionButton
var _vsync: CheckButton
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(480, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	_build_language(box)
	_build_display(box)
	_build_audio(box)
	var back: Button = Button.new()
	back.text = tr("menu.back")
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(_close)
	box.add_child(back)
	_language.grab_focus()
	_retranslate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _language != null:
		_retranslate()


## Avant le jeu et le menu pause : consomme Échap pour ne pas déclencher pause_menu.
func _input(event: InputEvent) -> void:
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
