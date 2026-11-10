class_name InventoryPanel
extends CanvasLayer
## Panneau d'inventaire provisoire (P1-E2), enfant de Player. Non modal : la souris reste capturée.
## inventory_open affiche/masque la liste Main + ceinture ; le label du bas à gauche (objet tenu)
## est permanent. Lecture seule : aucune gestion de l'inventaire.

const CATEGORY_LABELS: Dictionary = {
	ItemData.Category.SMALL: "Petit",
	ItemData.Category.MEDIUM: "Moyen",
	ItemData.Category.LARGE: "Grand",
	ItemData.Category.FIXED: "Fixe",
}
const EMPTY_TEXT: String = "vide"

var _inventory: CarryInventory

@onready var _panel: PanelContainer = $Panel
@onready var _rows: VBoxContainer = $Panel/Rows
@onready var _held_label: Label = $HeldLabel


func _ready() -> void:
	_inventory = (get_parent().get_node("CarryController") as CarryController).inventory
	_inventory.held_changed.connect(func(_i: ItemData) -> void: refresh())
	_inventory.belt_changed.connect(func(_s: int, _i: ItemData) -> void: refresh())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory_open") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		toggle()


func toggle() -> void:
	_panel.visible = not _panel.visible


func is_open() -> bool:
	return _panel.visible


## Texte du label permanent : nom de l'objet tenu, vide si la main est vide.
func held_text() -> String:
	return item_name(_inventory.held()) if _inventory.held() != null else ""


## Textes des lignes actuellement affichées.
func row_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for child: Node in _rows.get_children():
		texts.append((child as Label).text)
	return texts


func refresh() -> void:
	var belt: Array[ItemData] = []
	for slot: int in _inventory.capacity():
		belt.append(_inventory.belt_item(slot))
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for row: Dictionary in build_rows(_inventory.held(), belt):
		var label: Label = Label.new()
		label.text = row["text"]
		_rows.add_child(label)
	_held_label.text = held_text()


## Fonction pure : une ligne « Main » puis une par emplacement de ceinture disponible (belt.size()).
## Chaque ligne : {slot: String, name: String, category: String, empty: bool, text: String}.
static func build_rows(held: ItemData, belt: Array[ItemData]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [_row("Main", held)]
	for i: int in belt.size():
		rows.append(_row("Ceinture %d" % (i + 1), belt[i]))
	return rows


## Nom affiché : tr() sur la clé de nom (clé brute si aucune traduction ; id si la clé est vide).
static func item_name(item: ItemData) -> String:
	var key: String = item.name_key if item.name_key != "" else String(item.id)
	return TranslationServer.translate(key)


static func _row(slot: String, item: ItemData) -> Dictionary:
	if item == null:
		return {"slot": slot, "name": "", "category": "", "empty": true, "text": "%s : %s" % [slot, EMPTY_TEXT]}
	var name_text: String = item_name(item)
	var category: String = CATEGORY_LABELS.get(item.category, "")
	return {"slot": slot, "name": name_text, "category": category, "empty": false,
			"text": "%s : %s (%s)" % [slot, name_text, category]}
