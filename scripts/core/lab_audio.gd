class_name LabAudio
extends Node
## Small procedural UI feedback sounds. No external audio assets are required.
## Sound is optional and can be disabled from the Session menu.

const SAMPLE_RATE := 22050
const DEFAULT_VOLUME_DB := -15.0

var enabled: bool = true
var _player: AudioStreamPlayer
var _streams: Dictionary = {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "FeedbackPlayer"
	_player.volume_db = DEFAULT_VOLUME_DB
	add_child(_player)
	_streams["tap"] = _make_tone(620.0, 0.045, 0.10)
	_streams["pour"] = _make_tone(390.0, 0.10, 0.13)
	_streams["warm"] = _make_tone(520.0, 0.075, 0.10)
	_streams["warning"] = _make_tone(240.0, 0.11, 0.09)
	_streams["observe"] = _make_tone(740.0, 0.085, 0.08)


func bind() -> void:
	if not EventBus.command_logged.is_connected(_on_command_logged):
		EventBus.command_logged.connect(_on_command_logged)
	if not EventBus.observation_added.is_connected(_on_observation_added):
		EventBus.observation_added.connect(_on_observation_added)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled and _player != null:
		_player.stop()


func play_feedback(kind: String) -> void:
	if not enabled or _player == null or not _streams.has(kind):
		return
	_player.stream = _streams[kind] as AudioStream
	_player.play()


func _on_command_logged(entry: Dictionary) -> void:
	if not bool(entry.get("ok", false)):
		play_feedback("warning")
		return
	match str(entry.get("command", "")):
		"pour", "add_solid":
			play_feedback("pour")
		"heat":
			play_feedback("warm")
		"mix":
			play_feedback("tap")
		"place", "pick_up", "undo", "redo":
			play_feedback("tap")


func _on_observation_added(_object_id: String, _entry: Dictionary) -> void:
	play_feedback("observe")


func _make_tone(frequency: float, duration_s: float, amplitude: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var sample_count := maxi(1, int(round(duration_s * float(SAMPLE_RATE))))
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for index in range(sample_count):
		var phase := float(index) / float(SAMPLE_RATE)
		var progress := float(index) / float(sample_count)
		var attack := clampf(progress / 0.08, 0.0, 1.0)
		var release := clampf((1.0 - progress) / 0.22, 0.0, 1.0)
		var envelope := minf(attack, release)
		var sample := sin(TAU * frequency * phase) * amplitude * envelope
		samples.encode_s16(index * 2, int(round(sample * 32767.0)))
	stream.data = samples
	return stream
