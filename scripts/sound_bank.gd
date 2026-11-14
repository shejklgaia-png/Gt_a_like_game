extends Node
class_name PocketSoundBank
## Generated PCM sounds: intentionally no downloaded or unlicensed audio assets.
const SAMPLE_RATE := 22050
var sounds: Dictionary = {}
var steps: int = 0
var music: AudioStreamPlayer

func _ready() -> void:
	for key in ["Handgun", "Rifle", "Shotgun", "Sniper", "Machine Gun", "footstep", "impact", "hurt", "cash", "car_door", "engine", "police", "ui", "death"]:
		sounds[key] = make_sound(key)
	music = AudioStreamPlayer.new()
	music.stream = make_music()
	music.volume_db = -28.0
	add_child(music)
	music.play()

func make_music() -> AudioStreamWAV:
	# Original 8-second loop: restrained analog bass, low percussion and urban air.
	var rate := 11025
	var count := 8 * rate
	var data := PackedByteArray()
	data.resize(count * 2)
	var notes := [55.0, 55.0, 65.4, 55.0, 49.0, 55.0, 73.4, 65.4,
		55.0, 55.0, 65.4, 82.4, 49.0, 55.0, 65.4, 49.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4244225
	for sample in range(count):
		var sec := float(sample) / float(rate)
		var beat := fposmod(sec, 0.5)
		var subdivision := fposmod(sec, 0.25)
		var note: float = float(notes[int(sec / 0.5) % notes.size()])
		var bass := sin(TAU * note * sec) * 0.18 + sin(TAU * note * 2.0 * sec) * 0.06
		var kick := sin(TAU * (48.0 + 30.0 * exp(-beat * 17.0)) * beat) * exp(-beat * 19.0) * 0.22
		var click := rng.randf_range(-1.0, 1.0) * exp(-subdivision * 65.0) * 0.018
		var drone := sin(TAU * 27.5 * sec) * 0.046
		var wave := clampf(bass + kick + click + drone, -0.85, 0.85)
		data.encode_s16(sample * 2, int(wave * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.mix_rate = rate
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	return wav

func set_indoors(indoor: bool) -> void:
	if is_instance_valid(music):
		music.volume_db = -35.0 if indoor else -28.0

func make_sound(kind: String) -> AudioStreamWAV:
	var length := 0.18
	var tone := 170.0
	var noise_factor := 0.42
	var decay := 23.0
	match kind:
		"Handgun": length = 0.21; tone = 130.0; noise_factor = 0.72; decay = 18.0
		"Rifle": length = 0.24; tone = 100.0; noise_factor = 0.82; decay = 23.0
		"Shotgun": length = 0.41; tone = 71.0; noise_factor = 0.91; decay = 11.0
		"Sniper": length = 0.45; tone = 64.0; noise_factor = 0.80; decay = 9.0
		"Machine Gun": length = 0.16; tone = 190.0; noise_factor = 0.72; decay = 26.0
		"footstep": length = 0.105; tone = 64.0; noise_factor = 0.35; decay = 35.0
		"impact": length = 0.14; tone = 125.0; noise_factor = 0.85; decay = 24.0
		"hurt": length = 0.30; tone = 135.0; noise_factor = 0.23; decay = 10.0
		"cash": length = 0.27; tone = 600.0; noise_factor = 0.07; decay = 7.0
		"car_door": length = 0.15; tone = 95.0; noise_factor = 0.32; decay = 28.0
		"engine": length = 0.50; tone = 52.0; noise_factor = 0.20; decay = 2.5
		"police": length = 0.45; tone = 650.0; noise_factor = 0.06; decay = 2.1
		"ui": length = 0.08; tone = 470.0; noise_factor = 0.08; decay = 19.0
		"death": length = 0.54; tone = 75.0; noise_factor = 0.43; decay = 5.0
	var count := int(float(SAMPLE_RATE) * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(kind.hash()) + 502
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var envelope := exp(-decay * t)
		var osc := sin(TAU * tone * t) * 0.60 + sin(TAU * tone * 1.92 * t) * 0.2
		if kind == "cash" or kind == "ui":
			osc += sin(TAU * tone * 1.50 * t) * 0.28
		if kind == "police":
			osc = sin(TAU * (650.0 + 240.0 * sin(TAU * 3.5 * t)) * t)
		var wave := (osc * (1.0 - noise_factor) + rng.randf_range(-1.0, 1.0) * noise_factor) * envelope * 0.65
		data.encode_s16(i * 2, clampi(int(wave * 32767.0), -32767, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	if kind == "engine":
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = count
	return wav

func play(kind: String, at: Vector3 = Vector3.ZERO, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	if not sounds.has(kind):
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = sounds[kind]
	player.unit_size = 15.0
	player.max_distance = 100.0
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()

func play_ui(kind: String = "ui", volume_db: float = -9.0) -> void:
	if not sounds.has(kind):
		return
	var player := AudioStreamPlayer.new()
	player.stream = sounds[kind]
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
