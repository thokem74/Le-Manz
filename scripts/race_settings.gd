class_name RaceSettings
extends Resource
## Shared driving rules. Difficulty changes clock rewards and ten-car points, never driving behavior.

@export_category("Difficulty rewards")
@export var starting_seconds: PackedFloat32Array = [180.0, 120.0, 90.0]
@export var bonus_seconds: PackedFloat32Array = [55.0, 50.0, 45.0]
@export var clean_pass_bonus_points: PackedInt32Array = [4000, 2000, 1000]
@export_category("Driving")
@export var speed_kmh: float = 180.0
@export var scroll_speed: float = 120.0
@export var lateral_speed: float = 180.0
@export var ice_acceleration: float = 900.0
@export var ice_deceleration: float = 600.0
@export var repair_seconds: float = 4.0
@export var protection_seconds: float = 1.0
@export_category("Race")
@export var section_seconds: float = 20.0
@export var points_per_metre: float = 2.0
@export var passes_per_bonus: int = 10
@export var time_bonus_interval: int = 20000
@export var initial_spawn_seconds: float = 0.70
@export var minimum_spawn_seconds: float = 0.62
