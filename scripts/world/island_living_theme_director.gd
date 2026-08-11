class_name IslandLivingThemeDirector
extends Node3D

# Couche additive : elle ne remplace aucun décor existant. Elle renforce le thème
# de chaque royaume autour de l'arrivée et ajoute une petite vie quotidienne.
@export var themed_resident_budget := 8
@export var open_home_count := 3

const THEME_ROLES := {
    1: ["Violoniste", "Luthier", "Percussionniste", "Chanteuse", "Facteur de flûtes", "Chef d'orchestre", "Pianiste", "Accordeur"],
    2: ["Confiseur", "Pâtissière", "Maître chocolatier", "Vendeuse de dragées", "Sculpteur de sucre", "Livreur de bonbons", "Glacière", "Apprenti confiseur"],
    3: ["Maraîcher", "Boulangère", "Cuisinier", "Poissonnier", "Épicier", "Serveuse", "Fromagère", "Chef du marché"],
    4: ["Mage des cristaux", "Alchimiste", "Enchanteuse", "Bibliothécaire runique", "Gardien des portails", "Herboriste", "Astrologue", "Forgeron mystique"],
    5: ["Mécanicien héroïque", "Secouriste", "Journaliste", "Ingénieure", "Gardien urbain", "Livreuse", "Technicien", "Habitante du quartier"],
    6: ["Dresseuse", "Soigneur", "Éleveuse", "Arbitre d'arène", "Explorateur", "Chercheuse", "Vendeur de baies", "Apprenti dresseur"],
    7: ["Canonnier", "Charpentière", "Quartier-maître", "Tavernier", "Navigatrice", "Gabier", "Cartographe", "Matelot"],
    8: ["Guide des neiges", "Sculptrice de glace", "Chasseur", "Tisserande", "Gardien du refuge", "Pêcheuse polaire", "Messager", "Herboriste du givre"],
    9: ["Forgeron des braises", "Mineuse", "Gardien du four", "Artisane du verre", "Porteur d'eau", "Éclaireur volcanique", "Cuisinier des flammes", "Habitante des braises"],
    10: ["Tailleur de pierre", "Jardinière", "Architecte", "Potier", "Bûcheron", "Sculptrice", "Gardien des sources", "Bâtisseuse"]
}

const THEME_DIALOGUES := {
    1: ["Le concert du soir commence sur la grande place.", "Les ponts-pianos répondent mieux quand on marche en rythme.", "Le Conservatoire domine le Mont de la Résonance.", "Écoute les oiseaux : ils reprennent parfois la mélodie du village."],
    2: ["La pluie sucrée colle aux bottes, mais les enfants adorent ça.", "Le marché prépare une nouvelle recette de caramel.", "Les confiseurs décorent la place avant le festival."],
    3: ["Le grand marché ouvre avant le lever du soleil.", "Les cuisiniers échangent leurs recettes toute la journée.", "On apporte les récoltes fraîches depuis les collines."],
    4: ["Les cristaux brillent plus fort quand la brume descend.", "Les mages se réunissent près du portail au crépuscule.", "Certaines runes ne se lisent que sous la lumière bleue."],
    5: ["Les équipes de secours patrouillent sans arrêt dans le quartier.", "Les ateliers réparent les véhicules jusque tard le soir.", "La grande tour sert de point de rassemblement."],
    6: ["L'arène est ouverte pour les entraînements libres.", "Les soigneurs préparent les créatures avant les combats.", "Les dresseurs se retrouvent près des orbes d'entraînement."],
    7: ["Les charpentiers renforcent les coques avant la prochaine tempête.", "À la taverne, tout le monde connaît une histoire de trésor.", "Les gabiers répètent les manœuvres au port."],
    8: ["Les refuges restent ouverts quand le blizzard arrive.", "La glace chante parfois sous les pas.", "Les habitants se regroupent autour des braseros le soir."],
    9: ["Les forges ne s'arrêtent jamais dans la citadelle.", "On évite les fissures rouges : certaines s'ouvrent sans prévenir.", "Les artisans travaillent le verre volcanique."],
    10: ["Chaque famille entretient une partie des terrasses cultivées.", "Les bâtisseurs réparent les murs après chaque saison des pluies.", "Les anciens racontent l'histoire des grands totems."]
}

