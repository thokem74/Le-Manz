extends SceneTree
## Render one actual game screen for visual review (requires a display).


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var view: String = "title"
	var destination: String = "/tmp/le-manz-title.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--view="):
			view = argument.trim_prefix("--view=")
		if argument.begins_with("--out="):
			destination = argument.trim_prefix("--out=")
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.get_node("Profile").storage_path = "/tmp/le-manz-capture-profile.cfg"
	root.add_child(game)
	game.show_preview(view)
	game.set_physics_process(false)
	game.update_hud()
	if view in ["road", "curves", "narrow", "ice", "night"]:
		game.traffic.cars[0].activate(1, 80.0, Color("6ecbd4"), false)
		game.traffic.cars[0].position.y = 120.0
		game.traffic.cars[0].advance(0.0, game.road)
		game.traffic.cars[1].activate(2, 80.0, Color("d9d56e"), false)
		game.traffic.cars[1].position.y = 42.0
		game.traffic.cars[1].advance(0.0, game.road)
		game.headlights.visible = view == "night"
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var result: Error = image.save_png(destination)
	print("Captured %s to %s (%s)" % [view, destination, error_string(result)])
	quit(0 if result == OK else 1)
