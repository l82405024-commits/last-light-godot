extends Node

# Процедурный синтезатор звуков: атмосферный ветер, выстрел дробовика, звуки зомби и сонара

var player_wind: AudioStreamPlayer
var player_sfx: AudioStreamPlayer
var playback_wind: AudioStreamGeneratorPlayback
var sample_rate: float = 22050.0
var wind_filter: float = 0.0

func _ready() -> void:
	add_to_group("sound_synth")
	# 1. Генератор ветра
	player_wind = AudioStreamPlayer.new()
	var gen_wind = AudioStreamGenerator.new()
	gen_wind.mix_rate = sample_rate
	gen_wind.buffer_length = 0.15
	player_wind.stream = gen_wind
	player_wind.volume_db = -12.0
	add_child(player_wind)
	player_wind.play()
	playback_wind = player_wind.get_stream_playback()

	# 2. SFX плеер
	player_sfx = AudioStreamPlayer.new()
	player_sfx.volume_db = 0.0
	add_child(player_sfx)

func _process(_delta: float) -> void:
	if playback_wind:
		_fill_wind_buffer()

func _fill_wind_buffer() -> void:
	var frames_avail = playback_wind.get_frames_available()
	while frames_avail > 0:
		var white_noise = (randf() * 2.0 - 1.0)
		wind_filter = lerpf(wind_filter, white_noise, 0.045)
		var sample = wind_filter * 0.35
		playback_wind.push_frame(Vector2(sample, sample))
		frames_avail -= 1

func play_click() -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.05
	player_sfx.stream = gen
	player_sfx.play()
	var pb = player_sfx.get_stream_playback()
	if pb:
		for i in range(int(22050 * 0.03)):
			var t = float(i) / 22050.0
			var s = sin(t * 1200.0 * TAU) * exp(-t * 120.0)
			pb.push_frame(Vector2(s, s))

func play_scanner_ping() -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.35
	player_sfx.stream = gen
	player_sfx.play()
	var pb = player_sfx.get_stream_playback()
	if pb:
		var total_frames = int(22050 * 0.28)
		for i in range(total_frames):
			var t = float(i) / 22050.0
			var freq = 450.0 + t * 900.0
			var env = sin((float(i) / float(total_frames)) * PI)
			var s = sin(t * freq * TAU) * env * 0.5
			pb.push_frame(Vector2(s, s))

func play_shotgun_blast() -> void:
	# Мощный взрывной выстрел дробовика (басовый удар + шумовой взрыв)
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.4
	player_sfx.stream = gen
	player_sfx.play()
	var pb = player_sfx.get_stream_playback()
	if pb:
		var total = int(22050 * 0.35)
		for i in range(total):
			var t = float(i) / 22050.0
			var env = exp(-t * 14.0)
			var bass = sin(t * (120.0 - t * 80.0) * TAU)
			var crack = (randf() * 2.0 - 1.0) * exp(-t * 30.0)
			var s = clampf((bass * 0.7 + crack * 0.6) * env, -1.0, 1.0)
			pb.push_frame(Vector2(s, s))

func play_reload() -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.3
	player_sfx.stream = gen
	player_sfx.play()
	var pb = player_sfx.get_stream_playback()
	if pb:
		var total = int(22050 * 0.25)
		for i in range(total):
			var t = float(i) / 22050.0
			var s = (randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.4
			pb.push_frame(Vector2(s, s))

func play_zombie_groan() -> void:
	# Хриплый низкий рык мутанта
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.5
	player_sfx.stream = gen
	player_sfx.play()
	var pb = player_sfx.get_stream_playback()
	if pb:
		var total = int(22050 * 0.45)
		for i in range(total):
			var t = float(i) / 22050.0
			var freq = 65.0 + sin(t * 12.0) * 20.0
			var s = (sin(t * freq * TAU) + (randf() - 0.5) * 0.3) * sin((float(i) / float(total)) * PI) * 0.45
			pb.push_frame(Vector2(s, s))

func play_zombie_hit() -> void:
	# Шлепок попадания по плоти
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.12
	player_sfx.stream = gen
	player_sfx.play()
	var pb = player_sfx.get_stream_playback()
	if pb:
		var total = int(22050 * 0.1)
		for i in range(total):
			var t = float(i) / 22050.0
			var s = ((randf() - 0.5) * 0.8 + sin(t * 80.0 * TAU) * 0.5) * exp(-t * 45.0)
			pb.push_frame(Vector2(s, s))
