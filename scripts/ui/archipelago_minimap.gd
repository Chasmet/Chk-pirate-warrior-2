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

    var compass := Vector2(size.x - 28.0, 26.0)
    draw_circle(compass, 14.0, Color(0.02, 0.05, 0.07, 0.72))
    draw_arc(compass, 14.0, 0.0, TAU, 24, GOLD, 1.5, true)
    draw_line(compass + Vector2(0, 10), compass + Vector2(0, -10), GOLD_BRIGHT, 1.5)
    draw_line(compass + Vector2(-10, 0), compass + Vector2(10, 0), GOLD_BRIGHT, 1.5)
    draw_string(ThemeDB.fallback_font, compass + Vector2(-5, -17), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD_BRIGHT)

func _draw_island(index: int, center: Vector2) -> void:
    var island_id := index + 1
    var info := WorldCatalog.island(index)
    var radius := 8.0 + float(index % 3) * 1.5
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
        draw_arc(center, radius + 7.0, 0.0, TAU, 32, CURRENT, 3.0, true)
        draw_circle(center, 3.0, Color.WHITE)
    elif defeated:
        draw_arc(center, radius + 4.0, 0.0, TAU, 28, LIBERATED, 2.0, true)
    elif discovered and not locked:
        draw_arc(center, radius + 4.0, 0.0, TAU, 28, GOLD_BRIGHT, 1.8, true)

    var label := _short_name(str(info.get("name", "ÎLE")))
    var label_pos := center + Vector2(-28.0, radius + 15.0)
    draw_string(ThemeDB.fallback_font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, 56.0, 10, Color(0.94, 0.91, 0.79, 0.95))

func _map_point(normalized: Vector2) -> Vector2:
    return Vector2(18.0 + normalized.x * maxf(1.0, size.x - 36.0), 28.0 + normalized.y * maxf(1.0, size.y - 50.0))

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
