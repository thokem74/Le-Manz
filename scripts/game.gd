extends Node2D
## Coordinates the small gameplay components and the scene-authored interface.

enum Phase { TITLE, COUNTDOWN, RACING, PIT, FINISH, RESULTS }

@export var settings: RaceSettings

var session: RaceSession
var phase: Phase = Phase.TITLE
var paused: bool = false
var phase_elapsed: float = 0.0
var protection_remaining: float = 0.0
var notice_remaining: float = 0.0
var last_clock_second: int = -1
var countdown_number: int = -1
var crash_position: Vector2
var settings_return: String = "Title"
var new_record: bool = false

@onready var road: RaceRoad = $Road
@onready var player: PlayerCar = $Player
@onready var traffic: RaceTraffic = $Traffic
@onready var audio: RaceAudio = $Audio
@onready var effects: RaceEffects = $Effects
@onready var profile: GameProfile = $Profile
@onready var hud: Control = $UI/HUD
@onready var finish_line: Sprite2D = $FinishLine
@onready var headlights: Polygon2D = $Player/Headlights


func _ready() -> void:
	session = RaceSession.new(settings)
	traffic.overtaken.connect(_on_overtaken)
	connect_buttons()
	audio.set_enabled(profile.sound_enabled)
	player.reset_car(road, settings)
	show_title()
	apply_safe_area()
	get_viewport().size_changed.connect(apply_safe_area)
	# A deterministic rendering mode is useful for reproducible visual QA.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview="):
			show_preview(argument.trim_prefix("--preview="))


func connect_buttons() -> void:
	for index in range(3):
		var name: String = ["Easy", "Normal", "Hard"][index]
		get_node("UI/Title/" + name).pressed.connect(select_difficulty.bind(index))
	$UI/Title/Start.pressed.connect(start_race)
	$UI/Title/Help.pressed.connect(show_panel.bind("Help"))
	$UI/Title/Settings.pressed.connect(open_settings.bind("Title"))
	$UI/Help/Back.pressed.connect(show_title)
	$UI/Settings/Back.pressed.connect(close_settings)
	$UI/Settings/Sound.pressed.connect(toggle_sound)
	$UI/Settings/Vibration.pressed.connect(toggle_vibration)
	$UI/HUD/PauseButton.pressed.connect(pause_race)
	$UI/Pause/Resume.pressed.connect(resume_race)
	$UI/Pause/Settings.pressed.connect(open_settings.bind("Pause"))
	$UI/Pause/Quit.pressed.connect(end_race_from_pause)
	$UI/Results/Retry.pressed.connect(start_race)
	$UI/Results/Title.pressed.connect(show_title)


func _physics_process(delta: float) -> void:
	if paused:
		return
	notice_remaining = maxf(0.0, notice_remaining - delta)
	if notice_remaining <= 0.0:
		$UI/HUD/Notice.text = ""
	match phase:
		Phase.TITLE:
			road.advance(delta, settings.scroll_speed * 0.3)
		Phase.COUNTDOWN:
			advance_countdown(delta)
		Phase.RACING, Phase.PIT:
			advance_race(delta)
		Phase.FINISH:
			advance_finish(delta)
	update_hud()


func advance_countdown(delta: float) -> void:
	phase_elapsed += delta
	var number: int = maxi(1, 3 - int(phase_elapsed))
	if number != countdown_number:
		countdown_number = number
		$UI/HUD/Banner.text = str(number)
		audio.play_effect(&"tick")
	if phase_elapsed >= 3.0:
		phase = Phase.RACING
		phase_elapsed = 0.0
		$UI/HUD/Banner.text = ""
		show_notice("GO!", 1.0)
		audio.set_engine(true)


func advance_race(delta: float) -> void:
	var travelling: bool = phase == Phase.RACING
	var awards: int = session.advance(delta, travelling)
	if awards > 0:
		announce_time_bonus(awards)
	if session.remaining_seconds <= 0.0:
		begin_finish()
		return
	var next_section: int = int(session.elapsed_seconds / settings.section_seconds) % 5
	if next_section != road.section:
		road.section = next_section
		if next_section == RaceRoad.Section.NARROW:
			player.constrain_to_road()
			traffic.constrain_to_road(road)
		show_notice(road.SECTION_NAMES[next_section], 2.0)
	road.advance(delta, settings.scroll_speed if travelling else settings.scroll_speed * 0.3)
	headlights.visible = road.section == RaceRoad.Section.NIGHT and travelling
	road.headlight_x = player.position.x
	traffic.advance(delta, road, settings, session.elapsed_seconds, travelling)
	if travelling:
		player.advance(delta)
		protection_remaining = maxf(0.0, protection_remaining - delta)
		var blink: bool = (
			protection_remaining > 0.0 and int(protection_remaining * 12.0) % 2 == 0
		)
		player.modulate.a = 0.4 if blink else 1.0
		if protection_remaining <= 0.0:
			var collided_car: TrafficCar = traffic.collision_with(player)
			if collided_car != null:
				collided_car.deactivate()
				begin_crash()
	else:
		advance_pit(delta)
	update_driving_feedback(delta)
	var clock_second: int = ceili(session.remaining_seconds)
	if clock_second <= 10 and clock_second != last_clock_second:
		audio.play_effect(&"tick")
	last_clock_second = clock_second


