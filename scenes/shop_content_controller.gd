extends PanelContainer

@export var item_card_scene: PackedScene # Assign your ShopItemCard.tscn in the Inspector
@onready var shop_item_list: VScrollBar = $"VBox/ScrollContainer/ShopItemList"

func populate_shop(items: Array) -> void:
	# Clear any existing items first
	for child in shop_item_list.get_children():
		child.queue_free()
	
	# Instantiate and setup each item card
	for item_data in items:
		var card = item_card_scene.instantiate()
		shop_item_list.add_child(card)
		card.setup(item_data)
