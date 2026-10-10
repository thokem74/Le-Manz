class_name RaceTraffic
extends Node2D
## A scene-authored pool keeps gameplay free of repeated allocations on phones.

signal overtaken

const CAR_COLOURS: Array[Color] = [
	Color("d9d56e"), Color("8e80ce"), Color("6ecbd4"), Color("f2a66c")
]

const NARROW_GAP: float = 96.0

var cars: Array[TrafficCar] = []
var spawn_elapsed: float = 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	for child in get_children():
		cars.append(child as TrafficCar)
	rng.randomize()
	reset_traffic()


func reset_traffic() -> void:
	spawn_elapsed = 0.0
	for car in cars:
		car.deactivate()


func constrain_to_road(road: RaceRoad) -> void:
	# Outer traffic exits before the road closes, rather than squeezing into the player.
	for car in cars:
		var outside: bool = (
			car.target_lane < road.minimum_lane() or car.target_lane > road.maximum_lane()
		)
		if car.active and outside:
			car.deactivate()
		elif car.active and road.section == RaceRoad.Section.NARROW:
			car.target_lane = clampi(roundi(car.lane_coordinate), 1, 2)
			car.lane_coordinate = float(car.target_lane)
			car.pending_lane = -1
			car.relative_speed = 100.0
	# Equal relative speeds and a reaction gap prevent a two-lane traffic wall.
	if road.section == RaceRoad.Section.NARROW:
		for car in cars:
			for other in cars:
				if (
					car.active and other.active and car != other
					and absf(car.position.y - other.position.y) < NARROW_GAP
				):
					(car if car.position.y < other.position.y else other).deactivate()


func advance(
	delta: float, road: RaceRoad, rules: RaceSettings, elapsed: float, allow_passes: bool
) -> void:
	var interval: float = maxf(
		rules.minimum_spawn_seconds, rules.initial_spawn_seconds - elapsed / 900.0
	)
	spawn_elapsed += delta
	if spawn_elapsed >= interval and try_spawn(road):
		# Blocked rows retain their timer; retry as soon as the gap opens.
		spawn_elapsed = 0.0
	for car in cars:
		if not car.active:
			continue
		car.advance(delta, road)
		if car.wants_change and car.position.y > road.playfield_top + 45.0 and car.position.y < road.playfield_top + 90.0:
			car.wants_change = false
			var direction: int = -1 if rng.randf() < 0.5 else 1
			var destination: int = clampi(
				car.target_lane + direction, road.minimum_lane(), road.maximum_lane()
			)
			if road.section != RaceRoad.Section.NARROW and lane_clear(destination, car.position.y, car):
				car.signal_lane_change(destination)
		if not car.passed and car.position.y > road.player_y + car.hit_rect().size.y:
			car.passed = true
			if allow_passes:
				overtaken.emit()
		if car.position.y > road.playfield_bottom + 30.0:
			car.deactivate()


func try_spawn(road: RaceRoad) -> bool:
	# Narrow rows leave enough time to cross 56 pixels after a car clears.
	var row_gap: float = NARROW_GAP if road.section == RaceRoad.Section.NARROW else 54.0
	var spawn_y: float = road.playfield_top - 28.0
	for car in cars:
		if car.active and car.position.y < spawn_y + row_gap:
			return false
	var available_lanes: Array[int] = []
	for candidate in range(road.minimum_lane(), road.maximum_lane() + 1):
		if lane_clear(candidate, road.playfield_top - 28.0):
			available_lanes.append(candidate)
	if available_lanes.is_empty():
		return false
	var lane: int = available_lanes[rng.randi_range(0, available_lanes.size() - 1)]
	for car in cars:
		if not car.active:
			var speed: float = rng.randf_range(90.0, 104.0)
			if road.section == RaceRoad.Section.NARROW:
				speed = 100.0
			car.activate(lane, speed, CAR_COLOURS[rng.randi_range(0, 3)], rng.randf() < 0.22)
			car.position.y = road.playfield_top - 28.0
			car.position.x = road.lane_x(float(lane), car.position.y)
			return true
	return false


func lane_clear(lane: int, screen_y: float, except: TrafficCar = null) -> bool:
	for car in cars:
		if car == except or not car.active:
			continue
		if absf(car.position.y - screen_y) < 90.0:
			# Include both ends of a changing car's trajectory.
			if car.target_lane == lane or car.pending_lane == lane or roundi(car.lane_coordinate) == lane:
				return false
	return true


func collision_with(player: PlayerCar) -> TrafficCar:
	for car in cars:
		if car.active and car.hit_rect().intersects(player.hit_rect()):
			return car
	return null
