class_name HeroVoiceDirector
extends Node

# Direction vocale des personnages jouables.
# Une voix n'est jamais empruntée à un autre héros : si un événement n'a pas
# encore été enregistré pour le personnage sélectionné, le jeu reste silencieux.
const VOICE_ROOT := "res://assets/audio/personnages_principaux"
const MAX_VARIANTS := 6

const PRIORITIES := {
    "attaque": 10,
    "bonjour": 20,
    "ennemi_repere": 60,
    "embarquement": 65,
    "coffre_trouve": 70,
    "arrivee_ile_01": 75,
    "victoire": 80,
    "douleur": 90
}

const COOLDOWNS_MS := {
    "attaque": 2600,
    "bonjour": 5000,
    "ennemi_repere": 14000,
    "embarquement": 3500,
    "coffre_trouve": 3000,
    "arrivee_ile_01": 30000,
    "victoire": 4500,
    "douleur": 1350
}

var _player: AudioStreamPlayer
var _current_priority := -1
var _current_event := ""
var _last_played_ms: Dictionary = {}
var _variant_cursor: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _hero_serial := 0
var _pending_event := ""
var _pending_priority := -1
var _monitor_accumulator := 0.0
var _enemy_contact_active := false
var _last_arrival_island := -1

func _ready() -> void:
    add_to_group("hero_voice_director")
    _rng.seed = Time.get_ticks_usec() ^ 0x43A17

    _player = AudioStreamPlayer.new()
    _player.name = "PlayableHeroVoice"
    _player.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "Master"
    _player.volume_db = -1.5
    _player.finished.connect(_on_voice_finished)
    add_child(_player)

    GameState.hero_changed.connect(_on_hero_changed)
    GameState.island_changed.connect(_on_island_changed)
    _schedule_initial_context()

func _process(delta: float) -> void:
    _monitor_accumulator += delta
    if _monitor_accumulator < 0.12:
        return
    _monitor_accumulator = 0.0
    _monitor_enemy_contact()

func play_event(event_name: String, force: bool = false) -> bool:
    var event := event_name.strip_edges().to_lower()
    if event.is_empty():
        return false

    if event == "attaque" and not force:
        var hero_id := _hero_id()
        var chance := 0.34 if hero_id == "cheikh" else 0.22
        if _rng.randf() > chance:
            return false

    var now := Time.get_ticks_msec()
    var cooldown := _event_cooldown(event)
    if not force and now - int(_last_played_ms.get(event, -cooldown - 1)) < cooldown:
        return false

    var clips := _clips_for_event(_hero_id(), event)
    if clips.is_empty():
        return false

    var priority := _event_priority(event)
    if _player.playing:
        if priority <= _current_priority:
            if priority >= 60 and priority > _pending_priority:
                _pending_event = event
                _pending_priority = priority
            return false
        _player.stop()

    var clip_path := _choose_variant(event, clips)
    var stream: Resource = load(clip_path)
    if not (stream is AudioStream):
        return false

    _current_priority = priority
    _current_event = event
    _last_played_ms[event] = now
    _player.stream = stream as AudioStream
    _player.play()
    return true

func _event_priority(event: String) -> int:
    if event.begins_with("arrivee_ile_"):
        return 75
    return int(PRIORITIES.get(event, 30))

func _event_cooldown(event: String) -> int:
    if event.begins_with("arrivee_ile_"):
        return 30000
    return int(COOLDOWNS_MS.get(event, 1800))

func _clips_for_event(hero_id: String, event: String) -> Array[String]:
    var result: Array[String] = []
    var folder := "%s/%s" % [VOICE_ROOT, hero_id]

    for index in range(1, MAX_VARIANTS + 1):
        var path := "%s/%s_%02d.mp3" % [folder, event, index]
        if ResourceLoader.exists(path):
            result.append(path)

    if result.is_empty():
        for extension in ["mp3", "ogg", "wav"]:
            var single := "%s/%s.%s" % [folder, event, extension]
            if ResourceLoader.exists(single):
                result.append(single)
    return result

func _choose_variant(event: String, clips: Array[String]) -> String:
    if clips.size() == 1:
        return clips[0]
    var key := "%s:%s" % [_hero_id(), event]
    var previous := int(_variant_cursor.get(key, -1))
    var next := _rng.randi_range(0, clips.size() - 1)
    if next == previous:
        next = (next + 1 + _rng.randi_range(0, clips.size() - 2)) % clips.size()
    _variant_cursor[key] = next
    return clips[next]

func _hero_id() -> String:
    var hero_id := str(GameState.selected_hero).to_lower()
    return hero_id if hero_id in ["cheikh", "yvane", "nelvyn"] else "cheikh"

func _monitor_enemy_contact() -> void:
    var playable := get_tree().get_first_node_in_group("player") as Node3D
    if playable == null or not is_instance_valid(playable):
        _enemy_contact_active = false
        return

    var enemy_near := false
    for node in get_tree().get_nodes_in_group("enemy"):
        if not is_instance_valid(node) or not (node is Node3D):
            continue
        var enemy := node as Node3D
        var health_value := float(enemy.get("health"))
        if health_value <= 0.0:
            continue
        var detection := float(enemy.get("detection_radius"))
        if detection <= 0.0:
            detection = 28.0
        if playable.global_position.distance_to(enemy.global_position) <= detection:
            enemy_near = true
            break

    if enemy_near and not _enemy_contact_active:
        play_event("ennemi_repere")
    _enemy_contact_active = enemy_near

func _on_voice_finished() -> void:
    _current_priority = -1
    _current_event = ""
    if not _pending_event.is_empty():
        _play_pending.call_deferred()

func _play_pending() -> void:
    var event := _pending_event
    _pending_event = ""
    _pending_priority = -1
    await get_tree().create_timer(0.08).timeout
    play_event(event, true)

func _on_hero_changed(_hero_id_value: String) -> void:
    _hero_serial += 1
    var serial := _hero_serial
    _player.stop()
    _current_priority = -1
    _current_event = ""
    _pending_event = ""
    _pending_priority = -1
    _play_hero_greeting.call_deferred(serial)

func _play_hero_greeting(serial: int) -> void:
    await get_tree().create_timer(0.45).timeout
    if serial != _hero_serial:
        return
    play_event("bonjour", true)

func _on_island_changed(island_id: int) -> void:
    _enemy_contact_active = false
    if island_id == _last_arrival_island:
        return
    _last_arrival_island = island_id
    _play_island_arrival.call_deferred(island_id)

func _play_island_arrival(island_id: int) -> void:
    await get_tree().create_timer(0.75).timeout
    if island_id != GameState.current_island:
        return
    play_event("arrivee_ile_%02d" % clampi(island_id, 1, 11), true)

func _schedule_initial_context() -> void:
    _play_initial_context.call_deferred()

func _play_initial_context() -> void:
    await get_tree().create_timer(0.90).timeout
    var island_id := clampi(GameState.current_island, 1, 11)
    _last_arrival_island = island_id
    if not play_event("arrivee_ile_%02d" % island_id, true):
        play_event("bonjour", true)
