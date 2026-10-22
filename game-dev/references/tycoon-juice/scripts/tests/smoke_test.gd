extends SceneTree

var fails: int = 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)

func _initialize() -> void:
	# Economy
	check(EconomyCurves.format_compact(950.0) == "950", "fmt 950")
	check(EconomyCurves.format_compact(1200.0) == "1.2K", "fmt 1.2K")
	check(EconomyCurves.format_compact(3400000.0) == "3.4M", "fmt 3.4M")
	check(EconomyCurves.format_compact(1000000.0) == "1M", "fmt 1M")
	check(EconomyCurves.format_compact(999999.0) == "1M", "fmt 999999")
	check(EconomyCurves.level_cost(10.0, 1.15, 0) == 10, "level 0 cost")
	check(EconomyCurves.bulk_cost(10.0, 1.15, 0, 3) == 35, "bulk cost 3")
	check(EconomyCurves.max_affordable(10.0, 1.15, 0, 35.0) == 3, "max affordable")
	await process_frame
	# World
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.add_to_group("player")
	world.add_child(player)
	var stack := CarryStack.new()
	stack.capacity = 3
	player.add_child(stack)
	var items: Array[Node3D] = []
	for i in 5:
		var it := Node3D.new()
		it.set_meta("kind", &"fish")
		world.add_child(it)
		it.global_position = Vector3(3, 0, i)
		items.append(it)
	check(stack.add_item(items[0]), "add 1")
	check(stack.add_item(items[1]), "add 2")
	check(stack.add_item(items[2]), "add 3")
	check(not stack.add_item(items[3]), "reject when full (reserved)")
	check(stack.is_full(), "is_full")
	# let flights finish (needs frames)
	await create_timer(1.2).timeout
	check(stack.count() == 3, "3 landed, got %d" % stack.count())
	# move the player and check trailing
	var step := 1.0 / 60.0
	for f in 180:
		player.position.x += 5.0 * step
		stack._process(step)
	var top: Node3D = stack._stacked[2]
	var bottom: Node3D = stack._stacked[0]
	var slot_top: Vector3 = stack.slot_global_position(2)
	var slot_bottom: Vector3 = stack.slot_global_position(0)
	var lag_top := top.global_position.distance_to(slot_top)
	var lag_bottom := bottom.global_position.distance_to(slot_bottom)
	print("lag top ", lag_top, " lag bottom ", lag_bottom)
	check(lag_top > lag_bottom, "top lags more than bottom")
	check(lag_top < 2.0, "top lag sane")
	# send top
	var arrived := [0]
	var sent := stack.send_top(func() -> Vector3: return Vector3(5, 1, 5), 0.2, 0.5, func(_i: Node3D) -> void: arrived[0] += 1, &"fish")
	check(sent != null, "send_top returned item")
	check(stack.count() == 2, "count after send")
	await create_timer(0.8).timeout
	check(arrived[0] == 1, "arrive callback fired")
	check(stack.send_top(Callable(), 0.2, 0.5, Callable(), &"nothing") == null, "no item of unknown kind")
	# Tray
	var tray := ItemTray.new()
	tray.columns = 2
	tray.rows = 2
	tray.layers = 1
	world.add_child(tray)
	var pieces: Array[Node3D] = []
	for i in 5:
		var p := Node3D.new()
		world.add_child(p)
		pieces.append(p)
	var ok := 0
	for i in 5:
		if tray.push(pieces[i], 0.05 * i):
			ok += 1
	check(ok == 4, "tray accepts capacity only, got %d" % ok)
	await create_timer(1.2).timeout
	check(tray.count() == 4, "tray landed 4, got %d" % tray.count())
	check(tray.transfer_to_stack(stack), "tray -> stack")
	await create_timer(0.8).timeout
	check(stack.count() == 3, "stack has 3 after transfer, got %d" % stack.count())
	# Wallet + pad
	var Wallet: Node = root.get_node("/root/Wallet")
	Wallet.set_cash(100)
	var pad := UnlockPad.new()
	pad.price = 60
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	pad.add_child(cs)
	var hidden := Node3D.new()
	hidden.visible = false
	world.add_child(world.get_child(0) if false else pad)
	world.add_child(hidden)
	pad.reveal_targets = [hidden]
	var unlocked := [false]
	pad.unlocked.connect(func() -> void: unlocked[0] = true)
	pad._carrier = player
	await create_timer(1.2).timeout
	check(unlocked[0], "pad unlocked")
	check(int(Wallet.cash) == 40, "wallet drained exactly 60, cash=%d" % int(Wallet.cash))
	check(hidden.visible, "reveal target shown")
	# Camera
	var rig := TycoonCamera.new()
	var cam := Camera3D.new()
	rig.add_child(cam)
	rig.camera = cam
	rig.target = player
	world.add_child(rig)
	rig.focus_beat(Vector3(10, 0, 10), 0.1, 0.1, 0.1)
	rig.add_trauma(0.5)
	rig.fov_kick()
	await create_timer(0.8).timeout
	check(true, "camera ran")
	# Counter
	var label := MoneyCounter.new()
	root.add_child(label)
	label.set_value(5000)
	await create_timer(1.2).timeout
	print("counter text: ", label.text)
	check(label.text == "$5K", "counter rolled to $5K")
	print("RESULT fails=", fails)
	quit(1 if fails > 0 else 0)
