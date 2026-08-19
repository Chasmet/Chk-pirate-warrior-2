extends CanvasLayer

const TROPHY_ASSET = preload("res://scripts/ui/final_trophy_asset.gd")
const IMAGE_ASPECT := 1.5
const ENDGAME_FLAG := "endgame_trophy_seen"

var _root: Control
var _frame: Control
var _trophy_material: ShaderMaterial
var _drag_area: Control
var _dragging := false
var _yaw := 0.0
var _pitch := 0.0
var _yaw_velocity := 0.0
var _pitch_velocity := 0.0
var _end_screen_open := false

func _ready() -> void:
	layer = 240
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	get_viewport().size_changed.connect(_fit_frame)
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_signal("progression_changed"):
		game_state.progression_changed.connect(_on_progression_changed)
	call_deferred("_check_completion")

func _process(delta: float) -> void:
	if not _end_screen_open or _dragging or _trophy_material == null:
		return
	_yaw = fmod(_yaw + _yaw_velocity * delta, TAU)
	_pitch = clampf(_pitch + _pitch_velocity * delta, -0.72, 0.72)
	_yaw_velocity = move_toward(_yaw_velocity, 0.0, 3.5 * delta)
	_pitch_velocity = move_toward(_pitch_velocity, 0.0, 3.2 * delta)
	if absf(_pitch_velocity) < 0.08:
		_pitch = lerpf(_pitch, 0.0, minf(1.0, 1.1 * delta))
	_apply_trophy_rotation()

func _build_interface() -> void:
	_root = Control.new()
	_root.name = "EndgameTrophyRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var blackout := ColorRect.new()
	blackout.color = Color(0.004, 0.004, 0.008, 1.0)
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(blackout)

	_frame = Control.new()
	_frame.name = "TrophyFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_frame)

	var texture := _load_trophy_texture()
	if texture == null:
		push_error("CHK Endgame: impossible de charger l'image du trophée")
		return

	var base := TextureRect.new()
	base.name = "EndgameImage"
	base.texture = texture
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(base)

	var rays := ColorRect.new()
	rays.name = "LivingRedRays"
	rays.color = Color.WHITE
	rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.material = _make_rays_material()
	_frame.add_child(rays)

	var trophy_cover := ColorRect.new()
	trophy_cover.name = "TrophyBackgroundRegenerator"
	trophy_cover.color = Color.WHITE
	trophy_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trophy_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trophy_cover.material = _make_cover_material()
	_frame.add_child(trophy_cover)

	var trophy := TextureRect.new()
	trophy.name = "InteractiveTrophy"
	trophy.texture = texture
	trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy.stretch_mode = TextureRect.STRETCH_SCALE
	trophy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trophy_material = _make_trophy_material()
	trophy.material = _trophy_material
	_frame.add_child(trophy)

	var sparkle := ColorRect.new()
	sparkle.name = "GoldenSparkles"
	sparkle.color = Color.WHITE
	sparkle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkle.material = _make_sparkle_material()
	_frame.add_child(sparkle)

	_drag_area = Control.new()
	_drag_area.name = "TrophyTouchArea"
	_drag_area.anchor_left = 0.19
	_drag_area.anchor_top = 0.07
	_drag_area.anchor_right = 0.81
	_drag_area.anchor_bottom = 0.84
	_drag_area.offset_left = 0.0
	_drag_area.offset_top = 0.0
	_drag_area.offset_right = 0.0
	_drag_area.offset_bottom = 0.0
	_drag_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_area.gui_input.connect(_on_trophy_input)
	_frame.add_child(_drag_area)

	var continue_button := _make_button("CONTINUE")
	continue_button.name = "ContinueButton"
	continue_button.anchor_left = 0.043
	continue_button.anchor_top = 0.865
	continue_button.anchor_right = 0.300
	continue_button.anchor_bottom = 0.972
	continue_button.pressed.connect(_continue_game)
	_frame.add_child(continue_button)

	var restart_button := _make_button("RECOMMENCER")
	restart_button.name = "RestartButton"
	restart_button.anchor_left = 0.684
	restart_button.anchor_top = 0.865
	restart_button.anchor_right = 0.948
	restart_button.anchor_bottom = 0.972
	restart_button.pressed.connect(_restart_game)
	_frame.add_child(restart_button)

	_fit_frame()
	_apply_trophy_rotation()

