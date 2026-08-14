class_name ExtremeUICustomizerV11_3
extends CanvasLayer

const SAVE_PATH := "user://ui_extreme_v11_3.cfg"
const MIN_SCALE := 0.35
const MAX_SCALE := 2.25
const SCALE_STEP := 0.05
const MIN_ALPHA := 0.25
const MAX_ALPHA := 1.0
const ALPHA_STEP := 0.10
const TARGET_REFRESH_SECONDS := 0.75

var _config := ConfigFile.new()
var _edit_mode := false
var _selected: Control
var _drag_touch_id := -1
var _mouse_drag := false
var _drag_offset := Vector2.ZERO
var _scan_accumulator := 0.0
var _known_targets: Array[Control] = []

var _selection: Panel
var _toolbar: Panel
var _title: Label
var _smaller: Button
var _bigger: Button
var _less_alpha: Button
var _more_alpha: Button
var _reset_one: Button
var _reset_all: Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 245
    add_to_group("ui_extreme_customizer")
    set_process_input(true)
    _config.load(SAVE_PATH)
    _build_editor_ui()
    get_viewport().size_changed.connect(_on_viewport_changed)
    _refresh_targets.call_deferred()

func _process(delta: float) -> void:
    _scan_accumulator += delta
    if _scan_accumulator < TARGET_REFRESH_SECONDS:
        return
    _scan_accumulator = 0.0
    _refresh_targets()

func set_edit_mode(enabled: bool) -> void:
    _edit_mode = enabled
    _selected = null
    _drag_touch_id = -1
    _mouse_drag = false
    _selection.visible = false
    _toolbar.visible = false
    _refresh_targets()
    if not enabled:
        _config.save(SAVE_PATH)

func is_edit_mode() -> bool:
    return _edit_mode

func _build_editor_ui() -> void:
    _selection = Panel.new()
    _selection.name = "ExtremeUISelectionV11_3"
    _selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _selection.visible = false
    _selection.z_index = 900
    var selection_style := StyleBoxFlat.new()
    selection_style.bg_color = Color(0.20, 0.75, 1.0, 0.07)
    selection_style.border_color = Color("71d5ff")
    selection_style.set_border_width_all(4)
    selection_style.set_corner_radius_all(12)
    _selection.add_theme_stylebox_override("panel", selection_style)
    add_child(_selection)

    _toolbar = Panel.new()
    _toolbar.name = "ExtremeUIToolbarV11_3"
    _toolbar.visible = false
    _toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
    _toolbar.z_index = 910
    var toolbar_style := StyleBoxFlat.new()
    toolbar_style.bg_color = Color(0.012, 0.035, 0.050, 0.97)
    toolbar_style.border_color = Color("71d5ff")
    toolbar_style.set_border_width_all(2)
    toolbar_style.set_corner_radius_all(12)
    _toolbar.add_theme_stylebox_override("panel", toolbar_style)
    add_child(_toolbar)

    _title = Label.new()
    _title.text = "CASE"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _title.add_theme_font_size_override("font_size", 14)
    _title.add_theme_color_override("font_color", Color("dff7ff"))
    _toolbar.add_child(_title)

    _smaller = _editor_button("TAILLE −")
    _smaller.pressed.connect(func(): _resize_selected(-SCALE_STEP))
    _toolbar.add_child(_smaller)
    _bigger = _editor_button("TAILLE +")
    _bigger.pressed.connect(func(): _resize_selected(SCALE_STEP))
    _toolbar.add_child(_bigger)
    _less_alpha = _editor_button("OPAC. −")
    _less_alpha.pressed.connect(func(): _change_alpha(-ALPHA_STEP))
    _toolbar.add_child(_less_alpha)
    _more_alpha = _editor_button("OPAC. +")
    _more_alpha.pressed.connect(func(): _change_alpha(ALPHA_STEP))
    _toolbar.add_child(_more_alpha)
    _reset_one = _editor_button("RÉINIT. CASE")
    _reset_one.pressed.connect(_reset_selected)
    _toolbar.add_child(_reset_one)
    _reset_all = _editor_button("TOUT RÉINIT.")
    _reset_all.pressed.connect(_reset_everything)
    _toolbar.add_child(_reset_all)

func _editor_button(text_value: String) -> Button:
    var button := Button.new()
    button.text = text_value
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 12)
    button.add_theme_color_override("font_color", Color("effaff"))
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.03, 0.09, 0.12, 0.98)
    style.border_color = Color("4c9fbd")
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    button.add_theme_stylebox_override("normal", style)
    var pressed := style.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.07, 0.20, 0.26, 0.98)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("hover", pressed)
    return button

func _layout_editor() -> void:
    if _toolbar == null:
        return
    var viewport := get_viewport().get_visible_rect().size
    var width := minf(790.0, viewport.x - 24.0)
    var height := 98.0
    _toolbar.size = Vector2(width, height)
    _toolbar.position = Vector2((viewport.x - width) * 0.5, maxf(8.0, viewport.y - height - 68.0))

    _title.position = Vector2(10.0, 5.0)
    _title.size = Vector2(width - 20.0, 28.0)
    var gap := 6.0
    var button_y := 38.0
    var button_h := 48.0
    var button_w := (width - 20.0 - gap * 5.0) / 6.0
    var buttons := [_smaller, _bigger, _less_alpha, _more_alpha, _reset_one, _reset_all]
    for i in range(buttons.size()):
        var button: Button = buttons[i]
        button.position = Vector2(10.0 + float(i) * (button_w + gap), button_y)
        button.size = Vector2(button_w, button_h)

