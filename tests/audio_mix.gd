extends SceneTree
## Capture the real mixed output after the limiter (use a working audio driver).

var failures: int = 0
var capture := AudioEffectCapture.new()


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func window(seconds: float) -> Dictionary:
	capture.clear_buffer()
	await create_timer(seconds).timeout
	var frames: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var peak: float = 0.0
	var left_energy: float = 0.0
	var right_energy: float = 0.0
	for frame in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		left_energy += frame.x * frame.x
		right_energy += frame.y * frame.y
	return {
		"frames": frames.size(), "peak": peak,
		"rms": sqrt((left_energy + right_energy) / maxf(1.0, frames.size() * 2.0)),
		"left": left_energy, "right": right_energy,
	}


func run() -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.get_node("Profile").storage_path = "/tmp/le-manz-audio-mix.cfg"
	root.add_child(game)
	game.set_physics_process(false)
	game.audio.set_enabled(true)
	capture.buffer_length = 3.0
	var effect_index: int = AudioServer.get_bus_effect_count(0)
	check(AudioServer.get_bus_effect(0, 0) is AudioEffectHardLimiter, "Master mix has its clipping limiter")
	AudioServer.add_bus_effect(0, capture)
	game.audio.set_engine(true)
	var engine_start: Dictionary = await window(1.2)
	var engine_loop: Dictionary = await window(1.2)
	check(engine_loop.frames > 1000 and engine_loop.rms > 0.01, "Engine produces audio beyond its first loop")
	check(absf(engine_start.rms - engine_loop.rms) < 0.015, "Engine loop maintains its output level")
	game.audio.stop_all()
	await create_timer(0.1).timeout
	game.audio.play_pass(-112.0, 1)
	var left_pass: Dictionary = await window(0.22)
	game.audio.play_pass(112.0, 1)
	var right_pass: Dictionary = await window(0.22)
	check(left_pass.left > left_pass.right * 1.2, "Left passing sweep pans left in mixed output")
	check(right_pass.right > right_pass.left * 1.2, "Right passing sweep pans right in mixed output")
	game.audio.set_engine(true)
	game.audio.set_driving_effects(true, true)
	for index in range(4):
		game.audio.play_pass(0.0, index + 1)
	game.audio.play_effect(&"crash")
	game.audio.play_effect(&"bonus")
	game.audio.play_effect(&"time")
	game.audio.play_effect(&"tick")
	var busy_mix: Dictionary = await window(0.8)
	check(busy_mix.peak <= 0.895 and busy_mix.rms > 0.01, "Overlapping effects remain below the -1 dB ceiling")
	game.audio.set_enabled(false)
	await create_timer(0.12).timeout
	var muted_mix: Dictionary = await window(0.2)
	check(muted_mix.peak < 0.0001, "Muted output is digitally silent")
	print("Engine loop RMS %.4f; busy mix peak %.4f; muted peak %.6f" % [engine_loop.rms, busy_mix.peak, muted_mix.peak])
	AudioServer.remove_bus_effect(0, effect_index)
	game.free()
	await process_frame
	await process_frame
	print("Audio mix: %d failures" % failures)
	quit(0 if failures == 0 else 1)
