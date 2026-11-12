class_name OptionsScreen
extends Control
## Écran Options : vide pour l'instant (contenu : autre lot), un seul bouton « Retour ». Fonctionnel et provisoire.

signal closed

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var back: Button = Button.new()
	back.text = tr("menu.back")
	back.custom_minimum_size = Vector2(240, 48)
	back.pressed.connect(func() -> void: closed.emit())
	center.add_child(back)
	back.grab_focus()
