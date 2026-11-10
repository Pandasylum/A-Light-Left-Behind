class_name Interactable
extends Node
## Rend interactif le corps de collision parent (couche 3). Ne porte aucune logique de jeu.

enum Action { PICK_UP, USE, PLACE, OPEN }

signal interacted(player: Node)

@export var prompt_key: String = "" ## clé de traduction de l'indice
@export var action: Action = Action.USE


func interact(player: Node) -> void:
	interacted.emit(player)