func update_driving_feedback(delta: float) -> void:
	var sliding: bool = (
		phase == Phase.RACING
		and road.section == RaceRoad.Section.ICE
		and absf(player.lateral_velocity) > 30.0
	)
	var progress: float = phase_elapsed / settings.repair_seconds
	var in_bay: bool = phase == Phase.PIT and progress >= 0.45 and progress < 0.78
	audio.set_driving_effects(sliding, in_bay)
	effects.advance(delta, player.position, sliding, in_bay, $Pit.position)


func advance_pit(delta: float) -> void:
	phase_elapsed += delta
	var progress: float = phase_elapsed / settings.repair_seconds
	var pit_position := Vector2(18.0, road.player_y)
	if progress < 0.18:
		player.sprite.frame = 1 + int(phase_elapsed * 12.0) % 2
	elif progress < 0.45:
		player.sprite.frame = 0
		player.position = crash_position.lerp(pit_position, (progress - 0.18) / 0.27)
	elif progress < 0.78:
		player.position = pit_position
		player.modulate.a = 0.5 if int(phase_elapsed * 8.0) % 2 == 0 else 1.0
	else:
		player.modulate.a = 1.0
		var exit_position := Vector2(road.lane_x(1.0, road.player_y), road.player_y)
		player.position = pit_position.lerp(exit_position, minf(1.0, (progress - 0.78) / 0.22))
	if phase_elapsed >= settings.repair_seconds:
		player.horizontal_offset = -28.0
		player.clear_input()
		player.sprite.frame = 0
		player.modulate = Color.WHITE
		protection_remaining = settings.protection_seconds
		phase = Phase.RACING
		phase_elapsed = 0.0
		$UI/HUD/Banner.text = ""
		audio.set_engine(true)


func begin_crash() -> void:
	if phase != Phase.RACING:
		return
	session.register_crash()
	phase = Phase.PIT
	phase_elapsed = 0.0
	crash_position = player.position
	player.clear_input()
	headlights.visible = false
	$UI/HUD/Banner.text = "PIT REPAIR"
	show_notice("CRASH! CLEAN STREAK RESET", 2.0)
	effects.burst_crash(player.position)
	audio.play_effect(&"crash")
	audio.set_engine(true, true)
	if profile.vibration_enabled and OS.get_name() == "Android":
		Input.vibrate_handheld(250)


func _on_overtaken(car: TrafficCar) -> void:
	if phase != Phase.RACING:
		return
	audio.play_pass(car.position.x - player.position.x)
	if session.register_pass():
		show_notice("10 CLEAN PASSES! +1000", 2.0)
		audio.play_effect(&"bonus")
	var awards: int = session.award_time()
	if awards > 0:
		announce_time_bonus(awards)


func announce_time_bonus(awards: int) -> void:
	show_notice("EXTRA TIME! +%d SEC" % int(settings.bonus_seconds[session.difficulty] * awards), 2.5)
	audio.play_effect(&"time")


func start_race() -> void:
	paused = false
	new_record = false
	session.start(profile.difficulty)
	road.reset_road()
	traffic.reset_traffic()
	player.reset_car(road, settings)
	player.visible = true
	finish_line.visible = false
	headlights.visible = false
	protection_remaining = 0.0
	phase_elapsed = 0.0
	notice_remaining = 0.0
	last_clock_second = -1
	countdown_number = -1
	phase = Phase.COUNTDOWN
	show_panel("")
	hud.visible = true
	$UI/HUD/Banner.text = "3"
	$UI/HUD/Notice.text = ""
	audio.stop_all()
	effects.clear()
	update_hud()


func begin_finish() -> void:
	phase = Phase.FINISH
	phase_elapsed = 0.0
	player.clear_input()
	player.sprite.frame = 0
	player.modulate = Color.WHITE
	headlights.visible = false
	traffic.reset_traffic()
	finish_line.position = Vector2(road.centre_x(road.playfield_top - 16.0), road.playfield_top - 16.0)
	finish_line.scale.x = road.width / 224.0
	finish_line.visible = true
	$UI/HUD/Banner.text = "TIME UP!"
	$UI/HUD/Notice.text = ""
	notice_remaining = 0.0
	audio.set_driving_effects(false, false)
	audio.set_engine(false)
	effects.clear()
	audio.play_effect(&"finish")


