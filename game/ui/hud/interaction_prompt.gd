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
