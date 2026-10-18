class_name HammerSelectController
extends OptionButton

const FLAG_SIZE := Vector2i(24, 16)
const FLAG_PADDING_LEFT := 6

@onready var rootNode = get_tree().root

var all_hammers = [
	{"flag":load_hammer("res://assets/hammers/Basic_Hammer.svg"),"id":"BASICHAMMER"},
	{"flag":load_hammer("res://assets/hammers/German_Hammer.svg"),"id":"GERMANHAMMER"},
	{"flag":load_hammer("res://assets/hammers/French_Hammer.svg"),"id":"FRENCHHAMMER"},
	{"flag":load_hammer("res://assets/hammers/American_Hammer.svg"),"id":"AMERICANHAMMER"},
]

var available_hammers : Array = [
	"Basic_Hammer.svg",
	"German_Hammer.svg",
	"French_Hammer.svg",
	"American_Hammer.svg",
	]

var BASICHAMMER_PRICE = 200
var GERMANHAMMER_PRICE = 200
var FRENCHHAMMER_PRICE = 200
var AMERICANHAMMER_PRICE = 200

var shop_inventory : Array = [
	{
		"name": "BASICHAMMER",
		"description": "BASICHAMMERDESCR",
		"texture": preload("res://assets/hammers/Basic_Hammer.svg")
	},
	{
		"name": "GERMANHAMMER",
		"description": "GERMANHAMMERDESCR",
		"texture": preload("res://assets/hammers/German_Hammer.svg")
	},
	{
		"name": "FRENCHHAMMER",
		"description": "FRENCHHAMMERDESCR",
		"texture": preload("res://assets/hammers/French_Hammer.svg")
	},
	{
		"name": "AMERICANHAMMER",
		"description": "AMERICANHAMMERDESCR",
		"texture": preload("res://assets/hammers/American_Hammer.svg")
	}
]

func load_hammer(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("Failed to load flag: " + path)
		return null

	var image := texture.get_image()
	image.resize(FLAG_SIZE.x, FLAG_SIZE.y)

	# Create a wider transparent image
	var padded := Image.create(
		FLAG_SIZE.x + FLAG_PADDING_LEFT,
		FLAG_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)

	padded.fill(Color.TRANSPARENT)

	# Place the flag with left padding
	padded.blit_rect(
		image,
		Rect2i(0, 0, FLAG_SIZE.x, FLAG_SIZE.y),
		Vector2i(FLAG_PADDING_LEFT, 0)
	)

	return ImageTexture.create_from_image(padded)

func _ready():
	for i in range(0,len(all_hammers)):
		if(all_hammers[i].id in PlayerClass.unlocked_hammer):
			add_icon_item(all_hammers[i].flag, all_hammers[i].id)


	item_selected.connect(_on_hammer_selected)

	# White outline around the OptionButton
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("#222222")
	normal_style.border_color = Color.WHITE
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(6)

	add_theme_stylebox_override("normal", normal_style)

	# Hover style
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color("#333333")

	add_theme_stylebox_override("hover", hover_style)

	# Pressed style
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color("#111111")

	add_theme_stylebox_override("pressed", pressed_style)

func _refresh():
	for i in range(0,len(all_hammers)):
		if(all_hammers[i].id in PlayerClass.unlocked_hammer):
			push_error(all_hammers[i])
			push_error(PlayerClass.unlocked_hammer)
			add_icon_item(all_hammers[i].flag, all_hammers[i].id)



	# White outline around the OptionButton
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("#222222")
	normal_style.border_color = Color.WHITE
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(6)

	add_theme_stylebox_override("normal", normal_style)

	# Hover style
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color("#333333")

	add_theme_stylebox_override("hover", hover_style)

	# Pressed style
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color("#111111")

	add_theme_stylebox_override("pressed", pressed_style)

func _on_hammer_selected(index: int):
	icon = all_hammers[index]
	PlayerClass.selected_hammer = icon
	push_error(index)
	get_parent().get_parent()._refresh_board_labels()
	get_parent().get_parent()._rebuild_link_buttons()
