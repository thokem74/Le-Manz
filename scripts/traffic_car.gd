class_name TrafficCar
extends Area2D

var active: bool = false
var passed: bool = false
var lane_coordinate: float = 0.0
var target_lane: int = 0
var relative_speed: float = 70.0
var change_timer: float = 0.0
var wants_change: bool = false
var pending_lane: int = -1
var signal_remaining: float = 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var rear_lights: Sprite2D = $RearLights
@onready var indicator: Sprite2D = $Indicator


func activate(lane: int, speed: float, colour: Color, changing: bool) -> void:
	active = true
	passed = false
	lane_coordinate = float(lane)
	target_lane = lane
	relative_speed = speed
	change_timer = 0.0
	wants_change = changing
	pending_lane = -1
	signal_remaining = 0.0
	position.y = -28.0
	sprite.modulate = colour
	indicator.visible = false
	visible = true


func deactivate() -> void:
	active = false
	visible = false


func advance(delta: float, road: RaceRoad) -> void:
	position.y += relative_speed * delta
	if pending_lane >= 0:
		signal_remaining -= delta
		if signal_remaining <= 0.0:
			target_lane = pending_lane
			pending_lane = -1
	lane_coordinate = move_toward(lane_coordinate, float(target_lane), delta * 1.6)
	position.x = road.lane_x(lane_coordinate, position.y)
	change_timer += delta
	var indicated_lane: int = pending_lane if pending_lane >= 0 else target_lane
	var changing: bool = pending_lane >= 0 or not is_equal_approx(lane_coordinate, float(target_lane))
	indicator.visible = changing and int(change_timer * 8.0) % 2 == 0
	indicator.position.x = -6.0 if indicated_lane < lane_coordinate else 6.0
	rear_lights.visible = road.section == RaceRoad.Section.NIGHT
	var beam_width: float = maxf(10.0, (184.0 - position.y) * 0.48 + 10.0)
	var inside_beam: bool = (
		position.y >= 84.0 and position.y <= 196.0
		and absf(position.x - road.headlight_x) < beam_width
	)
	var unlit: bool = road.section == RaceRoad.Section.NIGHT and not inside_beam
	sprite.self_modulate = Color("383848") if unlit else Color.WHITE


func signal_lane_change(destination: int) -> void:
	if destination == target_lane:
		return
	pending_lane = destination
	signal_remaining = 0.45


func hit_rect() -> Rect2:
	return Rect2(position - Vector2(5.0, 9.0), Vector2(10.0, 18.0))
