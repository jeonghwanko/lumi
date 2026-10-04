extends AudioStreamPlayer
## Small native procedural UI tones, no external audio or paid generation.
var sounds: Dictionary={}
func tone(kind: String, enabled: bool) -> void:
	if not enabled or DisplayServer.get_name()=="headless": return
	if not sounds.has(kind):
		var frequency: float=660.0 if kind=="clear" else (880.0 if kind=="win" else 220.0)
		var duration: float=0.08 if kind=="clear" else 0.26
		var frames=int(22050*duration)
		var bytes=PackedByteArray()
		bytes.resize(frames*2)
		for i in frames:
			var t=float(i)/22050.0
			var envelope=minf(1,t*140)*pow(1-float(i)/frames,2)
			var sample=int(sin(TAU*frequency*t)*envelope*5000)
			bytes.encode_s16(i*2,sample)
		var audio=AudioStreamWAV.new()
		audio.format=AudioStreamWAV.FORMAT_16_BITS
		audio.mix_rate=22050
		audio.data=bytes
		sounds[kind]=audio
	stream=sounds[kind]
	play()

func _exit_tree() -> void:
	stop()
	stream=null
	sounds.clear()