const THEME_COLORS := [
    [Color("d7b85a"), Color("3c6f65"), Color("f0d675")],
    [Color("ff9bc1"), Color("8edcff"), Color("fff0a2")],
    [Color("d58a49"), Color("6ea65b"), Color("f2c95c")],
    [Color("78d9ff"), Color("9b75e7"), Color("78ffd5")],
    [Color("e65650"), Color("52687c"), Color("66b8ff")],
    [Color("f1dc4c"), Color("5ea86f"), Color("df5a55")],
    [Color("d5a64b"), Color("6f472d"), Color("31343a")],
    [Color("c8efff"), Color("7ca9c2"), Color("f2fbff")],
    [Color("ff6338"), Color("4a3430"), Color("ffb04f")],
    [Color("9fbd68"), Color("6e6044"), Color("c7b77a")],
    [Color("b88ae8"), Color("332b38"), Color("d7ba72")]
]

var _root: Node3D
var _residents: Array[Node3D] = []
var _current_island := -1
var _serial := 0
var _time := 0.0
var _player: Node3D
var _island_info: Dictionary = {}

func _ready() -> void:
    add_to_group("themed_life")
    _player = get_tree().get_first_node_in_group("player") as Node3D
    GameState.island_changed.connect(_on_island_changed)
    _on_island_changed(GameState.current_island)

func _process(delta: float) -> void:
    _time += delta
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as Node3D
    _animate_residents(delta)
    # Permet aussi l'interaction clavier/manette. Sur mobile, le bouton INTERAGIR
    # appelle directement request_interaction() avant l'embarquement.
    if Input.is_action_just_pressed("interact"):
        request_interaction()

func _on_island_changed(island_id: int) -> void:
    _current_island = clampi(island_id, 1, WorldCatalog.island_count())
    _serial += 1
    _rebuild.call_deferred(_current_island, _serial)

func _rebuild(island_id: int, serial: int) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if serial != _serial:
        return
    if _root != null and is_instance_valid(_root):
        _root.queue_free()
    _residents.clear()

    _island_info = WorldCatalog.island(island_id - 1)
    var center := WorldCatalog.world_positions()[island_id - 1]
    _root = Node3D.new()
    _root.name = "VieThematique_%02d" % island_id
    add_child(_root)
    _root.global_position = center

    _build_arrival_identity(island_id, _island_info)
    if island_id != 11:
        _build_open_homes(island_id, _island_info)
        _spawn_themed_residents(island_id, _island_info)

func request_interaction() -> bool:
    if _player == null or not is_instance_valid(_player):
        return false
    var nearest: Node3D
    var best := 4.8
    for resident in _residents:
        if not is_instance_valid(resident):
            continue
        var distance := _player.global_position.distance_to(resident.global_position)
        if distance < best:
            best = distance
            nearest = resident
    if nearest == null:
        return false
    var role := str(nearest.get_meta("role", "Habitant"))
    var lines: Array = THEME_DIALOGUES.get(_current_island, ["Bienvenue dans notre royaume."])
    var index := int(nearest.get_meta("resident_index", 0))
    var line := str(lines[(index + int(_time / 7.0)) % lines.size()])
    _notify("%s • %s" % [role.to_upper(), line])
    var bubble := nearest.get_node_or_null("Conversation") as Label3D
    if bubble != null:
        bubble.text = "!"
        bubble.visible = true
    return true

func _build_arrival_identity(island_id: int, info: Dictionary) -> void:
    var size: Vector2 = info["size"]
    var arrival_z := size.y * 0.305
    var colors: Array = THEME_COLORS[island_id - 1]

    var title_anchor := Node3D.new()
    title_anchor.name = "IdentiteRoyaume"
    title_anchor.position = _ground_local(Vector3(0.0, 0.0, arrival_z - 12.0))
    _root.add_child(title_anchor)
    var title := Label3D.new()
    title.text = _theme_title(island_id)
    title.position = Vector3(0.0, 7.0, 0.0)
    title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    title.no_depth_test = true
    title.font_size = 42
    title.outline_size = 10
    title.modulate = colors[0]
    title.outline_modulate = Color(0, 0, 0, 0.9)
    title_anchor.add_child(title)

    if island_id == 1:
        _build_music_arrival(size, arrival_z, colors)
        return

    # Pour tous les autres royaumes, six stations très visibles encadrent la route
    # du port vers le village. Elles utilisent uniquement des primitives légères.
    for i in range(6):
        var side := -1.0 if i % 2 == 0 else 1.0
        var row := i / 2
        var local := Vector3(side * (30.0 + float(row) * 13.0), 0.0, arrival_z - 28.0 - float(row) * 24.0)
        local = _ground_local(local)
        var station := Node3D.new()
        station.name = "StationTheme_%02d" % i
        station.position = local
        station.rotation.y = side * 0.18
        _root.add_child(station)
        _build_theme_station(station, island_id, i, colors)

