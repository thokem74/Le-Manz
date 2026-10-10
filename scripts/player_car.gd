class_name PlayerCar
extends Area2D
## Position is relative to the road centre, so curves carry the car naturally.

var horizontal_offset: float = 28.0
var lateral_velocity: float = 0.0
var road: RaceRoad
var rules: RaceSettings
var presses: Dictionary[int, SteeringPress] = {}
var moving: bool = false
var buffered_direction: int = 0
var move_elapsed: float = 0.0
var move_from: float = 0.0
var move_to: float = 0.0
var move_duration: float = 0.18
var tap_on_ice: bool = false

@onready var sprite: Sprite2D = $Sprite


class SteeringPress:
	extends RefCounted
	## Keep press timing and tap eligibility independent for every finger or key.
	var direction: int
	var elapsed: float = 0.0
	var origin: float
	var overlapping: bool

	func _init(input_direction: int, start_offset: float, overlaps: bool) -> void:
		direction = input_direction
		origin = start_offset
		overlapping = overlaps


func reset_car(track: RaceRoad, settings: RaceSettings) -> void:
	road = track
	rules = settings
	horizontal_offset = 28.0
	clear_input()
	position = Vector2(road.centre_x(road.player_y) + horizontal_offset, road.player_y)
	sprite.frame = 0
	modulate = Color.WHITE


func press_control(identifier: int, direction: int) -> void:
	if presses.has(identifier):
		return
	# Overlapping fingers never become taps, even if one is released quickly.
	var overlapping: bool = not presses.is_empty()
	for identifier_key: int in presses:
		var press: SteeringPress = presses[identifier_key]
		press.overlapping = true
	presses[identifier] = SteeringPress.new(
		signi(direction), move_to if moving else horizontal_offset, overlapping
	)

	if overlapping and steering_direction() == 0:
		moving = false
		buffered_direction = 0


func release_control(identifier: int, allow_tap: bool = true) -> void:
	if not presses.has(identifier):
		return
	var press: SteeringPress = presses[identifier]
	presses.erase(identifier)
	if allow_tap and press.elapsed <= rules.tap_seconds and not press.overlapping:
		request_tap(press.direction, press.origin)
	elif presses.is_empty() and (not allow_tap or road.section != RaceRoad.Section.ICE):
		lateral_velocity = 0.0


func request_tap(direction: int, origin: float) -> void:
	if moving:
		if buffered_direction == 0:
			buffered_direction = signi(direction)
		return
	move_from = horizontal_offset
	move_to = clampf(origin + direction * RaceRoad.LANE_WIDTH, -road.offset_limit(), road.offset_limit())
	move_elapsed = 0.0
	tap_on_ice = road.section == RaceRoad.Section.ICE
	move_duration = rules.ice_tap_seconds if tap_on_ice else rules.lane_change_seconds
	moving = not is_equal_approx(move_from, move_to)
	lateral_velocity = 0.0


func steering_direction() -> int:
	var left_pressed: bool = false
	var right_pressed: bool = false
	for identifier: int in presses:
		left_pressed = left_pressed or presses[identifier].direction < 0
		right_pressed = right_pressed or presses[identifier].direction > 0
	if left_pressed == right_pressed:
		return 0
	return -1 if left_pressed else 1


func advance(delta: float) -> void:
	var direction: int = steering_direction()
	var held: bool = false
	for identifier_key: int in presses:
		var press: SteeringPress = presses[identifier_key]
		press.elapsed += delta
		held = held or press.elapsed > rules.tap_seconds
	if held:
		moving = false
		buffered_direction = 0
	if moving:
		move_elapsed += delta
		var progress: float = minf(1.0, move_elapsed / move_duration)
		# Ease out on ice; tap completion still has a precise stopping point.
		if tap_on_ice:
			progress = 1.0 - pow(1.0 - progress, 2.0)
		horizontal_offset = lerpf(move_from, move_to, progress)
		if move_elapsed >= move_duration:
			moving = false
			var next_direction: int = buffered_direction
			buffered_direction = 0
			if next_direction != 0:
				request_tap(next_direction, horizontal_offset)
	else:
		var target_velocity: float = direction * rules.lateral_speed
		if road.section == RaceRoad.Section.ICE:
			var acceleration: float = rules.ice_deceleration if direction == 0 else rules.ice_acceleration
			var previous_velocity: float = lateral_velocity
			lateral_velocity = move_toward(lateral_velocity, target_velocity, acceleration * delta)
			# Integrate only until the target is reached, then travel at that velocity.
			# This also keeps release drift accurate during an unusually long frame.
			var acceleration_time: float = minf(
				delta, absf(target_velocity - previous_velocity) / maxf(0.001, acceleration)
			)
			horizontal_offset += (previous_velocity + lateral_velocity) * 0.5 * acceleration_time
			horizontal_offset += target_velocity * (delta - acceleration_time)
		else:
			lateral_velocity = target_velocity
			horizontal_offset += lateral_velocity * delta
	constrain_to_road()
	position = Vector2(road.centre_x(road.player_y) + horizontal_offset, road.player_y)


func constrain_to_road() -> void:
	var limit: float = road.offset_limit()
	horizontal_offset = clampf(horizontal_offset, -limit, limit)
	move_to = clampf(move_to, -limit, limit)
	if absf(horizontal_offset) >= limit and horizontal_offset * lateral_velocity > 0.0:
		lateral_velocity = 0.0


func clear_input() -> void:
	presses.clear()
	buffered_direction = 0
	moving = false
	lateral_velocity = 0.0


func hit_rect() -> Rect2:
	# Slightly inset from the pixel art, to keep close passes forgiving.
	return Rect2(position - Vector2(5.0, 9.0), Vector2(10.0, 18.0))