func advance_finish(delta: float) -> void:
	phase_elapsed += delta
	road.advance(delta, settings.scroll_speed)
	player.position.x = road.centre_x(road.player_y) + player.horizontal_offset
	finish_line.position.y += settings.scroll_speed * delta
	finish_line.position.x = 140.0 + road.curve_offset(finish_line.position.y)
	if phase_elapsed >= maxf(2.2, (road.player_y - road.playfield_top + 40.0) / settings.scroll_speed):
		show_results()


func show_results(update_record: bool = true) -> void:
	player.clear_input()
	player.visible = false
	phase = Phase.RESULTS
	paused = false
	audio.stop_all()
	effects.clear()
	new_record = profile.record_score(session.difficulty, session.score()) if update_record else false
	$UI/Results/Difficulty.text = session.DIFFICULTY_NAMES[session.difficulty]
	$UI/Results/Score.text = "%06d" % session.score()
	var best_text: String = "BEST %06d" % profile.records[session.difficulty]
	$UI/Results/Record.text = "NEW BEST!" if new_record else best_text
	$UI/Results/Stats.text = "%d PASSES / %d CRASHES" % [session.total_passes, session.crashes]
	show_panel("Results")


func show_title() -> void:
	phase = Phase.TITLE
	paused = false
	finish_line.visible = false
	headlights.visible = false
	hud.visible = false
	audio.stop_all()
	effects.clear()
	road.reset_road()
	traffic.reset_traffic()
	player.reset_car(road, settings)
	player.visible = false
	show_panel("Title")
	refresh_title()


func select_difficulty(index: int) -> void:
	profile.difficulty = index
	profile.save_profile()
	refresh_title()
	audio.play_effect(&"tick")


func refresh_title() -> void:
	for index in range(3):
		var name: String = ["Easy", "Normal", "Hard"][index]
		(get_node("UI/Title/" + name) as Button).set_pressed_no_signal(index == profile.difficulty)
	$UI/Title/Record.text = "BEST %06d / TIME %d" % [
		profile.records[profile.difficulty], int(settings.starting_seconds[profile.difficulty])
	]


func show_panel(name: String) -> void:
	for panel_name in ["Title", "Help", "Settings", "Pause", "Results"]:
		get_node("UI/" + panel_name).visible = panel_name == name
	# Touch play should not leave keyboard focus highlighting the previous menu.
	get_viewport().gui_release_focus()


func open_settings(return_to: String) -> void:
	settings_return = return_to
	refresh_settings()
	show_panel("Settings")


func close_settings() -> void:
	show_panel(settings_return)


func toggle_sound() -> void:
	profile.sound_enabled = not profile.sound_enabled
	audio.set_enabled(profile.sound_enabled)
	profile.save_profile()
	refresh_settings()
	audio.play_effect(&"tick")


func toggle_vibration() -> void:
	profile.vibration_enabled = not profile.vibration_enabled
	profile.save_profile()
	refresh_settings()


func refresh_settings() -> void:
	$UI/Settings/Sound.text = "SOUND: ON" if profile.sound_enabled else "SOUND: OFF"
	$UI/Settings/Vibration.text = "VIBRATION: ON" if profile.vibration_enabled else "VIBRATION: OFF"


func pause_race() -> void:
	if phase not in [Phase.COUNTDOWN, Phase.RACING, Phase.PIT, Phase.FINISH] or paused:
		return
	paused = true
	# A resumed race requires fresh input, even if a finger remained down.
	player.clear_input()
	audio.stop_all()
	effects.clear()
	show_panel("Pause")


func resume_race() -> void:
	paused = false
	show_panel("")
	if phase in [Phase.RACING, Phase.PIT]:
		audio.set_engine(true, phase == Phase.PIT)
		update_driving_feedback(0.0)


func end_race_from_pause() -> void:
	show_results()


func show_notice(message: String, seconds: float) -> void:
	$UI/HUD/Notice.text = message
	notice_remaining = seconds


func update_hud() -> void:
	if session == null or not hud.visible:
		return
	$UI/HUD/Score.text = "%06d" % session.score()
	$UI/HUD/Time.text = "%03d" % ceili(session.remaining_seconds)
	$UI/HUD/Speed.text = "%03d" % int(settings.speed_kmh) if phase == Phase.RACING else "000"
	$UI/HUD/Passes.text = "%d / 10" % (session.clean_passes % settings.passes_per_bonus)
	$UI/HUD/Difficulty.text = session.DIFFICULTY_NAMES[session.difficulty]
	$UI/HUD/Section.text = road.SECTION_NAMES[road.section]
	if phase == Phase.PIT:
		$UI/HUD/Banner.text = "PIT %.1fS" % maxf(0.0, settings.repair_seconds - phase_elapsed)
	$UI/HUD/BannerBacking.visible = not $UI/HUD/Banner.text.is_empty()
	$UI/HUD/NoticeBacking.visible = not $UI/HUD/Notice.text.is_empty()
	var warning: bool = (
		session.remaining_seconds <= 10.0 and int(session.remaining_seconds * 4.0) % 2 == 0
	)
	$UI/HUD/Time.modulate = Color("ff6b6b") if warning else Color.WHITE


