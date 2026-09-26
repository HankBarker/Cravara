extends RefCounted
## Pass 15: raising a ring world takes several seconds inside one frame.
## Between its steps the window's messages are seen to, so the system doesn't
## mark it "Not Responding" (the loading card stays up; the session holds off
## input until its boot is done, ForestPlaytest._ready).

static var _last := 0


static func breathe() -> void:
	if DisplayServer.get_name() == "headless": return
	var now := Time.get_ticks_msec()
	if now - _last < 250: return
	_last = now
	DisplayServer.process_events()
