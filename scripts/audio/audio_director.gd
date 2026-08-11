class_name AudioDirectorV130
extends Node

const ISLAND_AUDIO_ROOT := "res://assets/audio/bandes_son"
const SEA_AUDIO_FOLDER := "res://assets/audio/bandes_son/mer"
const MENU_AUDIO_PATH := "res://assets/audio/menu_theme.mp3"
const INTERFACE_AUDIO_PATH := "res://assets/audio/interface_theme.mp3"
const DEFAULT_BUS_LAYOUT_PATH := "res://default_bus_layout.tres"
const MUSIC_FADE_SECONDS := 0.85
const MUSIC_BUS_NAME := &"Music"
const VOICE_DUCK_DB := -20.0
const NORMAL_MUSIC_BUS_DB := 0.0
const NORMAL_MUSIC_PLAYER_DB := -1.0
const MUSIC_RECOVERY_DB_PER_SECOND := 14.0

var music_player: AudioStreamPlayer
var transition_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var _current_music_path := ""
var _sea_mode := false
var _gameplay_active := false
var _check_accumulator := 0.0
var _fade_tween: Tween
var _music_bus_index := -1

func _ready() -> void:
    add_to_group("audio_director")
    process_mode = Node.PROCESS_MODE_ALWAYS

    var bus_layout := load(DEFAULT_BUS_LAYOUT_PATH) as AudioBusLayout
    if bus_layout != null:
        # Chargement explicite pour Android et les exécutions headless : les
        # voix ne doivent jamais retomber silencieusement sur Master.
        AudioServer.set_bus_layout(bus_layout)

    _music_bus_index = AudioServer.get_bus_index(MUSIC_BUS_NAME)
    if _music_bus_index >= 0:
        AudioServer.set_bus_volume_db(_music_bus_index, NORMAL_MUSIC_BUS_DB)

    music_player = _new_music_player("MusicPrimary")
    transition_player = _new_music_player("MusicTransition")
    ambience_player = AudioStreamPlayer.new()
    ambience_player.name = "Ambience"
    ambience_player.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
    add_child(ambience_player)

    GameState.island_changed.connect(_on_island_changed)
    play_menu_audio.call_deferred()

func _process(delta: float) -> void:
    # Le ducking doit être évalué à chaque image. L'ancienne version ne le
    # calculait que toutes les 0,18 s avec un delta d'environ 0,016 s : les
    # répliques courtes se terminaient avant que la musique baisse réellement.
    _update_voice_ducking(delta)
    _check_accumulator += delta
    if _check_accumulator >= 0.18:
        _check_accumulator = 0.0
        _update_navigation_music_state()

func _new_music_player(node_name: String) -> AudioStreamPlayer:
    var player := AudioStreamPlayer.new()
    player.name = node_name
    player.bus = MUSIC_BUS_NAME if AudioServer.get_bus_index(MUSIC_BUS_NAME) >= 0 else &"Master"
    player.volume_db = NORMAL_MUSIC_PLAYER_DB
    add_child(player)
    return player

func _on_island_changed(island_id: int) -> void:
    if not _gameplay_active:
        return
    if not _is_player_on_boat():
        _sea_mode = false
        play_island_audio(island_id)

func play_menu_audio() -> void:
    _gameplay_active = false
    _sea_mode = false
    _crossfade_to(MENU_AUDIO_PATH)

func play_interface_audio() -> void:
    _gameplay_active = false
    _sea_mode = false
    _crossfade_to(INTERFACE_AUDIO_PATH)

func start_gameplay_audio() -> void:
    _gameplay_active = true
    _sea_mode = _is_player_on_boat()
    if _sea_mode:
        play_sea_audio()
    else:
        play_island_audio(GameState.current_island)

func play_island_audio(island_id: int = GameState.current_island) -> void:
    var folder := "%s/ile_%02d" % [ISLAND_AUDIO_ROOT, clampi(island_id, 1, 11)]
    var music_path := _find_music_file(folder, [
        "theme_principal", "theme", "musique", "bande_son", "soundtrack", "ile_%02d" % island_id
    ])
    _crossfade_to(music_path)

    var ambience_path := _find_named_audio(folder, ["ambiance", "ambience", "atmosphere"])
    _play_stream(ambience_player, ambience_path, true)

func play_sea_audio() -> void:
    var music_path := _find_music_file(SEA_AUDIO_FOLDER, [
        "traversee_mer", "traversee", "theme_mer", "musique_mer", "mer", "sea"
    ])
    _crossfade_to(music_path)

func play_sfx(path: String) -> void:
    if not ResourceLoader.exists(path):
        return
    var stream := load(path) as AudioStream
    if stream == null:
        return
    var player := AudioStreamPlayer.new()
    player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
    add_child(player)
    player.stream = stream
    player.finished.connect(player.queue_free)
    player.play()

