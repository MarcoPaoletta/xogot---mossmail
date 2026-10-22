extends Node
# Headless SpriteFrames builder for sheet-delivered 2D characters.
#
# Fill DATA with the baked per-frame rectangles (taken from the delivery JSON, in frame
# order, AFTER verifying each JSON meta.size == the current PNG width/height), put this
# script on a one-node throwaway scene, and `project_run` that scene. It writes one
# `<creature>_frames.tres` next to each character's sheets, then quits.
#
# NOT @tool on purpose: a @tool _ready() that calls get_tree().quit() would quit the
# EDITOR if the scene were ever opened. This runs only as a launched game.
#
# Generating the rects: read each sheet's JSON, sort frames by trailing index, and emit
# `Rect2(x, y, w, h)` per frame["frame"]. loop = true for idle/walk/fly; false for the
# gating states (attack/telegraph/take_damage/die) so animation_finished fires.

const FPS := 12.0

# creature -> {
#   "dir":   "res:// folder that holds the sheets AND receives the .tres",
#   "anims": { anim_name -> { "loop": bool, "rects": [Rect2, Rect2, ...] } }
# }
const DATA := {
	"rock_enemy": {
		"dir": "res://images/worlds/1 - Gloomlands/enemies/rock_enemy",
		"anims": {
			"idle": {"loop": true, "rects": [Rect2(2, 2, 512, 475)]}, # ... one Rect2 per frame, in order
			# "walk":      {"loop": true,  "rects": [ ... ]},
			# "telegraph": {"loop": false, "rects": [ ... ]},
			# "attack":    {"loop": false, "rects": [ ... ]},
			# "die":       {"loop": false, "rects": [ ... ]},
		},
	},
	# more creatures ...
}

func _ready() -> void:
	for creature in DATA:
		var d: Dictionary = DATA[creature]
		var anims: Dictionary = d["anims"]
		var sf := SpriteFrames.new()
		if sf.has_animation("default"):
			sf.remove_animation("default")
		for anim in anims:
			var a: Dictionary = anims[anim]
			sf.add_animation(anim)
			sf.set_animation_loop(anim, a["loop"])
			sf.set_animation_speed(anim, FPS)
			var tex: Texture2D = load(String(d["dir"]) + "/" + String(anim) + ".png")
			for r in a["rects"]:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = r
				sf.add_frame(anim, at)
		var outp: String = String(d["dir"]) + "/" + String(creature) + "_frames.tres"
		var err := ResourceSaver.save(sf, outp)
		print("[FRAMESBUILD] ", creature, " -> err=", err, " anims=", sf.get_animation_names())
	print("[FRAMESBUILD] DONE")
	get_tree().quit()
