extends SceneTree

var _failures: Array[String] = []
var _scripts_checked := 0
var _scenes_checked := 0
var _json_checked := 0

func _initialize() -> void:
    _audit_catalog()
    _audit_data_files()
    _audit_project_resources()
    _audit_loadable_tree("res://scripts")
    _audit_loadable_tree("res://scenes")
    _audit_loadable_tree("res://addons")
    _audit_json_tree("res://data")
    _audit_asset_inventory()
    _finish()

func _audit_catalog() -> void:
    _expect(WorldCatalog.island_count() == 11, "Le catalogue doit contenir exactement 11 royaumes.")
    _expect(WorldCatalog.SEA_GAPS.size() == 10, "Le catalogue doit contenir exactement 10 distances maritimes.")

    var ids: Dictionary = {}
    for index in range(WorldCatalog.island_count()):
        var info: Dictionary = WorldCatalog.island(index)
        var island_id := int(info.get("id", 0))
        _expect(island_id == index + 1, "ID d'île incohérent à l'index %d." % index)
        _expect(not ids.has(island_id), "ID d'île dupliqué: %d" % island_id)
        ids[island_id] = true

        var size: Vector2 = info.get("size", Vector2.ZERO)
        _expect(size.x >= 1000.0 and size.y >= 1000.0, "Île %02d trop petite ou dimensions invalides: %s" % [island_id, str(size)])
        _expect(_resource_or_file_exists(str(info.get("visual", ""))), "Visuel d'île absent: %02d" % island_id)
        _expect(_resource_or_file_exists(str(info.get("boss", ""))), "Boss principal absent: île %02d" % island_id)
        _expect(_resource_or_file_exists(str(info.get("ship", ""))), "Bateau absent: île %02d" % island_id)

        var soldiers = info.get("soldiers", [])
        _expect(soldiers is Array and not (soldiers as Array).is_empty(), "Aucune force ennemie définie pour l'île %02d" % island_id)
        if soldiers is Array:
            for raw_path in soldiers:
                _expect(_resource_or_file_exists(str(raw_path)), "Asset ennemi absent île %02d: %s" % [island_id, str(raw_path)])

    for path in WorldCatalog.required_asset_paths():
        _expect(_resource_or_file_exists(path), "Asset obligatoire absent: %s" % path)

    var final_info := WorldCatalog.island(10)
    _expect(str(final_info.get("boss", "")).contains("grande boss sorcière"), "L'île 11 doit utiliser la Grande Sorcière comme boss final.")
    _expect(_resource_or_file_exists("res://assets/royaumes/11_royaume_trouble_final/boss sorcière.glb"), "Premier boss de l'île 11 absent.")
    _expect(_resource_or_file_exists(str(final_info.get("reward", ""))), "Trophée final de l'île 11 absent.")

func _audit_data_files() -> void:
    var heroes := _read_json_dict("res://data/heroes.json")
    _expect(heroes.size() == 3, "heroes.json doit définir exactement 3 héros.")
    for hero_id in ["cheikh", "yvane", "nelvyn"]:
        _expect(heroes.has(hero_id), "Héros manquant: %s" % hero_id)
        if not heroes.has(hero_id):
            continue
        var hero: Dictionary = heroes[hero_id]
        _expect(_resource_or_file_exists(str(hero.get("model", ""))), "Modèle héros absent: %s" % hero_id)
        _expect(_resource_or_file_exists(str(hero.get("backpack", ""))), "Sac héros absent: %s" % hero_id)
        var weapon := str(hero.get("weapon", ""))
        if not weapon.is_empty():
            _expect(_resource_or_file_exists(weapon), "Arme héros absente: %s" % hero_id)
        var abilities = hero.get("abilities", [])
        _expect(abilities is Array and (abilities as Array).size() >= 2, "%s doit avoir au moins 2 attaques spéciales." % hero_id)
        if abilities is Array and (abilities as Array).size() >= 2:
            _expect(int((abilities[0] as Dictionary).get("unlock_level", 0)) == 20, "Attaque 2 de %s doit se débloquer au niveau 20." % hero_id)
            _expect(int((abilities[1] as Dictionary).get("unlock_level", 0)) == 30, "Attaque 3 de %s doit se débloquer au niveau 30." % hero_id)

    var items := _read_json_dict("res://data/items.json")
    _expect(not items.is_empty(), "items.json vide ou invalide.")
    var quests := _read_json_dict("res://data/island_quests.json")
    _expect(quests.size() >= 11, "island_quests.json doit couvrir les 11 royaumes.")
    var islands := _read_json_dict("res://data/islands.json")
    _expect(islands.size() == 11, "islands.json doit contenir 11 entrées.")

func _audit_project_resources() -> void:
    _expect(str(ProjectSettings.get_setting("application/run/main_scene", "")) == "res://scenes/main/main.tscn", "La scène principale du projet est incorrecte.")
    _expect(_resource_or_file_exists("res://default_bus_layout.tres"), "default_bus_layout.tres absent.")
    var bus_layout := load("res://default_bus_layout.tres") as AudioBusLayout
    _expect(bus_layout != null, "Le layout audio ne se charge pas.")

    for autoload_name in ["GameState", "AudioDirector", "NetworkManager", "VisualUpgrade"]:
        var setting_key := "autoload/%s" % autoload_name
        _expect(ProjectSettings.has_setting(setting_key), "Autoload manquant: %s" % autoload_name)
        if ProjectSettings.has_setting(setting_key):
            var path := str(ProjectSettings.get_setting(setting_key, "")).trim_prefix("*")
            _expect(_resource_or_file_exists(path), "Script d'autoload absent: %s -> %s" % [autoload_name, path])

