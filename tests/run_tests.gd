extends SceneTree
## Integration checks run the same scenes and race rules shipped in the APK.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func run() -> void:
	check_clocks_and_scoring()
	check_persistence()
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.get_node("Profile").storage_path = "/tmp/le-manz-integration-profile.cfg"
	root.add_child(game)
	game.set_physics_process(false)
	# Headless simulations advance faster than real audio mixing; device QA covers sound.
	game.audio.set_enabled(false)
	check_steering(game)
	check_lifecycle(game)
	check_inputs(game)
	check_traffic(game)
	check_closed_gaps(game)
	check_narrow_escape_routes(game)
	check_portrait_geometry()
	check_clean_run_thresholds(game)
	check_difficulty_playthroughs(game)
	game.free()
	await process_frame
	await process_frame
	print("Le Manz: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check_clocks_and_scoring() -> void:
	var rules := RaceSettings.new()
	var race := RaceSession.new(rules)
	for level in range(3):
		race.start(level)
		check(is_equal_approx(race.remaining_seconds, [180.0, 120.0, 90.0][level]), "Starting clock for difficulty %d" % level)
		race.advance(1.0, true)
		check(race.score() == 100 and is_equal_approx(race.distance_metres, 50.0), "Fixed speed / metre scoring for difficulty %d" % level)
		for count in range(9):
			check(not race.register_pass(), "No early clean-pass bonus")
		check(race.register_pass() and race.score() == 1100, "Tenth clean pass scores 1000")
		race.distance_metres = 9500.0
		var before: float = race.remaining_seconds
		check(race.award_time() == 1, "20,000 threshold awards once")
		check(is_equal_approx(race.remaining_seconds - before, [90.0, 60.0, 45.0][level]), "Correct difficulty time award")
		check(race.award_time() == 0, "A threshold cannot award twice")
		race.distance_metres = 29500.0
		check(race.award_time() == 2, "Multiple crossed thresholds award individually")
		race.register_crash()
		check(race.clean_passes == 0 and race.total_passes == 10 and race.score() == 60000, "Crash preserves points and total passes, resets clean streak")
		var distance: float = race.distance_metres
		before = race.remaining_seconds
		race.advance(4.0, false)
		check(race.distance_metres == distance and race.remaining_seconds == before - 4.0, "Pit consumes time without distance scoring")
		race.remaining_seconds = 0.1
		race.advance(1.0, false)
		check(race.remaining_seconds == 0.0 and not race.register_pass(), "No passes after expiry")
		race.start(level)
		check(race.clean_passes == 0 and race.bonus_points == 0 and race.crashes == 0, "Restart resets race state")
	# Count only the part of a long frame before the clock expires.
	race.start(1)
	race.remaining_seconds = 0.1
	race.advance(2.0, true)
	check(race.score() == 10, "Long-frame expiry caps distance")


func check_persistence() -> void:
	var profile := GameProfile.new()
	profile.storage_path = "/tmp/le-manz-test-profile.cfg"
	profile.difficulty = 2
	profile.sound_enabled = false
	profile.vibration_enabled = false
	profile.records = [100, 200, 300]
	check(profile.save_profile() == OK, "Profile saves")
	var restored := GameProfile.new()
	restored.storage_path = profile.storage_path
	restored.load_profile()
	check(restored.difficulty == 2 and not restored.sound_enabled and not restored.vibration_enabled, "Options persist")
	check(restored.records == [100, 200, 300], "Separate difficulty records persist")
	check(not restored.record_score(1, 150), "Lower score does not replace record")
	check(restored.record_score(1, 250) and restored.records == [100, 250, 300], "Record changes only its difficulty")
	var invalid := ConfigFile.new()
	invalid.set_value("options", "difficulty", 99)
	invalid.set_value("records", "0", -5)
	invalid.save("/tmp/le-manz-invalid-profile.cfg")
	restored.load_profile("/tmp/le-manz-invalid-profile.cfg")
	check(restored.difficulty == 2 and restored.records[0] == 0, "Invalid stored ranges are clamped")
	profile.free()
	restored.free()


func check_steering(game: Node) -> void:
	game.start_race()
	var car: PlayerCar = game.player
	car.press_control(0, -1)
	car.advance(0.1)
	check(is_equal_approx(car.horizontal_offset, 10.0), "Press begins continuous movement immediately")
	car.release_control(0)
	car.advance(0.18)
	check(is_equal_approx(car.horizontal_offset, 10.0), "Quick release stops without completing a lane")
	car.press_control(0, 1)
	car.advance(0.2)
	car.release_control(0)
	var stopped: float = car.horizontal_offset
	car.advance(0.2)
	check(is_equal_approx(car.horizontal_offset, stopped) and car.lateral_velocity == 0.0, "Dry hold releases without snapping")
	for count in range(3):
		car.press_control(0, -1)
		car.advance(0.02)
		car.release_control(0)
	car.advance(1.0)
	check(is_equal_approx(car.horizontal_offset, stopped - 10.8), "Rapid short presses move only while held")
	car.clear_input()
	car.press_control(0, -1)
	car.advance(2.0)
	check(is_equal_approx(car.horizontal_offset, -94.0) and car.lateral_velocity == 0.0, "Full car clamps at road edge")
	game.road.section = RaceRoad.Section.NARROW
	for step in range(60):
		game.road.advance(1.0 / 60.0, 120.0)
		car.advance(1.0 / 60.0)
		check(absf(car.horizontal_offset) <= game.road.offset_limit(car.visual_half_width()), "Narrowing keeps full car inside road")
	check(is_equal_approx(car.horizontal_offset, -38.0), "Narrow road preserves free position rather than lane snapping")
	car.clear_input()
	game.road.reset_road()
	game.road.section = RaceRoad.Section.ICE
	car.horizontal_offset = -40.0
	car.press_control(0, 1)
	for step in range(15):
		car.advance(1.0 / 60.0)
	check(is_equal_approx(car.lateral_velocity, 180.0), "Ice reaches configured lateral speed gradually")
	car.release_control(0)
	stopped = car.horizontal_offset
	for step in range(18):
		car.advance(1.0 / 60.0)
	check(is_equal_approx(car.horizontal_offset - stopped, 27.0), "Ice release coasts a gentle 27 pixels")
	check(is_zero_approx(car.lateral_velocity), "Ice drift comes to rest")
	car.horizontal_offset = 0.0
	car.lateral_velocity = 180.0
	car.press_control(0, -1)
	car.advance(0.2)
	check(is_zero_approx(car.lateral_velocity), "Countersteering brakes slide")
	car.advance(0.1)
	check(car.lateral_velocity < 0.0, "Countersteering reverses slide")
	car.clear_input()
	car.horizontal_offset = 0.0
	car.press_control(0, 1)
	car.advance(0.1)
	car.release_control(0)
	car.advance(0.30)
	check(is_equal_approx(car.horizontal_offset, 11.25) and car.lateral_velocity == 0.0, "Short ice press produces proportionate drift without a lane switch")
	car.press_control(0, -1)
	car.advance(0.2)
	stopped = car.horizontal_offset
	car.clear_input()
	car.advance(0.2)
	check(is_equal_approx(car.horizontal_offset, stopped), "Clearing input stops momentum without snapping")
	car.horizontal_offset = 0.0
	car.lateral_velocity = 180.0
	car.advance(0.5)
	check(is_equal_approx(car.horizontal_offset, 27.0), "Delayed frame preserves exact ice stopping distance")
	car.press_control(0, 1)
	car.advance(0.05)
	var before_transition: float = car.horizontal_offset
	game.road.section = RaceRoad.Section.NIGHT
	car.advance(0.01)
	check(is_equal_approx(car.horizontal_offset - before_transition, 1.8), "Leaving ice restores direct held steering")
	car.clear_input()
	game.road.section = RaceRoad.Section.CURVES
	game.road.advance(1.0, 120.0)
	car.advance(0.0)
	check(is_equal_approx(car.position.x, game.road.centre_x(car.position.y) + car.horizontal_offset), "Curves carry road-relative car position")


func check_lifecycle(game: Node) -> void:
	game.profile.difficulty = 1
	game.start_race()
	game._physics_process(3.1)
	check(game.phase == game.Phase.RACING, "Countdown enters race")
	game._physics_process(1.0)
	var before: float = game.session.remaining_seconds
	game.pause_race()
	game._physics_process(10.0)
	check(game.session.remaining_seconds == before, "Pause stops clock")
	game.open_settings("Pause")
	game.close_settings()
	check(game.paused and game.get_node("UI/Pause").visible, "Settings return to paused race")
	game.resume_race()
	game.traffic.reset_traffic()
	game.begin_crash()
	game.begin_crash()
	check(game.session.crashes == 1, "Repeated collision cannot duplicate crash")
	var score_before: int = game.session.score()
	for step in range(241):
		game._physics_process(1.0 / 60.0)
	check(game.phase == game.Phase.RACING, "Four-second pit returns to race")
	check(game.session.score() == score_before and game.protection_remaining > 0.0, "Pit does not score; re-entry is protected")
	game.begin_crash()
	game.session.remaining_seconds = 0.02
	game._physics_process(0.03)
	check(game.phase == game.Phase.FINISH, "Expiry during pit enters finish")
	game._physics_process(10.0)
	check(game.phase == game.Phase.RESULTS and game.get_node("UI/Results").visible, "Finish displays results")
	game.start_race()
	check(game.session.crashes == 0 and not game.finish_line.visible and game.player.sprite.frame == 0, "Retry clears crash and finish visuals")
	game.phase = game.Phase.RACING
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.paused, "Background notification pauses gameplay")
	game.resume_race()
	check(not game.paused, "Explicit resume restores gameplay")
	game.player.press_control(0, 1)
	game.player.advance(0.2)
	var position_before_pause: float = game.player.horizontal_offset
	game.pause_race()
	check(game.player.presses.is_empty() and game.player.lateral_velocity == 0.0, "Pause clears all steering state")
	game.resume_race()
	game.player.advance(0.2)
	check(is_equal_approx(game.player.horizontal_offset, position_before_pause), "Resume requires fresh input")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.paused, "Android Back pauses an active race")
	game.open_settings("Pause")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.get_node("UI/Pause").visible, "Android Back returns from settings")
	game.profile.difficulty = 0
	check(game.session.difficulty != 0, "Difficulty change cannot change an active race")
	game.start_race()
	check(game.session.difficulty == 0, "Next race uses selected difficulty")


