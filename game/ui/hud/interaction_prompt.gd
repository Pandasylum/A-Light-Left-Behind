class_name InteractionPrompt
extends CanvasLayer
## Viseur central + indice d'interaction (visible seulement quand il y a une cible).

@onready var hint: Label = $Hint


func _ready() -> void:
	hint.visible = false


## Affiche l'indice de la cible (tr(prompt_key), ou la clé telle quelle sans traduction) ; null le masque.
func set_target(interactable: Interactable) -> void:
	if interactable == null:
		hint.visible = false
		return
	hint.text = tr(interactable.prompt_key)
	hint.visible = true


const MESSAGE_DURATION: float = 2.0 ## s

var _message_left: float = 0.0


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			$Message.visible = false


## Affiche un message temporaire (tr(key), ~2 s).
func show_message(key: String) -> void:
	$Message.text = tr(key)
	$Message.visible = true
	_message_left = MESSAGE_DURATION
