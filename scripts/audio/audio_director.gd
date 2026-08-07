extends Node

var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer

func _ready() -> void:
    music_player = AudioStreamPlayer.new()
    music_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
    add_child(music_player)
    ambience_player = AudioStreamPlayer.new()
    ambience_player.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
    add_child(ambience_player)
    GameState.island_changed.connect(play_island_audio)

func play_island_audio(island_id: int = GameState.current_island) -> void:
    var folder := "res://assets/audio/bandes_son/ile_%02d" % island_id
    _play_if_exists(music_player, folder + "/theme_principal.ogg", true)
    _play_if_exists(ambience_player, folder + "/ambiance.ogg", true)

func play_sfx(path: String) -> void:
    if not ResourceLoader.exists(path):
        return
    var player := AudioStreamPlayer.new()
    add_child(player)
    player.stream = load(path)
    player.finished.connect(player.queue_free)
    player.play()

func _play_if_exists(player: AudioStreamPlayer, path: String, looped: bool) -> void:
    if not ResourceLoader.exists(path):
        return
    var stream = load(path)
    if stream == null:
        return
    if "loop" in stream:
        stream.loop = looped
    player.stop()
    player.stream = stream
    player.play()