func check_inputs(game: Node) -> void:
	game.start_race()
	game.phase = game.Phase.RACING
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(30, 200)
	touch.pressed = true
	game._unhandled_input(touch)
	game.player.advance(0.05)
	check(game.player.horizontal_offset < 28.0, "Left-half press moves left")
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.position = Vector2(game.get_viewport_rect().size.x - 30, 200)
	second.pressed = true
	game._unhandled_input(second)
	var before: float = game.player.horizontal_offset
	game.player.advance(0.05)
	check(is_equal_approx(game.player.horizontal_offset, before), "Opposite touches cancel movement")
	var third := InputEventScreenTouch.new()
	third.index = 2
	third.position = Vector2(30, 200)
	third.pressed = true
	game._unhandled_input(third)
	game.player.advance(0.05)
	check(is_equal_approx(game.player.horizontal_offset, before), "Opposite sides cancel even with three fingers")
	third.pressed = false
	game._input(third)
	touch.pressed = false
	touch.position = Vector2(220, 10)
	game._input(touch)
	check(not game.player.presses.has(0), "Release over HUD removes the tracked finger")
	game.player.advance(0.2)
	check(game.player.horizontal_offset > before, "Remaining right finger continues steering")
	second.pressed = false
	game._input(second)
	check(game.player.presses.is_empty(), "All releases clear tracked controls")
	game.pause_race()
	touch.pressed = true
	game._unhandled_input(touch)
	check(game.player.presses.is_empty(), "Touches do not steer while paused")
	game.resume_race()
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.position = Vector2(30, 200)
	game._unhandled_input(emulated)
	check(game.player.presses.is_empty(), "Emulated mouse cannot duplicate steering")
	check(Input.emulate_mouse_from_touch, "Mouse emulation remains available for touch menus")
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	key.echo = true
	game._unhandled_input(key)
	check(game.player.presses.is_empty(), "Key repeat cannot start steering")
	key.echo = false
	game._unhandled_input(key)
	game.player.advance(0.2)
	key.pressed = false
	game._input(key)
	check(game.player.presses.is_empty(), "Keyboard hold releases correctly")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(30, 200)
	mouse.pressed = true
	game._unhandled_input(mouse)
	game.player.advance(0.05)
	mouse.pressed = false
	game._input(mouse)
	var released_offset: float = game.player.horizontal_offset
	game.player.advance(0.3)
	check(is_equal_approx(game.player.horizontal_offset, released_offset), "Quick mouse click stops without completing a lane")
	game.player.clear_input()
	touch.pressed = true
	touch.position = Vector2(30, 200)
	game._unhandled_input(touch)
	game.player.advance(0.05)
	touch.canceled = true
	touch.pressed = false
	game._input(touch)
	check(game.player.lateral_velocity == 0.0 and game.player.presses.is_empty(), "Cancelled touch stops steering")


