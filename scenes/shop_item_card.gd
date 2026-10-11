extends PanelContainer


@onready var item_preview: TextureRect = $HBoxContainer/ItemPreview
@onready var item_name_label: Label = $HBoxContainer/VBoxContainer/ItemName
@onready var item_desc_label: Label = $HBoxContainer/VBoxContainer/ItemDescription

func setup(item_data: Dictionary):
	item_name_label.text = item_data.get("name", "Unknown Item")
	item_desc_label.text = item_data.get("description", "No description available.")
	if item_data.has("texture"):
		item_preview.texture = item_data["texture"]
