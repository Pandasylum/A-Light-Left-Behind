class_name GameFlow
extends RefCounted
## Enchaînement des écrans : écran-titre -> partie -> pause -> écran-titre. Logique sans interface
## (testable). Valeurs provisoires : il n'existe pas encore de scène de jeu officielle.

const TITLE_SCENE: String = "res://ui/menu/title_screen.tscn"
const GAME_SCENE: String = "res://tests/test_tools/sponge_test.tscn" ## PROVISOIRE, configurable (title_screen.game_scene)
const SLOT_ID: String = "partie"

## État de l'emplacement vu par l'écran-titre.
enum SlotState { EMPTY, CONTINUABLE, DAMAGED }

## Vrai quand la partie lancée doit charger la sauvegarde (« Continuer »), faux pour « Nouvelle partie ».
## Lu par la scène de jeu à son démarrage.
static var continue_requested: bool = false


## Sauvegarde lisible (principal ou .bak) -> CONTINUABLE ; sauvegarde endommagée -> DAMAGED
## (les fichiers invalides sont alors déjà renommés .corrompu par le service) ; sinon EMPTY.
static func slot_state(service: Node, slot_id: String = SLOT_ID) -> SlotState:
	if service == null:
		return SlotState.EMPTY
	var result: Dictionary = service.call(&"load_slot", slot_id)
	if result["ok"]:
		return SlotState.CONTINUABLE
	if result["damaged"] or service.call(&"is_slot_damaged", slot_id):
		return SlotState.DAMAGED
	return SlotState.EMPTY


## Libellés (clés de message) des boutons de l'écran-titre, dans l'ordre.
static func title_entries(state: SlotState) -> Array[String]:
	var first: String = "menu.continue" if state == SlotState.CONTINUABLE else "menu.new_game"
	return [first, "menu.options", "menu.quit"]


## Une confirmation précède « Nouvelle partie » seulement si une sauvegarde endommagée existe.
static func new_game_needs_confirmation(state: SlotState) -> bool:
	return state == SlotState.DAMAGED


## Applique la sauvegarde à la partie démarrée par « Continuer ». Retourne les données (vides sinon).
static func take_continue_data(service: Node, slot_id: String = SLOT_ID) -> Dictionary:
	if not continue_requested:
		return {}
	continue_requested = false
	if service == null:
		return {}
	var result: Dictionary = service.call(&"load_slot", slot_id)
	return result["data"] if result["ok"] else {}
