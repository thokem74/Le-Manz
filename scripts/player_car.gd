class_name PlayerCar
extends Area2D
## Position is relative to the road centre, so curves carry the car naturally.

var horizontal_offset: float = 28.0
var lateral_velocity: float = 0.0
var road: RaceRoad
var rules: RaceSettings
# Each touch, mouse button, or key supplies only a held steering direction.
var presses: Dictionary[int, int] = {}

@onready var sprite: Sprite2D = $Sprite


func reset_car(track: RaceRoad, settings: RaceSettings) -> void:
	road = track
	rules = settings
	horizontal_offset = 28.0
	clear_input()
	position = Vector2(road.centre_x(road.player_y) + horizontal_offset, road.player_y)
	sprite.frame = 0
	modulate = Color.WHITE


func press_control(identifier: int, direction: int) -> void:
	presses[identifier] = signi(direction)


func release_control(identifier: int, canceled: bool = false) -> void:
	if not presses.has(identifier):
		return
	presses.erase(identifier)
	if presses.is_empty() and (canceled or road.section != RaceRoad.Section.ICE):
		lateral_velocity = 0.0


func steering_direction() -> int:
	var left_pressed: bool = false
	var right_pressed: bool = false
	for identifier: int in presses:
		left_pressed = left_pressed or presses[identifier] < 0
		right_pressed = right_pressed or presses[identifier] > 0
	if left_pressed == right_pressed:
		return 0
	return -1 if left_pressed else 1


func advance(delta: float) -> void:
	var direction: int = steering_direction()
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
	if absf(horizontal_offset) >= limit and horizontal_offset * lateral_velocity > 0.0:
		lateral_velocity = 0.0


func clear_input() -> void:
	presses.clear()
	lateral_velocity = 0.0


func hit_rect() -> Rect2:
	# Slightly inset from the pixel art, to keep close passes forgiving.
	return Rect2(position - Vector2(5.0, 9.0), Vector2(10.0, 18.0))
