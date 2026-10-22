extends SceneTree
## Writes the per-island deck anchors measured by tools/measure_dock_anchors.py
## into each IslandData (feedback round 3). Absolute values, safe to re-run:
##   godot --headless --path . --script tools/apply_dock_anchors.gd

const STAND_POINTS: Dictionary = {
	"forest": Vector2(244.4, 65.9),
	"cherry": Vector2(246.9, 42.9),
	"pine": Vector2(243.9, 48.4),
	"autumn": Vector2(253.4, 67.4),
	"sand": Vector2(231.4, 86.4),
	"meadow": Vector2(237.4, 48.4)
}

func _initialize() -> void:
	for id in STAND_POINTS:
		var path: String = "res://data/islands/%s.tres" % id
		var data: Resource = load(path)
		data.set("stand_point", STAND_POINTS[id])
		print("%s stand_point %s (%s)" % [path, STAND_POINTS[id], error_string(ResourceSaver.save(data, path))])
	quit()
