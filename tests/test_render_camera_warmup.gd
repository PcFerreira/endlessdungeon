extends SceneTree

const Warmup = preload("res://scripts/render_warmup.gd")

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18
	var warmup := Warmup.new()
	warmup.main_camera = camera
	warmup._begin_scene()
	# A destination snap can run after the loading step starts.
	camera.size = 9
	warmup._process(0)
	var covered := camera.size >= 160 and warmup.busy
	warmup._after_draw()
	var pending := warmup.busy
	warmup._after_draw()
	var restored := camera.size == 18 and not warmup.busy
	warmup.free()
	camera.free()
	if not covered or not pending or not restored:
		push_error("Loading must preserve the wide camera coverage through both drawn frames, then restore the player's zoom")
		quit(1)
		return
	print("PASS: destination camera changes cannot shrink loading coverage; two draws restore player zoom")
	quit()