func _build_music_arrival(size: Vector2, arrival_z: float, colors: Array) -> void:
    # Le joueur doit comprendre en quelques secondes qu'il est à Accordia.
    # Une avenue de touches de piano part du port vers la ville.
    for row in range(9):
        var z := arrival_z - 22.0 - float(row) * 7.0
        var y := _ground_local(Vector3(0.0, 0.0, z)).y + 0.10
        for key in range(6):
            var x := -9.0 + float(key) * 3.6
            _box(_root, "PianoBlanc_%02d_%02d" % [row, key], Vector3(x, y, z), Vector3(3.25, 0.18, 6.2), Color("f4eee0"))
        for black_key in range(5):
            var bx := -7.2 + float(black_key) * 3.6
            _box(_root, "PianoNoir_%02d_%02d" % [row, black_key], Vector3(bx, y + 0.18, z - 1.2), Vector3(1.55, 0.32, 3.5), Color("27272b"))

    # Deux arches-harpes marquent l'entrée du royaume depuis le quai.
    for side_variant in [-1.0, 1.0]:
        var side: float = float(side_variant)
        var harp := Node3D.new()
        harp.name = "ArcheHarpe_%s" % ("G" if side < 0.0 else "D")
        harp.position = _ground_local(Vector3(side * 32.0, 0.0, arrival_z - 8.0))
        _root.add_child(harp)
        _cylinder(harp, "Montant", Vector3(0.0, 5.0, 0.0), 0.48, 10.0, colors[0])
        _cylinder(harp, "ColonneCourbe", Vector3(side * 3.4, 4.4, 0.0), 0.36, 8.8, colors[0])
        _box(harp, "Traverse", Vector3(side * 1.7, 8.8, 0.0), Vector3(4.6, 0.45, 0.45), colors[0])
        for string_index in range(7):
            var sx: float = side * (0.55 + float(string_index) * 0.42)
            var sh: float = 6.4 - float(string_index) * 0.45
            _cylinder(harp, "Corde_%02d" % string_index, Vector3(sx, 4.4, 0.0), 0.045, sh, colors[2], 0.75)

    # Place publique : scène, batterie, orgue et grands symboles musicaux.
    var stage_z := arrival_z - 98.0
    var stage_y := _ground_local(Vector3(0.0, 0.0, stage_z)).y
    _box(_root, "SceneAccordia", Vector3(0.0, stage_y + 0.55, stage_z), Vector3(24.0, 1.1, 12.0), Color("6c4933"))
    for drum in range(3):
        _cylinder(_root, "Tambour_%02d" % drum, Vector3(-3.0 + drum * 3.0, stage_y + 1.7, stage_z), 1.05, 2.1, [Color("b64e45"), Color("d8aa45"), Color("477ca2")][drum])
    for pipe in range(7):
        var h := 4.0 + float(3 - abs(pipe - 3)) * 1.2
        _cylinder(_root, "OrgueScene_%02d" % pipe, Vector3(-6.0 + pipe * 2.0, stage_y + 1.1 + h * 0.5, stage_z + 4.0), 0.34, h, colors[0], 0.45)
    for note_index in range(6):
        var side := -1.0 if note_index % 2 == 0 else 1.0
        var nz := arrival_z - 42.0 - float(note_index / 2) * 24.0
        var ground := _ground_local(Vector3(side * 24.0, 0.0, nz)).y
        _sphere(_root, "NoteTete_%02d" % note_index, Vector3(side * 24.0, ground + 2.1, nz), 0.72, colors[2], 0.65)
        _cylinder(_root, "NoteHampe_%02d" % note_index, Vector3(side * (23.3 if side > 0 else 24.7), ground + 4.0, nz), 0.12, 4.3, colors[2], 0.45)

