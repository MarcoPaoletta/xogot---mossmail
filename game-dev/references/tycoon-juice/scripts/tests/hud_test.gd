extends SceneTree
func _initialize() -> void:
	await process_frame
	var wallet: Node = root.get_node("/root/Wallet")
	wallet.set_cash(0)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var hud := HudCoinFlight.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	var label := Label.new()
	label.position = Vector2(20, 20)
	label.size = Vector2(100, 40)
	hud.add_child(label)
	hud.counter = label
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 5, 8)
	cam.look_at(Vector3.ZERO)
	hud.camera = cam
	var scene := PackedScene.new()
	var coin := TextureRect.new()
	coin.custom_minimum_size = Vector2(32, 32)
	scene.pack(coin)
	hud.coin_scene = scene
	var landed := [0]
	hud.coin_landed.connect(func(_i: int, _t: int) -> void: landed[0] += 1)
	hud.collect(Vector3.ZERO, 103)
	await create_timer(1.5).timeout
	print("landed ", landed[0], " cash ", int(wallet.cash))
	var ok: bool = landed[0] == 8 and int(wallet.cash) == 103
	print("RESULT ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
