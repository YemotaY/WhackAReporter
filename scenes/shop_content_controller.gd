extends PanelContainer

@export var item_card_scene: PackedScene # Assign your ShopItemCard.tscn in the Inspector
@onready var shop_item_list: VScrollBar = $"VBox/ScrollContainer/ShopItemList"

# Example shop data array
var shop_inventory = [
	{
		"name": "Basic Hammer",
		"description": "Bonkes like Chef since 60 years.",
		"texture": preload("res://assets/hammers/Basic_hammer.png")
	},
	{
		"name": "Another Hammer",
		"description": "Mysterious.",
		"texture": preload("res://assets/hammers/Basic_hammer.png")
	}
]

func _ready() -> void:
	populate_shop(shop_inventory)

func populate_shop(items: Array) -> void:
	# Clear any existing items first
	for child in shop_item_list.get_children():
		child.queue_free()
	
	# Instantiate and setup each item card
	for item_data in items:
		var card = item_card_scene.instantiate()
		shop_item_list.add_child(card)
		card.setup(item_data)