func _build_theme_station(parent: Node3D, island_id: int, index: int, colors: Array) -> void:
    match island_id:
        2:
            _cylinder(parent, "SucetteTige", Vector3(0, 2.6, 0), 0.18, 5.2, Color("f6eee2"))
            _sphere(parent, "Sucette", Vector3(0, 5.8, 0), 1.55, colors[index % 3], 0.25)
            _sphere(parent, "Bonbon", Vector3(2.0, 0.55, 0.8), 0.65, colors[(index + 1) % 3])
        3:
            _box(parent, "Etal", Vector3(0, 1.0, 0), Vector3(5.5, 2.0, 3.2), colors[1])
            _box(parent, "Auvent", Vector3(0, 2.7, 0), Vector3(6.2, 0.35, 3.8), colors[2])
            for fruit in range(4):
                _sphere(parent, "Produit_%02d" % fruit, Vector3(-1.5 + fruit, 2.0, -0.7), 0.38, [Color("e76044"), Color("79a94d"), Color("e5c04b"), Color("a05a93")][fruit])
        4:
            for crystal in range(4):
                var h := 3.0 + float(crystal % 3) * 1.3
                _crystal(parent, "Cristal_%02d" % crystal, Vector3(-1.8 + crystal * 1.2, h * 0.5, 0), 0.5, h, colors[crystal % 3], 0.75)
        5:
            _box(parent, "BorneHeroique", Vector3(0, 2.5, 0), Vector3(2.8, 5.0, 2.8), colors[1])
            _sphere(parent, "SignalHeroique", Vector3(0, 5.6, 0), 0.7, colors[index % 3], 0.8)
            _box(parent, "Panneau", Vector3(2.5, 3.2, 0), Vector3(2.2, 1.3, 0.25), colors[0])
        6:
            _cylinder(parent, "PoteauDresseur", Vector3(0, 2.3, 0), 0.28, 4.6, Color("735337"))
            _sphere(parent, "OrbeDresseur", Vector3(0, 5.2, 0), 1.0, colors[index % 3], 0.35)
            _torus(parent, "CercleEntrainement", Vector3(0, 0.14, 0), 3.1, 0.25, colors[2])
        7:
            _cylinder(parent, "Mat", Vector3(0, 3.7, 0), 0.28, 7.4, Color("624028"))
            _box(parent, "Drapeau", Vector3(2.0, 5.8, 0), Vector3(3.7, 2.0, 0.18), colors[2])
            _cylinder(parent, "Tonneau", Vector3(-1.8, 0.9, 0.6), 0.72, 1.8, Color("764c2f"))
        8:
            for ice in range(4):
                var ih := 2.8 + float(ice % 2) * 1.5
                _crystal(parent, "Glace_%02d" % ice, Vector3(-1.7 + ice * 1.1, ih * 0.5, 0), 0.55, ih, colors[ice % 3], 0.25)
            _sphere(parent, "Congere", Vector3(1.8, 0.45, 1.0), 0.85, Color("f3fbff"))
        9:
            _crystal(parent, "Basalte", Vector3(-0.8, 2.0, 0), 0.8, 4.0, colors[1])
            _crystal(parent, "Basalte2", Vector3(1.0, 1.5, 0.6), 0.6, 3.0, colors[1].lightened(0.1))
            _torus(parent, "Lave", Vector3(0, 0.18, 0), 2.5, 0.28, colors[0], 1.1)
        10:
            _box(parent, "Totem", Vector3(0, 2.5, 0), Vector3(1.4, 5.0, 1.4), colors[1])
            _torus(parent, "CercleTerre", Vector3(0, 0.16, 0), 2.8, 0.30, colors[2])
            _sphere(parent, "PierreSacree", Vector3(2.2, 0.7, 0.7), 0.8, colors[0])
        11:
            _crystal(parent, "Obelisque", Vector3(0, 3.2, 0), 0.9, 6.4, colors[1], 0.1)
            _torus(parent, "Anneau", Vector3(0, 4.2, 0), 2.0, 0.22, colors[0], 0.65)

