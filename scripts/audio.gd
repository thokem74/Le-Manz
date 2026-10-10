class_name RaceAudio
extends Node

var enabled: bool = true

@onready var engine: AudioStreamPlayer = $Engine
@onready var crash: AudioStreamPlayer = $Crash
@onready var bonus: AudioStreamPlayer = $Bonus
@onready var extra_time: AudioStreamPlayer = $ExtraTime
@onready var finish: AudioStreamPlayer = $Finish
@onready var tick: AudioStreamPlayer = $Tick


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		stop_all()


func set_engine(running: bool, repairing: bool = false) -> void:
	engine.pitch_scale = 0.55 if repairing else 1.0
	if running and enabled:
		if not engine.playing:
			engine.play()
	else:
		engine.stop()


func play_effect(effect: StringName) -> void:
	if not enabled:
		return
	match effect:
		&"crash": crash.play()
		&"bonus": bonus.play()
		&"time": extra_time.play()
		&"finish": finish.play()
		&"tick": tick.play()


func stop_all() -> void:
	for child in get_children():
		(child as AudioStreamPlayer).stop()