func check_traffic(game: Node) -> void:
	game.start_race()
	game.phase = game.Phase.RACING
	game.traffic.rng.seed = 1982
	game.traffic.try_spawn(game.road)
	var car: TrafficCar = game.traffic.cars[0]
	car.position.y = game.road.player_y + 29.0
	game.traffic.advance(0.03, game.road, game.settings, 0.0, true)
	check(game.session.total_passes == 1, "A passed car scores once")
	game.traffic.advance(0.03, game.road, game.settings, 0.0, true)
	check(game.session.total_passes == 1, "Same car cannot score twice")
	game.traffic.reset_traffic()
	car.activate(2, 90, Color.WHITE, false)
	car.position = game.player.position
	game._physics_process(0.01)
	check(game.phase == game.Phase.PIT and not car.active, "Actual car collision enters pit and removes obstacle")
	game.traffic.reset_traffic()
	car.activate(0, 90, Color.WHITE, false)
	game.road.section = RaceRoad.Section.NARROW
	game.traffic.constrain_to_road(game.road)
	check(not car.active, "Outer traffic leaves before narrowing")
	for section in range(5):
		game.road.section = section
		game.road.advance(1.0, 120.0)
		check(game.road.minimum_lane() <= game.road.maximum_lane(), "Valid lane range in section %d" % section)


