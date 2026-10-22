extends SceneTree
## Feedback round 5: seated passengers are anchored at their bottom centre (the
## point they sit on) and each boat's seat_positions are where that bottom goes,
## measured on the benches of each boat's art. The rear seat of the level 3
## boats moved up onto the last bench, clear of the life ring. Absolute values:
##   godot --headless --path . --script tools/apply_seat_anchors.gd

const SEATS: Dictionary = {
	"a_1": [Vector2(-21, 47), Vector2(21, 47)],
	"a_2": [Vector2(-27, 47), Vector2(27, 47)],
	"a_3": [Vector2(-29, 27), Vector2(29, 27), Vector2(0, 58)],
	"b_1": [Vector2(-22, 52), Vector2(22, 52)],
	"b_2": [Vector2(-25, 52), Vector2(25, 52)],
	"b_3": [Vector2(-27, 32), Vector2(27, 32), Vector2(0, 60)]
}

func _initialize() -> void:
	for key in SEATS:
		var path: String = "res://data/boats/%s.tres" % key
		var data: Resource = load(path)
		var seats: Array[Vector2] = []
		seats.assign(SEATS[key])
		data.set("seat_positions", seats)
		print("%s seats %s (%s)" % [path, seats, error_string(ResourceSaver.save(data, path))])
	quit()
