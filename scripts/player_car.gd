class_name PlayerCar
extends Area2D
## Lane coordinates are fractional during a move; the road supplies screen positions.

var lane: int = 2
var lane_coordinate: float = 2.0
var buffered_direction: int = 0
var move_elapsed: float = 0.0
var moving: bool = false
var move_from: float = 2.0
var move_to: int = 2
var road: RaceRoad
var lane_change_seconds: float = 0.18

@onready var sprite: Sprite2D = $Sprite


func reset_car(track: RaceRoad, change_seconds: float) -> void:
	road = track
	lane_change_seconds = change_seconds
	lane = 2
	lane_coordinate = 2.0
	clear_input()
	position = Vector2(road.lane_x(lane_coordinate, 184.0), 184.0)
	sprite.frame = 0
	modulate = Color.WHITE


func request_lane(direction: int) -> void:
	if direction == 0:
		return
	if moving:
		if buffered_direction == 0:
			buffered_direction = signi(direction)
		return
	var destination: int = clampi(lane + signi(direction), road.minimum_lane(), road.maximum_lane())
	if destination == lane:
		return
	move_from = lane_coordinate
	move_to = destination
	move_elapsed = 0.0
	moving = true


func advance(delta: float) -> void:
	if moving:
		move_elapsed += delta
		lane_coordinate = lerpf(move_from, float(move_to), minf(1.0, move_elapsed / lane_change_seconds))
		if move_elapsed >= lane_change_seconds:
			lane = move_to
			lane_coordinate = float(lane)
			moving = false
			var next_direction: int = buffered_direction
			buffered_direction = 0
			request_lane(next_direction)
	position.x = road.lane_x(lane_coordinate, position.y)


func constrain_to_road() -> void:
	buffered_direction = 0
	moving = false
	lane = clampi(roundi(lane_coordinate), road.minimum_lane(), road.maximum_lane())
	# Smoothly guide an outer-lane car into the narrowing road; no edge crash.
	move_from = lane_coordinate
	move_to = lane
	move_elapsed = 0.0
	moving = not is_equal_approx(move_from, float(move_to))


func clear_input() -> void:
	buffered_direction = 0
	moving = false
	lane = roundi(lane_coordinate)
	lane_coordinate = float(lane)


func hit_rect() -> Rect2:
	# Slightly inset from the pixel art, to keep close passes forgiving.
	return Rect2(position - Vector2(5.0, 9.0), Vector2(10.0, 18.0))