func check_portrait_geometry() -> void:
	for dimensions in [Vector2i(280, 498), Vector2i(280, 622), Vector2i(360, 480)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		root.add_child(viewport)
		var game: Node = load("res://scenes/game.tscn").instantiate()
		game.get_node("Profile").storage_path = "/tmp/le-manz-geometry-profile.cfg"
		viewport.add_child(game)
		game.set_physics_process(false)
		game.audio.set_enabled(false)
		game.start_race()
		check(is_equal_approx(game.road.player_y, dimensions.y - 80.0), "Player is 80 pixels above portrait bottom")
		check(game.road.rows.back().position.y > dimensions.y, "Scene-authored road pool covers portrait height")
		check(is_equal_approx(game.position.x, (dimensions.x - 280.0) * 0.5), "Road is centred on tablet")
		for name in ["Title", "Help", "Settings", "Pause", "Results"]:
			var panel: Control = game.get_node("UI/" + name)
			check(panel.position.y >= 0.0 and panel.position.y + panel.size.y <= dimensions.y, "Portrait panel stays inside viewport")
		game.phase = game.Phase.RACING
		game.traffic.cars[0].activate(2, 90.0, Color.WHITE, false)
		game.traffic.cars[0].position.y = game.road.player_y + 29.0
		game.traffic.advance(0.03, game.road, game.settings, 0.0, true)
		check(game.session.total_passes == 1, "Overtake line follows portrait player position")
		game.player.horizontal_offset = 14.0
		game.player.advance(0.0)
		game.traffic.cars[0].position = game.player.position
		check(game.traffic.collision_with(game.player) != null, "Collisions work between lanes and on centred tablets")
		game.begin_crash()
		game.advance_pit(4.0)
		check(is_equal_approx(game.player.position.y, game.road.player_y) and game.player.horizontal_offset == -28.0, "Pit re-entry follows portrait geometry")
		game.begin_finish()
		check(game.finish_line.position.y == game.road.playfield_top - 16.0, "Finish line starts at portrait road top")
		game.advance_finish((game.road.player_y - game.road.playfield_top + 40.0) / game.settings.scroll_speed + 0.1)
		check(game.phase == game.Phase.RESULTS, "Finish sequence crosses player before results")
		viewport.free()


func check_difficulty_playthroughs(game: Node) -> void:
	# An intentionally stationary driver must eventually finish on every difficulty.
	for level in range(3):
		game.profile.difficulty = level
		game.start_race()
		game.phase = game.Phase.RACING
		game.traffic.rng.seed = 1982
		for step in range(60 * 600):
			game._physics_process(1.0 / 60.0)
			if game.phase == game.Phase.RESULTS:
				break
		check(game.phase == game.Phase.RESULTS, "Complete stationary race on difficulty %d" % level)
		print("%s stationary run: %d points, %d passes, %d crashes, %.1fs" % [RaceSession.DIFFICULTY_NAMES[level], game.session.score(), game.session.total_passes, game.session.crashes, game.session.elapsed_seconds])


func check_clean_run_thresholds(game: Node) -> void:
	# Remove collision risk to measure the scoring opportunity supplied by traffic.
	# This is a pacing check, not a claim that a human can dodge every car.
	for level in range(3):
		game.profile.difficulty = level
		game.start_race()
		game.phase = game.Phase.RACING
		game.traffic.rng.seed = 1982
		game.protection_remaining = 10000.0
		for step in range(60 * 180):
			game._physics_process(1.0 / 60.0)
			if game.session.next_time_threshold > 20000 or game.phase != game.Phase.RACING:
				break
		check(game.session.next_time_threshold == 40000, "Clean run can reach extra time on difficulty %d" % level)
		print("%s first time bonus: %.1fs, %d passes" % [RaceSession.DIFFICULTY_NAMES[level], game.session.elapsed_seconds, game.session.total_passes])
	# Narrow traffic must keep a full reaction gap as it reaches the player.
	game.traffic.reset_traffic()
	game.road.section = RaceRoad.Section.NARROW
	var smallest_gap: float = 10000.0
	for step in range(60 * 60):
		game.traffic.advance(1.0 / 60.0, game.road, game.settings, 120.0, false)
		for car in game.traffic.cars:
			for other in game.traffic.cars:
				if car != other and car.active and other.active:
					smallest_gap = minf(smallest_gap, absf(car.position.y - other.position.y))
	check(smallest_gap >= 96.0, "Two-lane traffic cannot form an unavoidable wall")


func check_closed_gaps(game: Node) -> void:
	game.start_race()
	var car: TrafficCar = game.traffic.cars[0]
	check(game.player.sprite.texture.get_size() == Vector2(96, 34), "Player has three native 32 x 34 frames")
	check(car.sprite.texture.get_size() == Vector2(32, 34), "Traffic uses the same visual dimensions")
	check(game.player.hit_rect().size == Vector2(30, 30) and car.hit_rect().size == Vector2(30, 30), "Both scene collision rectangles are 30 x 30")
	for lane in range(3):
		car.activate(lane, 100.0, Color.WHITE, false)
		car.position = Vector2(game.road.lane_x(lane, game.road.player_y), game.road.player_y)
		game.player.horizontal_offset = (lane - 1.0) * RaceRoad.LANE_WIDTH
		game.player.advance(0.0)
		check(game.traffic.collision_with(game.player) == car, "Lane divider %d provides no safe corridor" % lane)
		game.player.horizontal_offset = (lane - 0.5) * RaceRoad.LANE_WIDTH
		game.player.advance(0.0)
		check(game.traffic.collision_with(game.player) == null, "Adjacent lane %d remains clear" % lane)
	for side in [-1, 1]:
		game.player.horizontal_offset = side * 1000.0
		game.player.advance(0.0)
		car.activate(0 if side < 0 else 3, 100.0, Color.WHITE, false)
		car.position = Vector2(game.road.lane_x(car.target_lane, game.road.player_y), game.road.player_y)
		check(game.traffic.collision_with(game.player) == car, "Road edge %d provides no safe corridor" % side)
	game.player.reset_car(game.road, game.settings)
	car.activate(1, 100.0, Color.WHITE, false)
	car.position = Vector2(game.road.lane_x(1, game.road.player_y), game.road.player_y)
	game.player.press_control(0, -1)
	game.player.advance(0.16)
	check(game.traffic.collision_with(game.player) == car, "Collision is detected during continuous steering")
	game.player.clear_input()
	var original_shape: RectangleShape2D = car.hitbox.shape
	var edited_shape := RectangleShape2D.new()
	edited_shape.size = Vector2(22, 26)
	car.hitbox.shape = edited_shape
	check(car.hit_rect().size == edited_shape.size, "Collision reads the scene shape rather than hard-coded dimensions")
	car.hitbox.shape = original_shape
	game.traffic.reset_traffic()
	game.road.section = RaceRoad.Section.NARROW
	game.road.advance(1.0, 0.0)
	for offset in [-38.0, 0.0, 38.0]:
		game.player.horizontal_offset = offset
		game.player.advance(0.0)
		car.activate(1 if offset <= 0.0 else 2, 100.0, Color.WHITE, false)
		car.position = Vector2(game.road.lane_x(car.target_lane, game.road.player_y), game.road.player_y)
		check(game.traffic.collision_with(game.player) == car, "Narrow edge/divider %.0f provides no safe corridor" % offset)
	check(game.get_node("Pit/Bay").size.x == 36.0, "Pit bay fits the larger artwork")
	check(game.get_node("Pit").z_index < game.player.z_index, "Pit bay renders behind the recovering car")
	car.activate(1, 100.0, Color.WHITE, false)
	car.position.y = game.road.playfield_top
	game.traffic.spawn_elapsed = 1.0
	check(not game.traffic.try_spawn(game.road), "Narrow spawning reports a blocked row")
	game.traffic.advance(0.01, game.road, game.settings, 0.0, false)
	check(game.traffic.spawn_elapsed > 1.0, "Blocked spawning retains elapsed time")
	car.position.y = game.road.playfield_top + 68.0
	game.traffic.advance(0.01, game.road, game.settings, 0.0, false)
	check(game.traffic.spawn_elapsed == 0.0, "Spawn retries immediately once its 96-pixel gap opens")
	var other: TrafficCar = game.traffic.cars[2]
	other.activate(2, 100.0, Color.WHITE, false)
	other.position.y = car.position.y - 40.0
	game.traffic.constrain_to_road(game.road)
	check(not other.active, "Narrowing removes traffic that violates the larger reaction gap")


func check_narrow_escape_routes(game: Node) -> void:
	# Drive with real held input past alternating obstacles spaced exactly 96 pixels.
	# Switching only after the preceding collision rectangle clears is conservative.
	game.start_race()
	game.traffic.reset_traffic()
	game.road.section = RaceRoad.Section.NARROW
	game.road.advance(1.0, 0.0)
	game.player.reset_car(game.road, game.settings)
	for index in range(8):
		var car: TrafficCar = game.traffic.cars[index]
		car.activate(1 + index % 2, 100.0, Color.WHITE, false)
		car.position.y = game.road.player_y - 100.0 - index * 96.0
		car.advance(0.0, game.road)
	var cleared: int = 0
	var destination: float = 28.0
	var collided: bool = false
	for step in range(60 * 10):
		if cleared < 8 and game.traffic.cars[cleared].position.y >= game.road.player_y + 30.0:
			destination = -28.0 if cleared % 2 == 0 else 28.0
			cleared += 1
		game.player.clear_input()
		if absf(destination - game.player.horizontal_offset) > 1.5:
			game.player.press_control(0, 1 if destination > game.player.horizontal_offset else -1)
		game.player.advance(1.0 / 60.0)
		for car in game.traffic.cars:
			if car.active:
				car.advance(1.0 / 60.0, game.road)
		if game.traffic.collision_with(game.player) != null:
			collided = true
	check(not collided and cleared == 8, "Held steering escapes eight alternating narrow obstacles at the minimum gap")
	game.player.clear_input()
