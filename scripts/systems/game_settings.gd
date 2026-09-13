extends Node

signal changed(key: String, value: Variant)
const PATH := "user://settings_v12.json"
const DEFAULTS := {
    "quality": 1, "fps": 60, "music": 0.75, "voice": 1.0,
    "sfx": 0.85, "ambience": 0.65, "sensitivity": 1.0,
    "camera_distance": 1.0, "fov": 68.0, "vibration": true,
    "auto_updates": true, "show_fps": false, "aim_assist": true
}
var values: Dictionary = DEFAULTS.duplicate(true)

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var saved := CHKSaveFiles.read_json(PATH)
    for key in DEFAULTS:
        if saved.has(key):
            values[key] = _validated(key, saved[key])
    apply()

func get_value(key: String) -> Variant:
    return values.get(key, DEFAULTS.get(key))

func set_value(key: String, value: Variant) -> void:
    if not DEFAULTS.has(key):
        return
    values[key] = _validated(key, value)
    apply()
    var result := CHKSaveFiles.write_json(PATH, values)
    if result != OK:
        push_warning("Réglages non sauvegardés : %s" % error_string(result))
    changed.emit(key, values[key])

func _validated(key: String, value: Variant) -> Variant:
    var fallback: Variant = DEFAULTS[key]
    if fallback is bool:
        return value if value is bool else fallback
    if not (value is float or value is int) or not is_finite(float(value)):
        return fallback
    match key:
        "quality": return clampi(int(value), 0, 2)
        "fps": return 30 if int(value) == 30 else 60
        "sensitivity": return clampf(float(value), 0.35, 2.0)
        "camera_distance": return clampf(float(value), 0.85, 1.7)
        "fov": return clampf(float(value), 55.0, 85.0)
        _: return clampf(float(value), 0.0, 1.0)

func apply() -> void:
    Engine.max_fps = int(values.fps)
    var viewport := get_viewport()
    if viewport != null:
        viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(values.quality)]
        viewport.scaling_3d_scale = [0.75, 0.9, 1.0][int(values.quality)]
    for pair in [["Music", "music"], ["Voice", "voice"], ["SFX", "sfx"], ["Ambience", "ambience"]]:
        var bus := AudioServer.get_bus_index(pair[0])
        if bus >= 0:
            var volume := float(values[pair[1]])
            AudioServer.set_bus_mute(bus, volume <= 0.001)
            AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))

func vibrate(duration_ms: int = 25) -> void:
    if bool(values.vibration) and OS.has_feature("android"):
        Input.vibrate_handheld(duration_ms)
