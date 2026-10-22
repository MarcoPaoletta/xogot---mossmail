extends Control

var ideas: Array = []
var selected_index: int = 0
var picture: TextureRect
var heading: Label
var subtitle: Label
var details: RichTextLabel
var tabs: HBoxContainer

func _ready() -> void:
	ideas = JSON.parse_string(FileAccess.get_file_as_string("res://pitch_ideas.json"))
	var backdrop := ColorRect.new()
	backdrop.color = Color("#101724")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var title := Label.new()
	title.text = "FIVE WORLDS / ONE NEXT PROJECT"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var note := Label.new()
	note.text = "Tap a pitch below. Original visual targets, not finished games. No Kenney assets."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var tab_scroll := ScrollContainer.new()
	column.add_child(tab_scroll)
	tabs = HBoxContainer.new()
	tab_scroll.add_child(tabs)
	for i in range(ideas.size()):
		var button := Button.new()
		button.text = str(i + 1) + "  " + ideas[i]["title"]
		button.custom_minimum_size.y = 48
		button.pressed.connect(_show_idea.bind(i))
		tabs.add_child(button)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 32)
	column.add_child(heading)
	subtitle = Label.new()
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(0, 340)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(picture)
	details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.fit_content = true
	details.scroll_active = false
	details.custom_minimum_size.y = 260
	details.add_theme_font_size_override("normal_font_size", 18)
	column.add_child(details)
	var link := Button.new()
	link.text = "Open proposed asset pack ↗"
	link.custom_minimum_size.y = 48
	link.pressed.connect(_open_source)
	column.add_child(link)
	var warning := Label.new()
	warning.text = "ASSET STATUS: provisional, not downloaded. Quaternius advertises free CC0 packs, but live pack contents, links and licenses have NOT been checked in this session. Before importing: confirm the official pack page and included license, retain license files, and record creator, source URL and download date. Reject any pack whose free tier or license does not cover commercial game use. Mockups here are original SVG artwork, not previews of the proposed packs."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", Color("#e5c698"))
	column.add_child(warning)
	_show_idea(0)

func _show_idea(index: int) -> void:
	selected_index = index
	var item: Dictionary = ideas[index]
	heading.text = item["title"]
	heading.add_theme_color_override("font_color", Color(item["color"]))
	subtitle.text = item["tag"]
	var svg_text := FileAccess.get_file_as_string("res://pitch_" + str(item["id"]) + ".svg")
	var img := Image.new()
	var result := img.load_svg_from_string(svg_text)
	if result == OK:
		picture.texture = ImageTexture.create_from_image(img)
	details.text = "[b]PLAY LOOP[/b]\n" + item["loop"] + "\n\n[b]WHY IT STANDS OUT[/b]\n" + item["hook"] + "\n\n[b]FIRST PLAYABLE[/b]\n" + item["slice"] + "\n\n[b]PROPOSED FREE ASSETS[/b]\n" + item["assets"] + "\n\n[b]SCOPE / RISK[/b]\n" + item["risk"]
	for i in range(tabs.get_child_count()):
		tabs.get_child(i).modulate = Color.WHITE if i == index else Color("#8993a4")

func _open_source() -> void:
	OS.shell_open(ideas[selected_index]["url"])
