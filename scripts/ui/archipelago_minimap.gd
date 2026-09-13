class_name ArchipelagoMinimap
extends Control

const GOLD := Color("d8b45d")
const GOLD_BRIGHT := Color("ffe49b")
const SEA := Color(0.015, 0.075, 0.11, 0.96)
const ROUTE := Color(0.78, 0.65, 0.35, 0.70)
const LOCKED := Color(0.28, 0.31, 0.34, 1.0)
const CURRENT := Color("61d7ff")
const LIBERATED := Color("78d98e")

var _points := [
    Vector2(0.12, 0.64),
    Vector2(0.22, 0.30),
    Vector2(0.36, 0.48),
    Vector2(0.50, 0.24),
    Vector2(0.63, 0.46),
    Vector2(0.79, 0.28),
    Vector2(0.88, 0.57),
    Vector2(0.72, 0.74),
    Vector2(0.53, 0.67),
    Vector2(0.34, 0.78),
    Vector2(0.16, 0.86)
]

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if not GameState.island_changed.is_connected(_on_state_changed):
        GameState.island_changed.connect(_on_state_changed)
    if not GameState.progression_changed.is_connected(_on_progression_changed):
        GameState.progression_changed.connect(_on_progression_changed)
    queue_redraw()

func _on_state_changed(_island_id: int) -> void:
    queue_redraw()

func _on_progression_changed() -> void:
    queue_redraw()

func _draw() -> void:
    if size.x < 40.0 or size.y < 40.0:
        return

    var inner := Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0))
    draw_rect(inner, SEA, true)

    # Routes maritimes : l'itinéraire principal relie réellement les 11 royaumes.
    for i in range(_points.size() - 1):
        var a := _map_point(_points[i])
        var b := _map_point(_points[i + 1])
        _draw_dotted_line(a, b, ROUTE, 2.0, 8.0)

    # Quelques liaisons visuelles supplémentaires rendent l'archipel lisible
    # comme une vraie carte sans changer la progression canonique.
    for link in [[1, 3], [2, 8], [4, 6], [7, 9]]:
        _draw_dotted_line(_map_point(_points[link[0]]), _map_point(_points[link[1]]), Color(0.52, 0.50, 0.37, 0.42), 1.4, 9.0)

    for i in range(WorldCatalog.island_count()):
        _draw_island(i, _map_point(_points[i]))

    var compact := _is_compact()
    var compass := Vector2(size.x - 20.0, 20.0) if compact else Vector2(size.x - 28.0, 26.0)
    var compass_radius := 8.0 if compact else 14.0
    var arm := compass_radius - 3.0
    draw_circle(compass, compass_radius, Color(0.02, 0.05, 0.07, 0.72))
    draw_arc(compass, compass_radius, 0.0, TAU, 24, GOLD, 1.5, true)
    draw_line(compass + Vector2(0, arm), compass + Vector2(0, -arm), GOLD_BRIGHT, 1.5)
    draw_line(compass + Vector2(-arm, 0), compass + Vector2(arm, 0), GOLD_BRIGHT, 1.5)
    draw_string(ThemeDB.fallback_font, compass + Vector2(-4, -compass_radius - 3), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 9 if compact else 11, GOLD_BRIGHT)
    if compact:
        var current_name := _short_name(str(WorldCatalog.island(GameState.current_island - 1).get("name", "ÎLE")))
        var caption := "%d · %s" % [GameState.current_island, current_name]
        var text_width := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
        draw_string(ThemeDB.fallback_font, Vector2((size.x - text_width) * 0.5, size.y - 6), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CURRENT)

func _draw_island(index: int, center: Vector2) -> void:
    var island_id := index + 1
    var info := WorldCatalog.island(index)
    var compact := _is_compact()
    var radius := 4.5 + float(index % 3) * 0.6 if compact else 8.0 + float(index % 3) * 1.5
    var discovered := GameState.discovered_islands.has(island_id)
    var defeated := GameState.is_boss_defeated(island_id)
    var locked := island_id == 11 and not GameState.can_enter_island(11)
    var current := island_id == GameState.current_island

    var color: Color = LOCKED if locked else (info.get("color", Color("6d805e")) if discovered else Color(0.34, 0.38, 0.39, 1.0))
    if defeated:
        color = LIBERATED.darkened(0.35)

    var poly := PackedVector2Array()
    var steps := 9
    for p in range(steps):
        var angle := TAU * float(p) / float(steps)
        var wobble := 0.78 + 0.22 * sin(float(p * 7 + island_id * 3))
        poly.append(center + Vector2(cos(angle), sin(angle)) * radius * wobble)
    draw_colored_polygon(poly, color)
    draw_polyline(poly + PackedVector2Array([poly[0]]), GOLD if discovered else Color(0.48, 0.51, 0.52, 0.8), 1.4, true)

    if current:
        draw_arc(center, radius + (3.0 if compact else 7.0), 0.0, TAU, 32, CURRENT, 1.8 if compact else 3.0, true)
        draw_circle(center, 1.8 if compact else 3.0, Color.WHITE)
    elif defeated and not compact:
        draw_arc(center, radius + 4.0, 0.0, TAU, 28, LIBERATED, 2.0, true)
    elif discovered and not locked and not compact:
        draw_arc(center, radius + 4.0, 0.0, TAU, 28, GOLD_BRIGHT, 1.8, true)

    # La miniature indique le royaume courant sous la carte ; les noms de tous
    # les royaumes restent sur la grande carte accessible par CARTE.
    if compact:
        return
    var label := _short_name(str(info.get("name", "ÎLE")))
    var label_pos := center + Vector2(-28.0, radius + 15.0)
    draw_string(ThemeDB.fallback_font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, 56.0, 10, Color(0.94, 0.91, 0.79, 0.95))

func _map_point(normalized: Vector2) -> Vector2:
    if _is_compact():
        return Vector2(12.0 + normalized.x * maxf(1.0, size.x - 38.0), 10.0 + normalized.y * maxf(1.0, size.y - 39.0))
    return Vector2(18.0 + normalized.x * maxf(1.0, size.x - 36.0), 28.0 + normalized.y * maxf(1.0, size.y - 50.0))

func _is_compact() -> bool:
    return size.x < 300.0 or size.y < 160.0

func _draw_dotted_line(a: Vector2, b: Vector2, color: Color, width: float, spacing: float) -> void:
    var delta := b - a
    var length := delta.length()
    if length <= 0.01:
        return
    var dir := delta / length
    var cursor := 0.0
    while cursor < length:
        var end_cursor := minf(cursor + spacing * 0.55, length)
        draw_line(a + dir * cursor, a + dir * end_cursor, color, width, true)
        cursor += spacing

func _short_name(value: String) -> String:
    var cleaned := value.to_upper()
    cleaned = cleaned.replace("ROYAUME DE LA ", "")
    cleaned = cleaned.replace("ROYAUME DE ", "")
    cleaned = cleaned.replace("ROYAUME DES ", "")
    cleaned = cleaned.replace("ROYAUME ", "")
    cleaned = cleaned.replace("ÎLE DES ", "")
    if cleaned.length() > 9:
        cleaned = cleaned.left(9)
    return cleaned