func _load_trophy_texture() -> Texture2D:
	var raw := Marshalls.base64_to_raw(TROPHY_ASSET.webp_base64())
	if raw.is_empty():
		return null
	var image := Image.new()
	var error := image.load_webp_from_buffer(raw)
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)

func _fit_frame() -> void:
	if _root == null or _frame == null:
		return
	var viewport_size := _root.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport().get_visible_rect().size
	var frame_size := Vector2.ZERO
	if viewport_size.x / maxf(1.0, viewport_size.y) >= IMAGE_ASPECT:
		frame_size = Vector2(viewport_size.y * IMAGE_ASPECT, viewport_size.y)
	else:
		frame_size = Vector2(viewport_size.x, viewport_size.x / IMAGE_ASPECT)
	_frame.position = (viewport_size - frame_size) * 0.5
	_frame.size = frame_size

func _make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color(0.035, 0.035, 0.035, 1.0))
	button.add_theme_color_override("font_hover_color", Color.BLACK)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 0.78, 0.035, 0.98)
	normal.border_color = Color(0.15, 0.12, 0.03, 1.0)
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(13)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	normal.shadow_size = 7
	normal.shadow_offset = Vector2(0.0, 4.0)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.87, 0.15, 1.0)
	hover.border_color = Color(1.0, 0.93, 0.52, 1.0)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.96, 0.59, 0.02, 1.0)
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0.0, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)
	return button

func _make_rays_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add;