func _refresh_targets() -> void:
    _known_targets.clear()
    var root := get_tree().current_scene
    if root == null:
        return
    var canvas_layers := root.find_children("*", "CanvasLayer", true, false)
    for raw_layer in canvas_layers:
        if raw_layer == self or not raw_layer is CanvasLayer:
            continue
        var layer := raw_layer as CanvasLayer
        if not layer.visible:
            continue
        _collect_targets(layer)
    _apply_saved_layouts()

func _collect_targets(node: Node) -> void:
    for child in node.get_children():
        if child == self or is_ancestor_of(child):
            continue
        if child is Control:
            var control := child as Control
            if _is_editable_box(control) and not _known_targets.has(control):
                _remember_default(control)
                _known_targets.append(control)
        _collect_targets(child)

func _is_editable_box(control: Control) -> bool:
    if control == null or not is_instance_valid(control) or not control.visible:
        return false
    if control.mouse_filter == Control.MOUSE_FILTER_IGNORE and not (control is Panel or control is PanelContainer):
        return false
    if str(control.name).begins_with("TouchLayout"):
        return false
    if str(control.name).begins_with("ExtremeUI"):
        return false
    if control.get_parent() is Container and not (control is PanelContainer):
        return false
    if control is Panel or control is PanelContainer:
        return control.size.x >= 40.0 and control.size.y >= 28.0
    if control is Button:
        return control.size.x >= 42.0 and control.size.y >= 28.0
    return false

func _remember_default(control: Control) -> void:
    if control.has_meta("v11_3_ui_default_saved"):
        return
    control.set_meta("v11_3_ui_default_saved", true)
    control.set_meta("v11_3_ui_default_global_position", control.global_position)
    control.set_meta("v11_3_ui_default_scale", control.scale)
    control.set_meta("v11_3_ui_default_modulate", control.modulate)
    control.pivot_offset = control.size * 0.5

func _input(event: InputEvent) -> void:
    if not _edit_mode:
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if _editor_owns_point(touch.position):
            return
        if touch.pressed and _drag_touch_id == -1:
            var picked := _pick_target(touch.position)
            if picked != null:
                _select(picked)
                _drag_touch_id = touch.index
                _drag_offset = touch.position - picked.global_position
                get_viewport().set_input_as_handled()
        elif not touch.pressed and touch.index == _drag_touch_id:
            _drag_touch_id = -1
            _save_selected()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _drag_touch_id and _selected != null:
            _move_selected(drag.position - _drag_offset)
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index != MOUSE_BUTTON_LEFT or _editor_owns_point(mouse.position):
            return
        if mouse.pressed:
            var picked := _pick_target(mouse.position)
            if picked != null:
                _select(picked)
                _mouse_drag = true
                _drag_offset = mouse.position - picked.global_position
                get_viewport().set_input_as_handled()
        elif _mouse_drag:
            _mouse_drag = false
            _save_selected()
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _mouse_drag and _selected != null:
        var motion := event as InputEventMouseMotion
        _move_selected(motion.position - _drag_offset)
        get_viewport().set_input_as_handled()

func _editor_owns_point(point: Vector2) -> bool:
    if _toolbar.visible and _toolbar.get_global_rect().has_point(point):
        return true
    for name_value in ["TouchLayoutSmaller", "TouchLayoutBigger", "TouchLayoutReset", "TouchLayoutDone"]:
        var candidate := get_tree().root.find_child(name_value, true, false)
        if candidate is Control and (candidate as Control).visible and (candidate as Control).get_global_rect().has_point(point):
            return true
    return false

func _pick_target(point: Vector2) -> Control:
    var best: Control = null
    var best_area := INF
    for control in _known_targets:
        if control == null or not is_instance_valid(control) or not control.visible:
            continue
        var rect := _display_rect(control)
        if rect.has_point(point):
            var area := rect.size.x * rect.size.y
            if area < best_area:
                best_area = area
                best = control
    return best

func _select(control: Control) -> void:
    _selected = control
    _selection.visible = true
    _toolbar.visible = true
    _layout_editor()
    _update_selection_frame()
    _refresh_title()

func _move_selected(global_target: Vector2) -> void:
    if _selected == null:
        return
    var viewport := get_viewport().get_visible_rect().size
    var display_size := _selected.size * _selected.scale.abs()
    var clamped := Vector2(
        clampf(global_target.x, 4.0, maxf(4.0, viewport.x - display_size.x - 4.0)),
        clampf(global_target.y, 4.0, maxf(4.0, viewport.y - display_size.y - 4.0))
    )
    _selected.global_position = clamped
    _update_selection_frame()

