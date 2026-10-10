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
	car.request_lane(-1)
	car.advance(0.09)
	check(is_equal_approx(car.lane_coordinate, 1.5), "Lane move is smooth at half duration")
	car.request_lane(-1)
	car.request_lane(1)
	car.advance(0.09)
	check(car.lane == 1 and car.moving and car.move_to == 0, "Only one tap buffers during a move")
	car.advance(0.18)
	check(car.lane == 0 and not car.moving, "Buffered tap moves exactly one additional lane")
	car.request_lane(-1)
	check(not car.moving, "Left boundary clamps")
	car.request_lane(1)
	car.advance(0.07)
	game.road.section = RaceRoad.Section.NARROW
	car.constrain_to_road()
	car.advance(0.18)
	check(car.lane == 1 and car.buffered_direction == 0, "Narrowing smoothly guides to middle lanes")
	car.request_lane(-1)
	check(not car.moving, "Narrow-road boundary clamps")
	game.road.section = RaceRoad.Section.ICE
	car.request_lane(1)
	car.advance(0.18)
	check(car.lane == 2, "Ice keeps the same steering duration")
	car.request_lane(1)
	car.advance(0.09)
	car.clear_input()
	check(not car.moving and car.buffered_direction == 0 and car.lane_coordinate == float(car.lane), "Cancelled movement settles on a lane")
	game.start_race()
	game.phase = game.Phase.RACING
	game.session.elapsed_seconds = 19.99
	car.request_lane(-1)
	car.advance(0.09)
	game._physics_process(0.02)
	check(car.moving and car.lane_coordinate < 1.5 and car.lane_coordinate > 1.0, "A wide-road section change does not interrupt steering")


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
	game._physics_process(2.3)
	check(game.phase == game.Phase.RESULTS and game.get_node("UI/Results").visible, "Finish displays results")
	game.start_race()
	check(game.session.crashes == 0 and not game.finish_line.visible and game.player.sprite.frame == 0, "Retry clears crash and finish visuals")
	game.phase = game.Phase.RACING
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.paused, "Background notification pauses gameplay")
	game.resume_race()
	check(not game.paused, "Explicit resume restores gameplay")
	game.player.request_lane(1)
	game.player.advance(0.09)
	game.player.request_lane(-1)
	game.pause_race()
	check(game.player.moving and game.player.buffered_direction == 0, "Pause freezes current movement and clears next tap")
	game.resume_race()
	game.player.advance(0.09)
	check(not game.player.moving, "Resume completes the frozen lane change")
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
	touch.position = Vector2(30, 120)
	touch.pressed = false
	game._unhandled_input(touch)
	check(not game.player.moving, "Release does not move a lane")
	touch.pressed = true
	game._unhandled_input(touch)
	check(game.player.move_to == 1, "Left-half press moves left")
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.position = Vector2(300, 120)
	second.pressed = true
	game._unhandled_input(second)
	game.player.advance(0.18)
	game.player.advance(0.18)
	check(game.player.lane == 2, "Second finger buffers one right change")
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(300, 130)
	game._unhandled_input(drag)
	check(not game.player.moving, "Dragging does not repeat steering")
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	key.echo = true
	game._unhandled_input(key)
	check(not game.player.moving, "Keyboard repeat is ignored")
	game.pause_race()
	game._unhandled_input(touch)
	check(not game.player.moving, "Touches do not steer while paused")
	game.resume_race()
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.position = Vector2(30, 120)
	game._unhandled_input(emulated)
	check(not game.player.moving, "Touch-generated mouse event cannot steer twice")
	check(Input.emulate_mouse_from_touch, "Mouse emulation remains available for touch menus")


func check_traffic(game: Node) -> void:
	game.start_race()
	game.phase = game.Phase.RACING
	game.traffic.rng.seed = 1982
	game.traffic.try_spawn(game.road)
	var car: TrafficCar = game.traffic.cars[0]
	car.position.y = 209.0
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
	check(smallest_gap >= 60.0, "Two-lane traffic cannot form an unavoidable wall")