func _audit_loadable_tree(root_path: String) -> void:
    var directory := DirAccess.open(root_path)
    if directory == null:
        _failures.append("Dossier impossible à ouvrir: %s" % root_path)
        return
    directory.list_dir_begin()
    var name := directory.get_next()
    while name != "":
        if name != "." and name != "..":
            var path := root_path.path_join(name)
            if directory.current_is_dir():
                _audit_loadable_tree(path)
            else:
                var lower := name.to_lower()
                if lower.ends_with(".gd"):
                    _scripts_checked += 1
                    var script_resource := load(path) as Script
                    _expect(script_resource != null, "Script impossible à charger: %s" % path)
                    if script_resource != null:
                        _expect(script_resource.can_instantiate(), "Script invalide / non instanciable: %s" % path)
                elif lower.ends_with(".tscn") or lower.ends_with(".scn"):
                    _scenes_checked += 1
                    _expect(load(path) != null, "Scène impossible à charger: %s" % path)
                elif lower.ends_with(".tres") or lower.ends_with(".res"):
                    _expect(load(path) != null, "Ressource impossible à charger: %s" % path)
        name = directory.get_next()
    directory.list_dir_end()

func _audit_json_tree(root_path: String) -> void:
    var directory := DirAccess.open(root_path)
    if directory == null:
        return
    directory.list_dir_begin()
    var name := directory.get_next()
    while name != "":
        if name != "." and name != "..":
            var path := root_path.path_join(name)
            if directory.current_is_dir():
                _audit_json_tree(path)
            elif name.to_lower().ends_with(".json"):
                _json_checked += 1
                var file := FileAccess.open(path, FileAccess.READ)
                if file == null:
                    _failures.append("JSON impossible à ouvrir: %s" % path)
                else:
                    var parsed = JSON.parse_string(file.get_as_text())
                    _expect(parsed != null, "JSON invalide: %s" % path)
        name = directory.get_next()
    directory.list_dir_end()

func _audit_asset_inventory() -> void:
    var roots := [
        "res://assets/audio",
        "res://assets/bateaux_glb",
        "res://assets/branding",
        "res://assets/cinematiques",
        "res://assets/decors_glb",
        "res://assets/effets_visuels",
        "res://assets/ennemis_et_boss",
        "res://assets/equipages_libres",
        "res://assets/gameplay",
        "res://assets/interface",
        "res://assets/objets_et_recompenses",
        "res://assets/pnj_et_quetes",
        "res://assets/royaumes",
        "res://assets/vrac"
    ]
    for path in roots:
        _expect(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)), "Dossier d'assets absent: %s" % path)

    var glb_count := _count_extension("res://assets", ".glb")
    var audio_count := _count_audio("res://assets/audio")
    var image_count := _count_images("res://assets")
    print("AUDIT V11.8: %d scripts, %d scènes, %d JSON, %d GLB, %d audios, %d images" % [
        _scripts_checked, _scenes_checked, _json_checked, glb_count, audio_count, image_count
    ])
    _expect(glb_count >= 35, "Trop peu de GLB détectés: %d" % glb_count)
    _expect(audio_count >= 20, "Trop peu d'audios détectés: %d" % audio_count)
    _expect(image_count >= 20, "Trop peu d'images détectées: %d" % image_count)

func _read_json_dict(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        _failures.append("Fichier JSON absent: %s" % path)
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        _failures.append("Fichier JSON impossible à ouvrir: %s" % path)
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        _failures.append("JSON racine non-dictionnaire: %s" % path)
        return {}
    return parsed as Dictionary

func _resource_or_file_exists(path: String) -> bool:
    if path.is_empty():
        return false
    return ResourceLoader.exists(path) or FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
    if not condition:
        _failures.append(message)

func _count_images(root_path: String) -> int:
    return _count_extension(root_path, ".png") + _count_extension(root_path, ".jpg") + _count_extension(root_path, ".jpeg") + _count_extension(root_path, ".webp")

func _count_audio(root_path: String) -> int:
    return _count_extension(root_path, ".ogg") + _count_extension(root_path, ".mp3") + _count_extension(root_path, ".wav")

func _count_extension(root_path: String, extension: String) -> int:
    var directory := DirAccess.open(root_path)
    if directory == null:
        return 0
    var count := 0
    directory.list_dir_begin()
    var name := directory.get_next()
    while name != "":
        if name != "." and name != "..":
            var path := root_path.path_join(name)
            if directory.current_is_dir():
                count += _count_extension(path, extension)
            elif name.to_lower().ends_with(extension):
                count += 1
        name = directory.get_next()
    directory.list_dir_end()
    return count

func _finish() -> void:
    if _failures.is_empty():
        print("AUDIT COMPLET V11.8 OK: code, scènes, addons, données, 11 royaumes et assets validés.")
        quit(0)
        return
    for failure in _failures:
        push_error(failure)
    print("AUDIT COMPLET V11.8: %d échec(s)." % _failures.size())
    quit(2)
