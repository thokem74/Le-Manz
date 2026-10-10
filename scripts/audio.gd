class_name RaceAudio
extends Node
## Scene-authored voices share a protected mix; only engine gain needs a fade.

const PASS_SEMITONES: Array[int] = [0, 0, 2, 2, 4, 4, 5, 5, 7, 7]

@export var racing_volume_db: float = -3.0
@export var repair_volume_db: float = -10.0
@export var fade_seconds: float = 0.08

var enabled: bool = true
var next_pass_voice: int = 0
var engine_target_gain: float = 0.0
var engine_gain: float = 0.0
var duck_remaining: float = 0.0
var pending_extra_time: bool = false

@onready var engine: AudioStreamPlayer = $Engine
@onready var crash: AudioStreamPlayer = $Crash
@onready var bonus: AudioStreamPlayer = $Bonus
@onready var extra_time: AudioStreamPlayer = $ExtraTime
@onready var finish: AudioStreamPlayer = $Finish
@onready var tick: AudioStreamPlayer = $Tick
@onready var ice_slip: AudioStreamPlayer = $IceSlip
@onready var repair: AudioStreamPlayer = $Repair
@onready var passing_voices: Array[AudioStreamPlayer] = [$Pass0, $Pass1, $Pass2, $Pass3]


func _ready() -> void:
	bonus.finished.connect(_on_bonus_finished)
	set_process(false)


func _process(delta: float) -> void:
	advance_mix(delta)


func advance_mix(delta: float) -> void:
	duck_remaining = maxf(0.0, duck_remaining - delta)
	var ducking: bool = duck_remaining > 0.0 or bonus.playing
	var target: float = engine_target_gain * (0.45 if ducking else 1.0)
	engine_gain = move_toward(engine_gain, target, delta / maxf(0.001, fade_seconds))
	engine.volume_linear = engine_gain
	if engine_target_gain == 0.0 and engine_gain == 0.0:
		engine.stop()
		set_process(false)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		stop_all()


func set_engine(running: bool, repairing: bool = false) -> void:
	engine.pitch_scale = 0.55 if repairing else 1.0
	var target_db: float = repair_volume_db if repairing else racing_volume_db
	engine_target_gain = db_to_linear(target_db) if running and enabled else 0.0
	if engine_target_gain > 0.0 and not engine.playing:
		engine_gain = 0.0
		engine.volume_linear = 0.0
		engine.play()
	set_process(engine.playing)


func set_driving_effects(sliding: bool, repairing: bool) -> void:
	set_loop(ice_slip, sliding)
	set_loop(repair, repairing)


func set_loop(voice: AudioStreamPlayer, active: bool) -> void:
	if enabled and active:
		if not voice.playing:
			voice.play()
	else:
		voice.stop()


func play_pass(relative_x: float, clean_pass_number: int) -> void:
	if not enabled:
		return
	var voice: AudioStreamPlayer = passing_voices[next_pass_voice]
	var bus_index: int = AudioServer.get_bus_index(voice.bus)
	var panner: AudioEffectPanner = AudioServer.get_bus_effect(bus_index, 0) as AudioEffectPanner
	panner.pan = clampf(relative_x / 112.0, -1.0, 1.0) * 0.45
	var step: int = (maxi(1, clean_pass_number) - 1) % PASS_SEMITONES.size()
	voice.pitch_scale = pow(2.0, PASS_SEMITONES[step] / 12.0)
	voice.play()
	next_pass_voice = (next_pass_voice + 1) % passing_voices.size()


func play_effect(effect: StringName) -> void:
	if not enabled:
		return
	match effect:
		&"crash": crash.play()
		&"bonus": bonus.play()
		&"time":
			# Preserve the immediate HUD award while letting the bonus resolve first.
			if bonus.playing:
				pending_extra_time = true
				return
			extra_time.play()
		&"finish": finish.play()
		&"tick": tick.play()
	# Briefly lower the engine to make alerts readable without changing its pitch.
	duck_remaining = maxf(duck_remaining, 0.18 if effect == &"tick" else 0.55)


func _on_bonus_finished() -> void:
	if pending_extra_time and enabled:
		pending_extra_time = false
		play_effect(&"time")


func cancel_rewards() -> void:
	# Stop() does not emit finished; discard the pending cue before stopping voices.
	pending_extra_time = false
	bonus.stop()
	extra_time.stop()
	for voice in passing_voices:
		voice.stop()


func stop_all() -> void:
	cancel_rewards()
	engine_target_gain = 0.0
	engine_gain = 0.0
	duck_remaining = 0.0
	next_pass_voice = 0
	set_process(false)
	for child in get_children():
		(child as AudioStreamPlayer).stop()
