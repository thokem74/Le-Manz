class_name RaceSession
extends RefCounted
## Pure race rules, separate from visuals and input so they can be tested headlessly.

const DIFFICULTY_NAMES: Array[String] = ["EASY", "NORMAL", "HARD"]

var settings: RaceSettings
var difficulty: int = 1
var remaining_seconds: float = 0.0
var elapsed_seconds: float = 0.0
var distance_metres: float = 0.0
var bonus_points: int = 0
var clean_passes: int = 0
var total_passes: int = 0
var crashes: int = 0
var next_time_threshold: int = 20000


func _init(rules: RaceSettings = null) -> void:
	settings = rules if rules != null else RaceSettings.new()


func start(selected_difficulty: int) -> void:
	difficulty = clampi(selected_difficulty, 0, 2)
	remaining_seconds = settings.starting_seconds[difficulty]
	elapsed_seconds = 0.0
	distance_metres = 0.0
	bonus_points = 0
	clean_passes = 0
	total_passes = 0
	crashes = 0
	next_time_threshold = settings.time_bonus_interval


func advance(delta: float, travelling: bool) -> int:
	if remaining_seconds <= 0.0:
		return 0
	# Never score distance beyond expiry, even during a long frame.
	var active_seconds: float = minf(delta, remaining_seconds)
	remaining_seconds = maxf(0.0, remaining_seconds - active_seconds)
	elapsed_seconds += active_seconds
	if travelling:
		distance_metres += settings.speed_kmh / 3.6 * active_seconds
		return award_time()
	return 0


func score() -> int:
	return int(distance_metres * settings.points_per_metre) + bonus_points


func register_pass() -> bool:
	if remaining_seconds <= 0.0:
		return false
	total_passes += 1
	clean_passes += 1
	if clean_passes % settings.passes_per_bonus == 0:
		bonus_points += settings.clean_pass_bonus_points[difficulty]
		return true
	return false


func award_time() -> int:
	# Expired races cannot be revived by a late score or pass event.
	if remaining_seconds <= 0.0:
		return 0
	var awards: int = 0
	while score() >= next_time_threshold:
		remaining_seconds += settings.bonus_seconds[difficulty]
		next_time_threshold += settings.time_bonus_interval
		awards += 1
	return awards


func register_crash() -> void:
	crashes += 1
	clean_passes = 0
