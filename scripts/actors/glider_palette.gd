class_name GliderPalette
extends RefCounted
## The five glider colours shared by the customization screen, the showcase
## and the flying glider. Hue < 0 keeps the downloaded texture's own blue.

const NAMES: PackedStringArray = ["Sky blue", "Ember red", "Moss green", "Sun gold", "Dusk violet"]
const SWATCHES: Array[Color] = [
	Color("#3b8ef0"), Color("#e5484d"), Color("#46a758"), Color("#f5b83d"), Color("#8e4ec6"),
]
const HUES: PackedFloat32Array = [-1.0, 0.0, 0.36, 0.115, 0.77]
const SAVE_PATH: String = "user://mossmail.cfg"


static func count() -> int:
	return SWATCHES.size()


## Applies colour [param index] to a material using glider_tint.gdshader.
static func apply(material: ShaderMaterial, index: int) -> void:
	if material == null:
		return
	var i: int = clampi(index, 0, HUES.size() - 1)
	material.set_shader_parameter(&"target_hue", HUES[i])


static func load_index() -> int:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		return clampi(int(config.get_value("glider", "color", 0)), 0, count() - 1)
	return 0


static func save_index(index: int) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("glider", "color", index)
	config.save(SAVE_PATH)