func _build_open_homes(island_id: int, info: Dictionary) -> void:
    var size: Vector2 = info["size"]
    var colors: Array = THEME_COLORS[island_id - 1]
    var count := clampi(open_home_count, 1, 5)
    for i in range(count):
        var side := -1.0 if i % 2 == 0 else 1.0
        var row := i / 2
        var local := Vector3(side * (112.0 + float(row) * 24.0), 0.0, size.y * 0.12 - float(row) * 48.0)
        local = _ground_local(local)
        var home := StaticBody3D.new()
        home.name = "MaisonVivante_%02d_%02d" % [island_id, i + 1]
        home.position = local
        home.rotation.y = side * 0.12
        _root.add_child(home)

        var width := 10.0
        var depth := 9.0
        var height := 5.8
        # Façade volontairement ouverte : le joueur voit et peut traverser l'intérieur.
        _home_box(home, "Sol", Vector3(0, 0.18, 0), Vector3(width, 0.36, depth), colors[1].darkened(0.16), true)
        _home_box(home, "MurFond", Vector3(0, height * 0.5, -depth * 0.5), Vector3(width, height, 0.35), colors[0], true)
        _home_box(home, "MurGauche", Vector3(-width * 0.5, height * 0.5, 0), Vector3(0.35, height, depth), colors[0], true)
        _home_box(home, "MurDroit", Vector3(width * 0.5, height * 0.5, 0), Vector3(0.35, height, depth), colors[0], true)
        _home_box(home, "Toit", Vector3(0, height + 0.25, 0), Vector3(width + 0.8, 0.5, depth + 0.8), colors[1], true)
        _home_box(home, "Table", Vector3(0.8, 1.0, -0.8), Vector3(3.2, 0.28, 2.0), Color("765037"), false)
        _home_box(home, "Lit", Vector3(-2.8, 0.65, -2.2), Vector3(2.2, 0.65, 3.2), colors[2].darkened(0.12), false)
        _home_box(home, "Etagere", Vector3(3.7, 2.1, -3.8), Vector3(1.0, 3.5, 0.7), colors[1].lightened(0.08), false)
        _sphere(home, "Lampe", Vector3(0.0, 4.2, -4.0), 0.32, colors[2], 0.65)
        _decorate_home(home, island_id, i, colors)

        var label := Label3D.new()
        label.text = _home_label(island_id, i)
        label.position = Vector3(0.0, height + 1.2, 0.0)
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.no_depth_test = true
        label.font_size = 22
        label.outline_size = 7
        label.modulate = colors[2]
        label.outline_modulate = Color(0, 0, 0, 0.88)
        home.add_child(label)

func _decorate_home(home: Node3D, island_id: int, index: int, colors: Array) -> void:
    match island_id:
        1:
            # Coin répétition : petit piano, tambour et partitions.
            for key in range(5):
                _home_box(home, "Piano_%02d" % key, Vector3(-1.6 + key * 0.8, 1.5, -3.3), Vector3(0.7, 0.18, 1.6), Color("f0ece2") if key % 2 == 0 else Color("2a2a2d"), false)
            _cylinder(home, "TambourMaison", Vector3(3.0, 0.85, 1.7), 0.75, 1.7, colors[0])
        2:
            for sweet in range(4):
                _sphere(home, "BonbonMaison_%02d" % sweet, Vector3(-1.5 + sweet, 1.5, -3.4), 0.35, colors[sweet % 3])
        3:
            for basket in range(3):
                _sphere(home, "ProduitMaison_%02d" % basket, Vector3(-1.0 + basket, 1.55, -3.4), 0.34, [Color("d66545"), Color("76a94d"), Color("e4c34f")][basket])
        4:
            _crystal(home, "CristalMaison", Vector3(0, 1.7, -3.5), 0.5, 3.2, colors[2], 0.65)
        5:
            _box(home, "EcranAtelier", Vector3(0, 2.5, -4.25), Vector3(3.5, 2.0, 0.18), colors[2], 0.45)
        6:
            _sphere(home, "OrbeSoin", Vector3(0, 1.6, -3.5), 0.72, colors[0], 0.35)
        7:
            _cylinder(home, "TonneauMaison", Vector3(3.2, 0.8, -2.5), 0.68, 1.6, Color("764b2d"))
        8:
            _box(home, "BraseroRefuge", Vector3(0, 0.55, -3.1), Vector3(1.6, 0.6, 1.6), colors[1], false)
            _sphere(home, "Chaleur", Vector3(0, 1.3, -3.1), 0.42, Color("ffb05a"), 0.7)
        9:
            _box(home, "PetiteForge", Vector3(0, 0.75, -3.2), Vector3(2.5, 1.2, 1.6), colors[1], false)
            _sphere(home, "BraiseMaison", Vector3(0, 1.55, -3.2), 0.38, colors[0], 0.9)
        10:
            _box(home, "EtabliPierre", Vector3(0, 1.0, -3.2), Vector3(3.4, 0.4, 1.8), colors[2], false)