func _update_navigation_music_state() -> void:
    if not _gameplay_active:
        return
    var on_boat := _is_player_on_boat()
    if on_boat == _sea_mode:
        return
    _sea_mode = on_boat
    if _sea_mode:
        play_sea_audio()
    else:
        play_island_audio(GameState.current_island)

func _is_player_on_boat() -> bool:
    var active := get_tree().get_first_node_in_group("active_controller")
    return active is BoatController and is_instance_valid(active) and (active as BoatController).is_boarded()

func _crossfade_to(path: String) -> void:
    if path.is_empty() or path == _current_music_path:
        return
    if not ResourceLoader.exists(path):
        return
    var stream := load(path) as AudioStream
    if stream == null:
        return
    _set_loop(stream, true)

    if not music_player.playing or music_player.stream == null:
        music_player.stream = stream
        music_player.volume_db = NORMAL_MUSIC_PLAYER_DB
        music_player.play()
        _current_music_path = path
        return

    if _fade_tween != null and _fade_tween.is_valid():
        _fade_tween.kill()

    transition_player.stop()
    transition_player.stream = stream
    transition_player.volume_db = -32.0
    transition_player.play()

    _fade_tween = create_tween()
    _fade_tween.set_parallel(true)
    _fade_tween.tween_property(music_player, "volume_db", -32.0, MUSIC_FADE_SECONDS)
    _fade_tween.tween_property(transition_player, "volume_db", NORMAL_MUSIC_PLAYER_DB, MUSIC_FADE_SECONDS)
    _fade_tween.set_parallel(false)
    _fade_tween.tween_callback(_finish_crossfade.bind(path))

func _finish_crossfade(path: String) -> void:
    var old := music_player
    music_player = transition_player
    transition_player = old
    transition_player.stop()
    transition_player.stream = null
    transition_player.volume_db = NORMAL_MUSIC_PLAYER_DB
    _current_music_path = path

func _update_voice_ducking(delta: float) -> void:
    if _music_bus_index < 0:
        _music_bus_index = AudioServer.get_bus_index(MUSIC_BUS_NAME)
    if _music_bus_index < 0:
        return
    var voice_director := get_tree().get_first_node_in_group("hero_voice_director")
    var voice_playing := false
    if voice_director != null:
        var voice_player := voice_director.get_node_or_null("PlayableHeroVoice") as AudioStreamPlayer
        voice_playing = voice_player != null and voice_player.playing
    var current_volume := AudioServer.get_bus_volume_db(_music_bus_index)
    if voice_playing:
        # Baisse immédiate de tout le bus Music : les deux lecteurs du fondu
        # sont atténués ensemble et aucune syllabe n'est masquée.
        AudioServer.set_bus_volume_db(_music_bus_index, VOICE_DUCK_DB)
    else:
        AudioServer.set_bus_volume_db(
            _music_bus_index,
            move_toward(current_volume, NORMAL_MUSIC_BUS_DB, MUSIC_RECOVERY_DB_PER_SECOND * delta)
        )

func _find_music_file(folder: String, preferred_stems: Array[String]) -> String:
    var preferred := _find_named_audio(folder, preferred_stems)
    if not preferred.is_empty():
        return preferred
    return _first_audio_file(folder, ["ambiance", "ambience", "atmosphere"])

func _find_named_audio(folder: String, stems: Array[String]) -> String:
    for stem in stems:
        for extension in ["mp3", "ogg", "wav"]:
            var path := "%s/%s.%s" % [folder, stem, extension]
            if ResourceLoader.exists(path):
                return path
    return ""

func _first_audio_file(folder: String, excluded_terms: Array[String] = []) -> String:
    var dir := DirAccess.open(folder)
    if dir == null:
        return ""
    var files := Array(dir.get_files())
    files.sort()
    for filename_value in files:
        var filename := str(filename_value)
        var lower := filename.to_lower()
        if not (lower.ends_with(".mp3") or lower.ends_with(".ogg") or lower.ends_with(".wav")):
            continue
        var excluded := false
        for term in excluded_terms:
            if lower.contains(term.to_lower()):
                excluded = true
                break
        if excluded:
            continue
        var path := folder + "/" + filename
        if ResourceLoader.exists(path):
            return path
    return ""

func _play_stream(player: AudioStreamPlayer, path: String, looped: bool) -> void:
    if player == null:
        return
    if path.is_empty() or not ResourceLoader.exists(path):
        player.stop()
        player.stream = null
        return
    var stream := load(path) as AudioStream
    if stream == null:
        return
    _set_loop(stream, looped)
    player.stop()
    player.stream = stream
    player.play()

func _set_loop(stream: AudioStream, looped: bool) -> void:
    if stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = looped
    elif stream is AudioStreamMP3:
        (stream as AudioStreamMP3).loop = looped
    elif stream is AudioStreamWAV:
        (stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
