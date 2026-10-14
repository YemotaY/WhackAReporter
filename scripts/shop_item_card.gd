extends PanelContainer

@onready var item_preview: TextureRect = $HBoxContainer/ItemPreview
@onready var item_name_label: Label = $HBoxContainer/VBoxContainer/ItemName
@onready var item_desc_label: Label = $HBoxContainer/VBoxContainer/ItemDescription
@onready var buy_button: Button = $HBoxContainer/BuyButton

func setup(item_data: Dictionary):

	item_name_label.text = item_data.get("name", "Unknown Item")
	item_desc_label.text = item_data.get("description", "No description available.")
	buy_button.pressed.connect(try_buy.bind(item_name_label.text))
	if item_data.has("texture"):
		item_preview.texture = item_data["texture"]

func try_buy(arg):
	var trgt = arg+"_PRICE"
	var hammer_price = HammerClass.get(trgt)
	var player_money = PlayerClass.money
	
	if hammer_price<=player_money :
		PlayerClass.money - hammer_price
		PlayerClass.unlocked_hammer.append(arg)
