class_name ToolSlots
extends RefCounted
## Emplacements dédiés des outils du joueur (logique pure, hors ItemData et hors ceinture) : un
## emplacement par outil, au plus un outil en main, aucun par défaut. L'état d'usage (salissure)
## reste attaché à l'emplacement quand l'outil est rangé.

## Émis quand l'outil en main change (sorti ou rangé).
signal held_changed

const NONE: int = -1

## Emplacement de l'outil en main (NONE = aucun) ; lecture seule hors de cette classe.
var held_index: int = NONE
## Emplacement sorti par toggle(). La sélection parmi plusieurs outils n'est pas implémentée :
## elle reviendra à changer cet index.
var selected_index: int = 0

var _slots: Array[ToolState] = []


## Ajoute un emplacement pour cet outil (rangé, propre) et renvoie son index. Un outil déjà
## présent garde son emplacement. NONE si tool_data est null.
func add_tool(tool_data: ToolData) -> int:
	if tool_data == null:
		return NONE
	for index: int in _slots.size():
		if _slots[index].data == tool_data:
			return index
	_slots.append(ToolState.new(tool_data))
	return _slots.size() - 1


func count() -> int:
	return _slots.size()


## État de l'outil de l'emplacement (null hors bornes).
func state_at(index: int) -> ToolState:
	return _slots[index] if index >= 0 and index < _slots.size() else null


## État de l'outil en main (null si aucun).
func held() -> ToolState:
	return state_at(held_index)


## Sort l'outil de l'emplacement et le place en main (l'outil déjà en main retourne dans le sien).
## Renvoie false si l'emplacement n'existe pas.
func take_out(index: int) -> bool:
	if state_at(index) == null:
		return false
	if index != held_index:
		held_index = index
		held_changed.emit()
	return true


## Range l'outil en main dans son emplacement. Renvoie false si aucun outil n'était en main.
func stow() -> bool:
	if held_index == NONE:
		return false
	held_index = NONE
	held_changed.emit()
	return true


## Bascule : range l'outil en main, sinon sort l'outil sélectionné. Renvoie false sans effet.
func toggle() -> bool:
	return stow() if held_index != NONE else take_out(selected_index)


## Retire tous les emplacements (outil en main rangé d'abord).
func clear() -> void:
	stow()
	_slots.clear()
