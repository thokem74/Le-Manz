extends SceneTree
## Record the actual audio controller and bus mix for a repeatable listening review.

var capture := AudioEffectCapture.new()


func _initialize() -> void:
	call_deferred("record")


func play_streak(game: Node, with_engine: bool) -> void:
	game.audio.stop_all()
	game.audio.set_engine(with_engine)
	await create_timer(0.25).timeout
	for number in range(1, 11):
		game.audio.play_pass(-56.0 if number % 2 == 0 else 56.0, number)
		if number == 10:
			game.audio.play_effect(&"bonus")
		await create_timer(0.48 if number < 10 else 1.0).timeout
	game.audio.stop_all()


func record() -> void:
	var destination: String = "res://builds/audio/le-manz-reward-preview.wav"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			destination = argument.trim_prefix("--out=")
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.get_node("Profile").storage_path = "/tmp/le-manz-reward-preview.cfg"
	root.add_child(game)
	game.set_physics_process(false)
	game.audio.set_enabled(true)
	capture.buffer_length = 20.0
	var effect_index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	capture.clear_buffer()
	await play_streak(game, false)
	await create_timer(0.7).timeout
	await play_streak(game, true)
	await create_timer(0.25).timeout
	var frames: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var data := PackedByteArray()
	data.resize(frames.size() * 4)
	var peak: float = 0.0
	for index in range(frames.size()):
		var frame: Vector2 = frames[index]
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		data.encode_s16(index * 4, int(clampf(frame.x, -1.0, 1.0) * 32767.0))
		data.encode_s16(index * 4 + 2, int(clampf(frame.y, -1.0, 1.0) * 32767.0))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = int(AudioServer.get_mix_rate())
	wave.stereo = true
	wave.data = data
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
	var result: Error = wave.save_to_wav(destination)
	print("Reward preview: %.2fs, peak %.4f, %s (%s)" % [wave.get_length(), peak, destination, error_string(result)])
	AudioServer.remove_bus_effect(0, effect_index)
	game.free()
	await process_frame
	await process_frame
	quit(0 if result == OK and peak > 0.01 else 1)