void fragment() {
	vec2 p = UV - vec2(0.5, 0.46);
	p.x *= 1.5;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float broad = pow(max(0.0, 0.5 + 0.5 * cos(angle * 22.0 - TIME * 0.34)), 5.0);
	float fine = pow(max(0.0, 0.5 + 0.5 * sin(angle * 44.0 + TIME * 0.72)), 12.0);
	float pulse = 0.68 + 0.32 * sin(TIME * 2.8 - radius * 19.0);
	float fade = smoothstep(0.74, 0.05, radius) * smoothstep(0.02, 0.16, radius);
	float strength = (0.20 * broad + 0.32 * fine) * pulse * fade;
	vec3 red = vec3(1.0, 0.035, 0.012) * strength;
	COLOR = vec4(red, strength * 0.75);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _make_cover_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_mix;

void fragment() {
	vec2 p = UV - vec2(0.5, 0.49);
	vec2 e = vec2(p.x / 0.33, p.y / 0.49);
	float ellipse = length(e);
	float alpha = 1.0 - smoothstep(0.78, 1.03, ellipse);
	p.x *= 1.5;
	float angle = atan(p.y, p.x);
	float radius = length(p);
	float ray = pow(max(0.0, 0.5 + 0.5 * cos(angle * 22.0 - TIME * 0.28)), 6.0);
	float pulse = 0.72 + 0.28 * sin(TIME * 2.2 - radius * 16.0);
	vec3 black_red = mix(vec3(0.008, 0.006, 0.009), vec3(0.30, 0.008, 0.005), ray * pulse);
	COLOR = vec4(black_red, alpha * 0.98);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _make_trophy_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_mix;

uniform float yaw = 0.0;
uniform float pitch = 0.0;

float box_mask(vec2 uv, vec2 lo, vec2 hi, float feather) {
	float x1 = smoothstep(lo.x, lo.x + feather, uv.x);
	float x2 = 1.0 - smoothstep(hi.x - feather, hi.x, uv.x);
	float y1 = smoothstep(lo.y, lo.y + feather, uv.y);
	float y2 = 1.0 - smoothstep(hi.y - feather, hi.y, uv.y);
	return x1 * x2 * y1 * y2;
}

void fragment() {
	vec2 center = vec2(0.5, 0.50);
	vec2 p = UV - center;
	float c = cos(yaw);
	float safe_c = (c < 0.0 ? -1.0 : 1.0) * max(abs(c), 0.105);
	float sy = max(cos(pitch), 0.62);
	vec2 src = center;
	src.x += p.x / safe_c;
	src.y += (p.y - sin(pitch) * p.x * 0.20) / sy;

	if (src.x < 0.0 || src.x > 1.0 || src.y < 0.0 || src.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 texel = texture(TEXTURE, src);
		float luma = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
		float gold = smoothstep(0.055, 0.24, texel.r - texel.b)
			* smoothstep(0.020, 0.18, texel.g - texel.b)
			* smoothstep(0.20, 0.58, texel.r);
		float gold_area = box_mask(src, vec2(0.195, 0.075), vec2(0.805, 0.875), 0.018);
		float base_area = box_mask(src, vec2(0.285, 0.725), vec2(0.715, 0.958), 0.012);
		float dark_base = base_area * (1.0 - smoothstep(0.20, 0.38, luma));
		float plate = base_area * gold;
		float mask = clamp(max(gold * gold_area, max(dark_base, plate)), 0.0, 1.0);
		float side = 0.78 + 0.22 * abs(c);
		vec3 lit = texel.rgb * side;
		lit += vec3(1.0, 0.52, 0.04) * gold * (1.0 - abs(c)) * 0.23;
		COLOR = vec4(lit, mask * texel.a);
	}
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("yaw", 0.0)
	material.set_shader_parameter("pitch", 0.0)
	return material

func _make_sparkle_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add;

void fragment() {
	vec2 p = UV - vec2(0.5, 0.46);
	p.x *= 1.5;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float ray_zone = pow(max(0.0, 0.5 + 0.5 * cos(angle * 22.0 - TIME * 0.35)), 7.0);
	float a = pow(max(0.0, sin((UV.x * 91.0 + UV.y * 53.0) * 3.141592 + TIME * 5.1)), 42.0);
	float b = pow(max(0.0, sin((UV.x * 37.0 - UV.y * 79.0) * 3.141592 - TIME * 4.2)), 34.0);
	float sparkle = a * b * smoothstep(0.72, 0.08, radius);
	float glow = sparkle * (0.40 + 0.60 * ray_zone);
	vec3 color = mix(vec3(1.0, 0.10, 0.02), vec3(1.0, 0.88, 0.35), sparkle);
	COLOR = vec4(color * glow * 1.8, glow);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _on_trophy_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_dragging = touch.pressed
		if not _dragging:
			_drag_area.accept_event()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_apply_drag(drag.relative)
		_drag_area.accept_event()
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse_button.pressed
			_drag_area.accept_event()
		return
	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_apply_drag(motion.relative)
		_drag_area.accept_event()

func _apply_drag(relative: Vector2) -> void:
	_yaw = fmod(_yaw - relative.x * 0.013, TAU)
	_pitch = clampf(_pitch + relative.y * 0.008, -0.72, 0.72)
	_yaw_velocity = clampf(-relative.x * 0.055, -8.5, 8.5)
	_pitch_velocity = clampf(relative.y * 0.035, -4.0, 4.0)
	_apply_trophy_rotation()

func _apply_trophy_rotation() -> void:
	if _trophy_material == null:
		return
	_trophy_material.set_shader_parameter("yaw", _yaw)
	_trophy_material.set_shader_parameter("pitch", _pitch)

func _on_progression_changed() -> void:
	call_deferred("_check_completion")

func _check_completion() -> void:
	if _end_screen_open:
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not game_state.has_method("is_boss_defeated"):
		return
	if not bool(game_state.call("is_boss_defeated", 11)):
		return
	var already_seen := false
	if game_state.has_method("get_quest_value"):
		already_seen = bool(game_state.call("get_quest_value", ENDGAME_FLAG, false))
	if already_seen:
		return
	_show_end_screen()

func _show_end_screen() -> void:
	_end_screen_open = true
	_dragging = false
	_yaw_velocity = 0.0
	_pitch_velocity = 0.0
	_root.visible = true
	_fit_frame()
	get_tree().paused = true

func _continue_game() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		if game_state.has_method("set_quest_value"):
			game_state.call("set_quest_value", ENDGAME_FLAG, true)
		if game_state.has_method("quick_save"):
			game_state.call("quick_save")
	_close_end_screen()

func _restart_game() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		_close_end_screen()
		get_tree().reload_current_scene()
		return
	var hero := str(game_state.get("selected_hero"))
	var difficulty := str(game_state.get("difficulty"))
	get_tree().paused = false
	_end_screen_open = false
	_root.visible = false
	if game_state.has_method("new_game"):
		game_state.call("new_game", hero, difficulty)
	if game_state.has_method("quick_save"):
		game_state.call("quick_save")
	get_tree().reload_current_scene()

func _close_end_screen() -> void:
	_end_screen_open = false
	_dragging = false
	_root.visible = false
	get_tree().paused = false