func _resize_selected(delta_value: float) -> void:
    if _selected == null:
        return
    var center := _display_rect(_selected).get_center()
    var current := maxf(0.01, _selected.scale.x)
    var next := clampf(current + delta_value, MIN_SCALE, MAX_SCALE)
    _selected.scale = Vector2.ONE * next
    _selected.pivot_offset = _selected.size * 0.5
    var display_size := _selected.size * next
    _move_selected(center - display_size * 0.5)
    _save_selected()
    _refresh_title()

func _change_alpha(delta_value: float) -> void:
    if _selected == null:
        return
    var alpha := clampf(_selected.modulate.a + delta_value, MIN_ALPHA, MAX_ALPHA)
    var color := _selected.modulate
    color.a = alpha
    _selected.modulate = color
    _save_selected()
    _refresh_title()

func _reset_selected() -> void:
    if _selected == null:
        return
    var key := _target_key(_selected)
    if _config.has_section(key):
        _config.erase_section(key)
    _restore_default(_selected)
    _config.save(SAVE_PATH)
    _update_selection_frame()
    _refresh_title()

func _reset_everything() -> void:
    _config.clear()
    for control in _known_targets:
        if control != null and is_instance_valid(control):
            _restore_default(control)
    _config.save(SAVE_PATH)
    _selected = null
    _selection.visible = false
    _toolbar.visible = false

func _restore_default(control: Control) -> void:
    var default_pos = control.get_meta("v11_3_ui_default_global_position", control.global_position)
    var default_scale = control.get_meta("v11_3_ui_default_scale", Vector2.ONE)
    var default_modulate = control.get_meta("v11_3_ui_default_modulate", Color.WHITE)
    if default_pos is Vector2:
        control.global_position = default_pos
    if default_scale is Vector2:
        control.scale = default_scale
    if default_modulate is Color:
        control.modulate = default_modulate

func _save_selected() -> void:
    if _selected == null or not is_instance_valid(_selected):
        return
    var viewport := get_viewport().get_visible_rect().size
    if viewport.x <= 1.0 or viewport.y <= 1.0:
        return
    var rect := _display_rect(_selected)
    var center := rect.get_center()
    var key := _target_key(_selected)
    _config.set_value(key, "center", Vector2(center.x / viewport.x, center.y / viewport.y))
    _config.set_value(key, "scale", _selected.scale.x)
    _config.set_value(key, "alpha", _selected.modulate.a)
    _config.save(SAVE_PATH)

func _apply_saved_layouts() -> void:
    var viewport := get_viewport().get_visible_rect().size
    if viewport.x <= 1.0 or viewport.y <= 1.0:
        return
    for control in _known_targets:
        if control == null or not is_instance_valid(control):
            continue
        var key := _target_key(control)
        if not _config.has_section(key):
            continue
        var scale_value := clampf(float(_config.get_value(key, "scale", control.scale.x)), MIN_SCALE, MAX_SCALE)
        var alpha_value := clampf(float(_config.get_value(key, "alpha", control.modulate.a)), MIN_ALPHA, MAX_ALPHA)
        control.scale = Vector2.ONE * scale_value
        control.pivot_offset = control.size * 0.5
        var color := control.modulate
        color.a = alpha_value
        control.modulate = color
        if _config.has_section_key(key, "center"):
            var normalized = _config.get_value(key, "center", Vector2(0.5, 0.5))
            if normalized is Vector2:
                var display_size := control.size * scale_value
                var center := Vector2(normalized.x * viewport.x, normalized.y * viewport.y)
                control.global_position = center - display_size * 0.5
    _update_selection_frame()

func _target_key(control: Control) -> String:
    var label := str(control.name)
    if control is Button:
        var text_value := (control as Button).text.replace("\n", "_").strip_edges()
        if not text_value.is_empty():
            label = "%s_%s" % [label, text_value]
    var owner_name := "UI"
    var cursor: Node = control
    while cursor != null:
        if cursor is CanvasLayer:
            owner_name = str(cursor.name)
            break
        cursor = cursor.get_parent()
    return "%s__%s" % [owner_name, label]

func _display_rect(control: Control) -> Rect2:
    var size_value := control.size * control.scale.abs()
    return Rect2(control.global_position, size_value)

func _update_selection_frame() -> void:
    if not _edit_mode or _selected == null or not is_instance_valid(_selected):
        _selection.visible = false
        return
    var rect := _display_rect(_selected)
    _selection.position = rect.position - Vector2(5.0, 5.0)
    _selection.size = rect.size + Vector2(10.0, 10.0)

func _refresh_title() -> void:
    if _selected == null:
        return
    var display_name := str(_selected.name).replace("@", "")
    if _selected is Button and not ( _selected as Button).text.strip_edges().is_empty():
        display_name = ( _selected as Button).text.replace("\n", " ")
    _title.text = "%s • TAILLE %d%% • OPACITÉ %d%% • GLISSE POUR DÉPLACER" % [
        display_name.to_upper(),
        roundi(_selected.scale.x * 100.0),
        roundi(_selected.modulate.a * 100.0)
    ]

func _on_viewport_changed() -> void:
    _layout_editor()
    _apply_saved_layouts.call_deferred()
