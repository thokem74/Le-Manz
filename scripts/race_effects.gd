class_name RaceEffects
extends Node2D
## Decorative particles and repair feedback have no effect on driving or scoring.

var repair_elapsed: float = 0.0
var repairing: bool = false

@onready var crash: CPUParticles2D = $Crash
@onready var skid: CPUParticles2D = $Skid
@onready var repair_indicator: Sprite2D = $RepairIndicator


func advance(
	delta: float, car_position: Vector2, sliding: bool, in_bay: bool, pit_position: Vector2
) -> void:
	skid.position = car_position + Vector2(0.0, 14.0)
	if sliding and not skid.emitting:
		skid.visible = true
		skid.restart()
	skid.emitting = sliding
	repairing = in_bay
	repair_indicator.visible = repairing
	if repairing:
		repair_elapsed += delta
		repair_indicator.position = pit_position + Vector2(0.0, -45.0)
		repair_indicator.frame = int(repair_elapsed * 8.0) % 3
	else:
		repair_elapsed = 0.0


func burst_crash(car_position: Vector2) -> void:
	crash.position = car_position
	crash.visible = true
	crash.restart()
	crash.emitting = true


func clear() -> void:
	crash.emitting = false
	crash.visible = false
	skid.emitting = false
	skid.visible = false
	repairing = false
	repair_elapsed = 0.0
	repair_indicator.visible = false