func _spawn_themed_residents(island_id: int, info: Dictionary) -> void:
    var roles: Array = THEME_ROLES.get(island_id, ["Habitant"])
    var colors: Array = THEME_COLORS[island_id - 1]
    var size: Vector2 = info["size"]
    var count := clampi(themed_resident_budget, 4, 10)
    for i in range(count):
        var resident := _make_resident(island_id, i, colors)
        resident.name = "HabitantTheme_%02d" % i
        var side := -1.0 if i % 2 == 0 else 1.0
        var row := i / 2
        var home := Vector3(side * (54.0 + float(row % 3) * 23.0), 0.0, size.y * 0.18 - float(row) * 22.0)
        home = _ground_local(home)
        resident.position = home
        resident.set_meta("home", home)
        resident.set_meta("resident_index", i)
        resident.set_meta("role", str(roles[i % roles.size()]))
        resident.set_meta("phase", float(i) * 1.37)
        _root.add_child(resident)
        _residents.append(resident)

        var role_label := Label3D.new()
        role_label.name = "RoleTheme"
        role_label.text = str(roles[i % roles.size()]).to_upper()
        role_label.position = Vector3(0, 2.25, 0)
        role_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        role_label.no_depth_test = true
        role_label.font_size = 18
        role_label.outline_size = 6
        role_label.modulate = colors[2]
        role_label.outline_modulate = Color(0, 0, 0, 0.88)
        resident.add_child(role_label)

        var conversation := Label3D.new()
        conversation.name = "Conversation"
        conversation.text = "♪" if island_id == 1 else "…"
        conversation.position = Vector3(0.75, 2.85, 0)
        conversation.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        conversation.no_depth_test = true
        conversation.font_size = 28
        conversation.outline_size = 6
        conversation.modulate = colors[0]
        conversation.outline_modulate = Color(0, 0, 0, 0.85)
        conversation.visible = false
        resident.add_child(conversation)

func _make_resident(island_id: int, index: int, colors: Array) -> Node3D:
    var root := Node3D.new()
    var cloth: Color = colors[index % 3]
    var skin := Color("b98263") if index % 3 == 0 else (Color("d6a27c") if index % 3 == 1 else Color("7a4f39"))

    var body := MeshInstance3D.new()
    body.name = "TenueTheme"
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.30
    capsule.height = 1.28
    body.mesh = capsule
    body.position.y = 0.82
    body.material_override = _material(cloth)
    root.add_child(body)

    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.23
    sphere.height = 0.46
    head.mesh = sphere
    head.position.y = 1.62
    head.material_override = _material(skin)
    root.add_child(head)

    _add_themed_outfit(root, island_id, index, colors)
    return root

