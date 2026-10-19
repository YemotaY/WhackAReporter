class_name ShopController
extends PanelContainer

@export var item_card_scene: PackedScene
@export var item_card_height: float = 120.0
@onready var shop_item_list: VBoxContainer = %ShopItemList

func _ready() -> void:
	return

func populate_shop(items: Array) -> void:
	
	#push_error("Rebuilding shop: " +str(items))
	#push_error(shop_item_list)
	
	for child in shop_item_list.get_children():
		shop_item_list.remove_child(child)
		child.queue_free()

	for item_data in items:
		var card = item_card_scene.instantiate() as Control

		# Set the card's height
		card.custom_minimum_size.y = item_card_height
		
		# Prevent vertical expansion
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

		shop_item_list.add_child(card)
		card.setup(item_data)
