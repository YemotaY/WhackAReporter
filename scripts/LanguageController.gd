extends OptionButton

const FLAG_SIZE := Vector2i(24, 16)
const FLAG_PADDING_LEFT := 6

@onready var rootNode = get_tree().root

var flags = [
	load_flag("res://flags/de.svg"),
	load_flag("res://flags/fr.svg"),
	load_flag("res://flags/us.svg")
]

func load_flag(path: String) -> Texture2D:
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
	add_icon_item(flags[0], "Germany")
	add_icon_item(flags[1], "France")
	add_icon_item(flags[2], "United States")

	item_selected.connect(_on_country_selected)

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


func _on_country_selected(index: int):
	icon = flags[index]
	# Hier noch im Hauptmenü bei wehcsel manuell HIGHSCORE aktualisieren
	match index:
		0:
			TranslationServer.set_locale("de")
		1:
			TranslationServer.set_locale("fr")
		2:
			TranslationServer.set_locale("en")
	get_parent().get_parent()._refresh_board_labels()
	
	get_parent().get_parent()._rebuild_link_buttons()
