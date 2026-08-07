extends CanvasLayer

const VirtualJoystickScript = preload("res://scripts/ui/virtual_joystick.gd")

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 20

    var movement = VirtualJoystickScript.new()
    movement.name = "MovementJoystickInput"
    movement.mode = "movement"
    movement.draw_visuals = false
    movement.position = Vector2(38, 760)
    movement.size = Vector2(145, 175)
    add_child(movement)

    var camera = VirtualJoystickScript.new()
    camera.name = "CameraJoystickInput"
    camera.mode = "camera"
    camera.draw_visuals = false
    camera.position = Vector2(255, 805)
    camera.size = Vector2(110, 140)
    add_child(camera)
