extends CanvasLayer

const VirtualJoystickScript = preload("res://scripts/ui/virtual_joystick.gd")

var _movement: Control
var _camera: Control

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 30

    _movement = VirtualJoystickScript.new()
    _movement.name = "MovementJoystickInput"
    _movement.mode = "movement"
    _movement.draw_visuals = true
    _movement.size = Vector2(190, 190)
    add_child(_movement)

    _camera = VirtualJoystickScript.new()
    _camera.name = "CameraJoystickInput"
    _camera.mode = "camera"
    _camera.draw_visuals = true
    _camera.size = Vector2(145, 145)
    add_child(_camera)

    get_viewport().size_changed.connect(_layout_controls)
    _layout_controls.call_deferred()

func _layout_controls() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    if _movement != null:
        _movement.position = Vector2(42.0, maxf(20.0, viewport_size.y - 232.0))
    if _camera != null:
        _camera.position = Vector2(282.0, maxf(20.0, viewport_size.y - 190.0))