func _add_themed_outfit(root: Node3D, island_id: int, index: int, colors: Array) -> void:
    match island_id:
        1:
            _box(root, "EcharpeMusicien", Vector3(0, 1.35, 0), Vector3(0.72, 0.14, 0.42), colors[2])
            if index % 2 == 0:
                _sphere(root, "Instrument", Vector3(0.48, 0.92, -0.12), 0.32, Color("9a623b"))
                _box(root, "MancheInstrument", Vector3(0.64, 1.32, -0.12), Vector3(0.10, 0.95, 0.12), Color("6e442b"))
            else:
                _cylinder(root, "PetitTambour", Vector3(0.46, 0.72, -0.02), 0.28, 0.48, colors[0])
        2:
            _sphere(root, "ChapeauBonbon", Vector3(0, 2.00, 0), 0.32, colors[(index + 1) % 3])
        3:
            _cylinder(root, "Toque", Vector3(0, 1.98, 0), 0.28, 0.42, Color("f4eee6"))
        4:
            _crystal(root, "CristalEpaule", Vector3(0.42, 1.32, 0), 0.15, 0.85, colors[2], 0.55)
        5:
            _box(root, "Cape", Vector3(0, 1.10, 0.24), Vector3(0.72, 1.15, 0.08), colors[0])
        6:
            _sphere(root, "OrbeCeinture", Vector3(0.36, 0.82, 0), 0.18, colors[0])
            _box(root, "Casquette", Vector3(0, 1.93, -0.05), Vector3(0.52, 0.14, 0.52), colors[2])
        7:
            _box(root, "Bandana", Vector3(0, 1.88, 0), Vector3(0.52, 0.14, 0.48), colors[0])
            _box(root, "CeintureCorsaire", Vector3(0, 0.88, 0), Vector3(0.72, 0.12, 0.44), Color("55351f"))
        8:
            _box(root, "EcharpeGivre", Vector3(0, 1.34, 0), Vector3(0.78, 0.18, 0.48), colors[2])
            _sphere(root, "Bonnet", Vector3(0, 1.96, 0), 0.28, colors[1])
        9:
            _sphere(root, "EpauleBraise", Vector3(0.38, 1.30, 0), 0.20, colors[0], 0.7)
            _sphere(root, "EpauleBraise2", Vector3(-0.38, 1.30, 0), 0.20, colors[0], 0.7)
        10:
            _box(root, "Tablier", Vector3(0, 0.95, -0.23), Vector3(0.58, 0.85, 0.08), colors[2])
            _box(root, "Outil", Vector3(0.42, 0.86, 0), Vector3(0.10, 0.78, 0.10), Color("6c5537"))

func _animate_residents(delta: float) -> void:
    if _residents.is_empty() or _island_info.is_empty():
        return
    var size: Vector2 = _island_info["size"]
    for i in range(_residents.size()):
        var resident := _residents[i]
        if not is_instance_valid(resident):
            continue
        var home: Vector3 = resident.get_meta("home", resident.position)
        var phase := float(resident.get_meta("phase", 0.0))
        var cycle := int(floor((_time + phase * 2.0) / 8.5)) % 4
        var target := home
        var talking := false

        match cycle:
            0:
                # Travail autour du foyer/atelier.
                target = home + Vector3(sin(_time * 0.35 + phase) * 4.0, 0, cos(_time * 0.30 + phase) * 3.0)
            1:
                # Trajet vers la place publique.
                target = _ground_local(Vector3((-14.0 + float(i % 4) * 9.0), 0, size.y * 0.205 - float(i / 4) * 9.0))
            2:
                # Deux habitants se rejoignent réellement et se font face.
                var pair_index := i + 1 if i % 2 == 0 else i - 1
                if pair_index >= 0 and pair_index < _residents.size() and is_instance_valid(_residents[pair_index]):
                    var pair := _residents[pair_index]
                    var pair_home: Vector3 = pair.get_meta("home", pair.position)
                    var meeting := (home + pair_home) * 0.5
                    meeting = _ground_local(meeting)
                    target = meeting + Vector3(-1.15 if i % 2 == 0 else 1.15, 0, 0)
                    talking = resident.position.distance_to(target) < 1.8
                    if talking:
                        var face := pair.position - resident.position
                        face.y = 0
                        if face.length_squared() > 0.01:
                            resident.rotation.y = lerp_angle(resident.rotation.y, atan2(-face.x, -face.z), minf(1.0, delta * 5.0))
            3:
                # Retour à la maison.
                target = home

        var direction := target - resident.position
        direction.y = 0.0
        if direction.length_squared() > 0.12:
            var speed := 1.35 + float(i % 3) * 0.12
            resident.position += direction.normalized() * minf(direction.length(), speed * delta)
            resident.position.y = lerpf(resident.position.y, target.y, minf(1.0, delta * 3.0))
            resident.rotation.y = lerp_angle(resident.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 5.0))

        var bubble := resident.get_node_or_null("Conversation") as Label3D
        if bubble != null:
            bubble.visible = talking
            if talking:
                bubble.text = "♪  ♪" if _current_island == 1 else "…"
                bubble.position.y = 2.82 + sin(_time * 2.6 + phase) * 0.08

