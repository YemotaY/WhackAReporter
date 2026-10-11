extends TextureButton

@onready var Menu_panel: PanelContainer = %MenuPanel
@onready var Shop_panel: PanelContainer = %ShopPanel
@onready var Language_select: OptionButton = %LanguageSelect
@onready var btn_Close_Shop: Button = %ExitShopButton
@onready var btn_Open_shop: TextureButton = %ShopButton

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


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	btn_Open_shop.pressed.connect(open_shop)
	btn_Close_Shop.pressed.connect(close_shop)
	pass # Replace with function body.

func open_shop():
	Language_select.visible = false
	btn_Open_shop.visible = false
	Menu_panel.visible = false
	Shop_panel.visible = true
	Shop_panel.populate_shop(shop_inventory)

func close_shop():
	Language_select.visible = true
	btn_Open_shop.visible = true
	Menu_panel.visible = true
	Shop_panel.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
