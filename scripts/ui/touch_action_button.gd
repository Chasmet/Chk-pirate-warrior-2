class_name TouchActionButton
extends Control

signal activated()
signal released()

var action_name: StringName = &""
var round_button := false
var font_size := 18
var enabled := true

var _button_text := ""
var _touch_id := -1
var _mouse_down := false
var _pressed := false
var _label: Label

func configure(text_value: String, action: StringName, circular: bool, text_size: int) -> void:
    _button_text = text_value
    action_name = action
    round_button = circular
    font_size = text_size
    if _label != null:
        _refresh_label()
    queue_redraw()

func _ready() -> void:
    add_to_group("touch_action_button")
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_NONE
    _label = Label.new()
    _label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(_label)
    _refresh_label()
    queue_redraw()

func _exit_tree() -> void:
    _release_button()

func set_button_text(value: String) -> void:
    _button_text = value
    if _label != null:
        _refresh_label()

func set_enabled(value: bool) -> void:
    if enabled == value:
        return
    enabled = value
    if not enabled:
        _release_button()
    modulate = Color.WHITE if enabled else Color(0.62, 0.62, 0.62, 0.66)
    queue_redraw()

func is_button_pressed() -> bool:
    return _pressed

func _gui_input(event: InputEvent) -> void:
    if not enabled:
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _touch_id == -1:
            _touch_id = touch.index
            _press_button()
            accept_event()
        elif not touch.pressed and touch.index == _touch_id:
            _touch_id = -1
            _release_button()
            accept_event()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _touch_id:
            accept_event()
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_LEFT:
            _mouse_down = mouse.pressed
            if _mouse_down:
                _press_button()
            else:
                _release_button()
            accept_event()

func _press_button() -> void:
    if _pressed or not enabled:
        return
    _pressed = true
    if not action_name.is_empty():
        Input.action_press(action_name)
    activated.emit()
    Input.vibrate_handheld(10)
    queue_redraw()

func _release_button() -> void:
    if not _pressed:
        return
    _pressed = false
    if not action_name.is_empty():
        Input.action_release(action_name)
    released.emit()
    queue_redraw()

func _refresh_label() -> void:
    _label.text = _button_text
    _label.add_theme_font_size_override("font_size", font_size)
    _label.add_theme_color_override("font_color", Color("f9e6a5"))
    _label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
    _label.add_theme_constant_override("shadow_offset_x", 2)
    _label.add_theme_constant_override("shadow_offset_y", 2)

func _draw() -> void:
    var fill := Color(0.23, 0.15, 0.025, 0.97) if _pressed else Color(0.02, 0.055, 0.075, 0.86)
    var border := Color("ffe08a") if _pressed else Color(0.91, 0.68, 0.20, 0.96)
    if round_button:
        var radius := minf(size.x, size.y) * 0.5 - 3.0
        var center := size * 0.5
        draw_circle(center, radius, fill)
        draw_arc(center, radius, 0.0, TAU, 64, border, 4.0, true)
        return
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(4)
    style.set_corner_radius_all(18)
    draw_style_box(style, Rect2(Vector2.ZERO, size))