func _theme_title(island_id: int) -> String:
    match island_id:
        1: return "ACCORDIA • ROYAUME MUSICAL"
        2: return "BOURG DES CONFISERIES"
        3: return "GRAND MARCHÉ GOURMAND"
        4: return "CITÉ DES CRISTAUX"
        5: return "QUARTIER DES HÉROS"
        6: return "CAMP DES DRESSEURS"
        7: return "PORT DES CORSAIRES"
        8: return "HAMEAU DES GLACES"
        9: return "CITADELLE DES BRAISES"
        10: return "VILLAGE DES BÂTISSEURS"
        _: return "ROYAUME TROUBLÉ"

func _home_label(island_id: int, index: int) -> String:
    if island_id == 1:
        return ["ATELIER DU LUTHIER", "MAISON DES PERCUSSIONS", "FOYER DES CHORISTES"][index % 3]
    return "FOYER %02d • %s" % [index + 1, _theme_title(island_id)]

func _ground_local(local_position: Vector3) -> Vector3:
    if _root == null or get_world_3d() == null:
        return local_position
    var world_x := _root.global_position.x + local_position.x
    var world_z := _root.global_position.z + local_position.z
    var query := PhysicsRayQueryParameters3D.create(Vector3(world_x, 180.0, world_z), Vector3(world_x, -90.0, world_z), 1)
    query.collide_with_areas = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.has("position"):
        var world_hit: Vector3 = hit["position"]
        return world_hit - _root.global_position + Vector3.UP * 0.04
    return local_position

func _home_box(parent: StaticBody3D, node_name: String, pos: Vector3, size_value: Vector3, color: Color, collide: bool) -> void:
    _box(parent, node_name, pos, size_value, color)
    if not collide:
        return
    var collision := CollisionShape3D.new()
    collision.name = "%sCollision" % node_name
    var shape := BoxShape3D.new()
    shape.size = size_value
    collision.shape = shape
    collision.position = pos
    parent.add_child(collision)

func _box(parent: Node3D, node_name: String, pos: Vector3, size_value: Vector3, color: Color, emission := 0.0) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size_value
    visual.mesh = mesh
    visual.position = pos
    visual.material_override = _material(color, emission)
    parent.add_child(visual)

func _sphere(parent: Node3D, node_name: String, pos: Vector3, radius: float, color: Color, emission := 0.0) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 10
    mesh.rings = 6
    visual.mesh = mesh
    visual.position = pos
    visual.material_override = _material(color, emission)
    parent.add_child(visual)

func _cylinder(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, color: Color, emission := 0.0) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := CylinderMesh.new()
    mesh.bottom_radius = radius
    mesh.top_radius = radius
    mesh.height = height
    mesh.radial_segments = 10
    visual.mesh = mesh
    visual.position = pos
    visual.material_override = _material(color, emission)
    parent.add_child(visual)

func _crystal(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, color: Color, emission := 0.0) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := CylinderMesh.new()
    mesh.bottom_radius = radius
    mesh.top_radius = 0.05
    mesh.height = height
    mesh.radial_segments = 6
    visual.mesh = mesh
    visual.position = pos
    visual.material_override = _material(color, emission)
    parent.add_child(visual)

func _torus(parent: Node3D, node_name: String, pos: Vector3, radius: float, thickness: float, color: Color, emission := 0.0) -> void:
    var visual := MeshInstance3D.new()
    visual.name = node_name
    var mesh := TorusMesh.new()
    mesh.inner_radius = maxf(0.05, radius - thickness)
    mesh.outer_radius = radius
    mesh.rings = 16
    mesh.ring_segments = 8
    visual.mesh = mesh
    visual.position = pos
    visual.material_override = _material(color, emission)
    parent.add_child(visual)

func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.78
    if emission > 0.0:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = emission
    return material

func _notify(text: String) -> void:
    var hud := get_tree().get_first_node_in_group("hud")
    if hud != null and hud.has_method("show_subtitle"):
        hud.call("show_subtitle", text, 3.4)
        return
    var world := get_tree().get_first_node_in_group("world_director")
    if world != null and world.has_method("_notify"):
        world.call("_notify", text)