func control_identifier(event: InputEvent) -> int:
	if event is InputEventScreenTouch:
		return event.index
	if event is InputEventMouseButton:
		return -1
	if event is InputEventKey:
		return -int(event.keycode) - 10
	return -2


func _input(event: InputEvent) -> void:
	# Releases must reach a tracked control even when a menu consumes the event.
	if event is InputEventScreenTouch and (not event.pressed or event.canceled):
		player.release_control(control_identifier(event), event.canceled)
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
			player.release_control(-1)
	elif event is InputEventKey and not event.pressed:
		player.release_control(control_identifier(event))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_P]:
			if paused:
				resume_race()
			else:
				pause_race()
			get_viewport().set_input_as_handled()
			return
	if phase != Phase.RACING or paused:
		return
	var direction: int = 0
	var midpoint: float = get_viewport_rect().size.x * 0.5
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		direction = -1 if event.position.x < midpoint else 1
	elif (
		event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.device != InputEvent.DEVICE_ID_EMULATION
	):
		direction = -1 if event.position.x < midpoint else 1
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_A]:
			direction = -1
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			direction = 1
	if direction != 0:
		player.press_control(control_identifier(event), direction)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		pause_race()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if $UI/Settings.visible:
			close_settings()
		elif phase in [Phase.COUNTDOWN, Phase.RACING, Phase.PIT, Phase.FINISH]:
			pause_race()
		elif not $UI/Title.visible:
			show_title()
		else:
			get_tree().quit()


func apply_safe_area() -> void:
	var canvas: Vector2 = get_viewport_rect().size
	var safe := Rect2(Vector2.ZERO, canvas)
	if OS.get_name() == "Android":
		var safe_pixels: Rect2i = DisplayServer.get_display_safe_area()
		if safe_pixels.size.x > 0 and safe_pixels.size.y > 0:
			var inverse: Transform2D = get_viewport().get_screen_transform().affine_inverse()
			safe = safe.intersection(inverse * Rect2(safe_pixels))
	# Expand vertically on tall phones. Centre the fixed-width pixel road on tablets.
	var left: float = (canvas.x - 280.0) * 0.5
	position.x = left
	road.playfield_top = maxf(0.0, safe.position.y) + 64.0
	road.playfield_bottom = safe.end.y
	road.player_y = road.playfield_bottom - 80.0
	road.refresh()
	$UI/HUD.position = Vector2(left, maxf(0.0, safe.position.y))
	$UI/HUD.size = Vector2(280.0, safe.size.y)
	$UI/HUD/LeftHint.position.y = safe.size.y - 18.0
	$UI/HUD/RightHint.position.y = safe.size.y - 18.0
	$Pit.position.y = road.player_y
	$UI/HUD/Banner.position.y = safe.size.y * 0.42
	$UI/HUD/BannerBacking.position.y = $UI/HUD/Banner.position.y - 4.0
	for name in ["Title", "Help", "Settings", "Pause", "Results"]:
		get_node("UI/" + name).position = Vector2(left + 12.0, safe.position.y + (safe.size.y - 360.0) * 0.5)
	if phase != Phase.PIT:
		player.position = Vector2(road.centre_x(road.player_y) + player.horizontal_offset, road.player_y)


func show_preview(view: String) -> void:
	if view == "countdown":
		start_race()
		return
	if view in ["title", "help", "settings", "results", "pause"]:
		match view:
			"help":
				show_panel("Help")
			"settings":
				open_settings("Title")
			"results":
				session.start(1)
				session.distance_metres = 12345.0
				show_results(false)
			"pause":
				start_race()
				pause_race()
	else:
		start_race()
		phase = Phase.RACING
		var section_index: int = road.SECTION_NAMES.find(view.to_upper())
		if view == "night":
			section_index = 4
		if view == "ice":
			section_index = 3
		if view == "narrow":
			section_index = 2
		if view == "curves":
			section_index = 1
		road.section = maxi(0, section_index)
		session.elapsed_seconds = road.section * settings.section_seconds + 5.0
		road.advance(1.0, settings.scroll_speed)
		player.advance(0.0)
		traffic.try_spawn(road)
		$UI/HUD/Banner.text = ""
