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
	var viewport := SubViewport.new()
	viewport.size = Vector2i(280, 480)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--size="):
			var dimensions: PackedStringArray = argument.trim_prefix("--size=").split("x")
			viewport.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.get_node("Profile").storage_path = "/tmp/le-manz-capture-profile.cfg"
	viewport.add_child(game)
	game.audio.set_enabled(false)
	game.show_preview("ice" if view == "ice_slide" else view)
	if view in ["crash1", "crash2", "pit"]:
		game.start_race()
		game.phase = game.Phase.RACING
		game.begin_crash()
		game.advance_pit(0.02 if view == "crash1" else (0.1 if view == "crash2" else 2.2))
	if view == "ice_slide":
		game.player.horizontal_offset = 0.0
		game.player.press_control(0, 1)
		game.player.advance(0.1)
		game.player.release_control(0)
	if view == "reward":
		game.session.clean_passes = 9
		game.session.distance_metres = (20000.0 - game.settings.clean_pass_bonus_points[game.session.difficulty]) / 2.0
		game._on_overtaken(game.traffic.cars[0])
	if view == "endurance":
		game.session.distance_metres = 617283.5
		game.session.remaining_seconds = 12345.0
	game.update_driving_feedback(0.0)
	game.set_physics_process(false)
	game.update_hud()
	if view in ["road", "curves", "narrow", "ice", "night"]:
		game.traffic.cars[0].activate(1, 80.0, Color("6ecbd4"), false)
		game.traffic.cars[0].position.y = game.road.player_y - 64.0
		game.traffic.cars[0].advance(0.0, game.road)
		game.traffic.cars[1].activate(2, 80.0, Color("d9d56e"), false)
		game.traffic.cars[1].position.y = game.road.playfield_top + 42.0
		game.traffic.cars[1].advance(0.0, game.road)
		game.headlights.visible = view == "night"
	if view in ["crash1", "crash2", "ice_slide"]:
		await create_timer(0.1).timeout
	if view == "pit":
		# The preview advances race time manually; hide the already-expired burst.
		game.effects.crash.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var result: Error = image.save_png(destination)
	print("Captured %s to %s (%s)" % [view, destination, error_string(result)])
	viewport.free()
	await process_frame
	await process_frame
	quit(0 if result == OK else 1)
