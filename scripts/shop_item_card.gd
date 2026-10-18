extends PanelContainer

@onready var item_preview: TextureRect = $HBoxContainer/ItemPreview
@onready var item_name_label: Label = $HBoxContainer/VBoxContainer/ItemName
@onready var item_desc_label: Label = $HBoxContainer/VBoxContainer/ItemDescription
@onready var buy_button: Button = $HBoxContainer/BuyButton
@onready var root_script : Node2D = get_node("/root/Main")

func setup(item_data: Dictionary):
	item_name_label.text = item_data.get("name", "Unknown Item")
	item_desc_label.text = item_data.get("description", "No description available.")
	buy_button.pressed.connect(try_buy.bind(item_name_label.text))
	push_error("did load " + item_name_label.text)
	if item_data.has("texture"):
		item_preview.texture = item_data["texture"]

func try_buy(arg):
		
	var trgt = arg+"_PRICE"
	var hammer_price = HammerSelectController.new().get(trgt)
	var player_money = PlayerClass.money
	push_error("arg: "+str(arg))
	push_error("trgt: "+str(trgt))
	push_error("hammer_price: "+str(hammer_price))
	push_error("player_money: "+str(player_money))
	if hammer_price<player_money and trgt not in PlayerClass.unlocked_hammer:
		PlayerClass.money = PlayerClass.money - hammer_price
		PlayerClass.unlocked_hammer.append(arg)

		#HIER NOCH DAS HAMMER MENÜ REFRESHEN
		#HammerController._refresh()
		var res = []
		for i in range(0,len(HammerController.shop_inventory)):
			if(HammerController.shop_inventory[i].name not in PlayerClass.unlocked_hammer):
				res.append(HammerController.shop_inventory[i])
				
		push_error("Bough trgt : " + str(trgt))
		push_error("Reload shop: " + str(res))
		root_script.update_shop(res)
