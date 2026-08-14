class_name CreativeEntityTile
extends Button

signal entity_activated(definition: CreativeEntityDef)

var definition: CreativeEntityDef

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup(value: CreativeEntityDef) -> void:
	definition = value
	text = value.display_name if value != null else "ENTITY"
	tooltip_text = value.description if value != null else ""

func set_selected_state(selected: bool) -> void:
	PaintingCreativeStyle.style_tab_button(self, selected)

func _on_pressed() -> void:
	if definition != null:
		entity_activated.emit(definition)
