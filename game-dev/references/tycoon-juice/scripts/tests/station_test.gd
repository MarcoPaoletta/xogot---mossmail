extends SceneTree

var fails: int = 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)

func _initialize() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.set_script(load("res://test_player.gd"))
	player.add_to_group("player")
	world.add_child(player)
	var stack := CarryStack.new()
	stack.capacity = 4
	player.add_child(stack)
	player.carry_stack = stack
	for i in 4:
		var fish := Node3D.new()
		fish.set_meta("kind", &"fish")
		world.add_child(fish)
		fish.global_position = Vector3(2, 0, i)
		stack.add_item(fish)
	await create_timer(1.0).timeout
	check(stack.count() == 4, "stack loaded with 4 fish, got %d" % stack.count())
	# Station
	var station := StationProcessor.new()
	var in_zone := Area3D.new()
	var out_zone := Area3D.new()
	var in_pt := Marker3D.new()
	var out_pt := Marker3D.new()
	var tray := ItemTray.new()
	tray.columns = 3
	tray.rows = 3
	tray.layers = 1
	station.add_child(in_zone)
	station.add_child(out_zone)
	station.add_child(in_pt)
	station.add_child(out_pt)
	station.add_child(tray)
	station.input_zone = in_zone
	station.output_zone = out_zone
	station.input_point = in_pt
	station.output_point = out_pt
	station.output_tray = tray
	station.process_time = 0.3
	var piece := Node3D.new()
	piece.name = "Fillet"
	var ps := PackedScene.new()
	ps.pack(piece)
	station.output_scene = ps
	world.add_child(station)
	var chops := [0]
	var cycles := [0]
	station.chop.connect(func(_i: int, _t: int) -> void: chops[0] += 1)
	station.cycle_completed.connect(func(_o: int) -> void: cycles[0] += 1)
	station._on_input_entered(player)
	await create_timer(3.0).timeout
	check(stack.count() == 0, "stack emptied into station, got %d" % stack.count())
	check(cycles[0] == 4, "4 cycles done, got %d" % cycles[0])
	check(chops[0] == 12, "12 chops (3 per cycle), got %d" % chops[0])
	check(tray.count() == 8 or tray.count() == 9, "tray has fillets, got %d" % tray.count())
	print("tray count ", tray.count(), " pending ", station._pending_outputs)
	# Pick up
	station._on_input_exited(player)
	station._on_output_entered(player)
	await create_timer(2.0).timeout
	check(stack.count() == 4, "stack picked 4 fillets, got %d" % stack.count())
	check(tray.count() == 4 or tray.count() == 5, "tray lost 4, got %d" % tray.count())
	print("RESULT fails=", fails)
	quit(1 if fails > 0 else 0)
