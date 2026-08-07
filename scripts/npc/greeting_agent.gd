extends Area3D

@export_range(1, 11) var island_id: int = 1
@export var play_once := true
@export var subtitle_seconds := 3.5

var _already_played := false
var _audio := AudioStreamPlayer3D.new()

func _ready() -> void:
    add_child(_audio)
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if _already_played and play_once:
        return
    if not body.is_in_group("player"):
        return
    greet_current_hero()

func greet_current_hero() -> void:
    var hero_id := GameState.selected_hero
    var hero_data := GameState.get_hero_data(hero_id)
    var hero_name := str(hero_data.get("display_name", hero_id.capitalize()))
    var text := "Bonjour %s, bienvenue sur l'île %d." % [hero_name, island_id]
    var path := "res://assets/audio/pnj_accueil/ile_%02d/bonjour_%s.ogg" % [island_id, hero_id]
    if ResourceLoader.exists(path):
        _audio.stream = load(path)
        _audio.play()
    _show_subtitle(text)
    _already_played = true

func _show_subtitle(text: String) -> void:
    var hud = get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_subtitle"):
        hud.show_subtitle(text, subtitle_seconds)
    else:
        print(text)
