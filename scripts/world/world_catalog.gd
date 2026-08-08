class_name WorldCatalog
extends RefCounted

# Catalogue canonique issu de NOTICE_EXPLICATIVE_PIRATE_2.md et des README de chaque royaume.
# Les tailles et distances sont en mètres de jeu. Les assets restent dans leurs dossiers d'origine.

const SEA_GAPS := [700.0, 850.0, 1000.0, 1150.0, 900.0, 1250.0, 1350.0, 1100.0, 1400.0, 1500.0]

const COMMON_PROPS := [
    "res://assets/decors_glb/glb/formation_pierre_grande.glb",
    "res://assets/decors_glb/glb/formation_pierre_moyenne.glb",
    "res://assets/decors_glb/glb/coffre_pirate.glb"
]

const ISLANDS := [
    {
        "id": 1,
        "slug": "royaume_musical",
        "name": "Royaume musical",
        "size": Vector2(1200.0, 1000.0),
        "color": Color("4b8f6a"),
        "accent": Color("d7b85a"),
        "weather": "vent_musical",
        "folder": "res://assets/royaumes/01_royaume_musical",
        "visual": "res://assets/royaumes/01_royaume_musical/visuel ile 1.png",
        "boss": "res://assets/royaumes/01_royaume_musical/boss musique ultime.glb",
        "soldiers": ["res://assets/royaumes/01_royaume_musical/solda ile 1 .glb"],
        "ship": "res://assets/bateaux_glb/iles_animes/glb/ile_01_corsaire_du_rivage_anime.glb",
        "population": true,
        "fog": false
    },
    {
        "id": 2,
        "slug": "royaume_sucrerie",
        "name": "Royaume sucrerie",
        "size": Vector2(1300.0, 1100.0),
        "color": Color("d98aa8"),
        "accent": Color("ffd8e8"),
        "weather": "pluie_sucree",
        "folder": "res://assets/royaumes/02_royaume_sucrerie",
        "visual": "res://assets/royaumes/02_royaume_sucrerie/visuel ile 2.png",
        "boss": "res://assets/royaumes/02_royaume_sucrerie/boss gardien du fromage.glb",
        "soldiers": ["res://assets/royaumes/02_royaume_sucrerie/solda commandant 3 ourson.glb"],
        "ship": "res://assets/bateaux_glb/iles_animes/glb/ile_02_requin_noir_anime.glb",
        "population": true,
        "fog": false
    },
    {
        "id": 3,
        "slug": "royaume_nourriture",
        "name": "Royaume de la nourriture",
        "size": Vector2(1500.0, 1200.0),
        "color": Color("83a85d"),
        "accent": Color("e3b34a"),
        "weather": "chaleur_gourmande",
        "folder": "res://assets/royaumes/03_royaume_nourriture",
        "visual": "res://assets/royaumes/03_royaume_nourriture/visuel royaume 3.jpg",
        "boss": "res://assets/royaumes/03_royaume_nourriture/big_mom 3 ème commandan.glb",
        "soldiers": ["res://assets/royaumes/03_royaume_nourriture/baguette 2.eme commandant_anime_compresse.glb"],
        "ship": "res://assets/bateaux_glb/iles_animes/glb/ile_03_galion_gourmand_anime.glb",
        "population": true,
        "fog": false
    },
    {
        "id": 4,
        "slug": "royaume_fantastique",
        "name": "Royaume fantastique",
        "size": Vector2(1700.0, 1400.0),
        "color": Color("617b8e"),
        "accent": Color("8fd6ff"),
        "weather": "brume_magique",
        "folder": "res://assets/royaumes/04_royaume_fantastique",
        "visual": "res://assets/royaumes/04_royaume_fantastique/visuel ile 4 royaume fantastique.png",
        "boss": "res://assets/royaumes/04_royaume_fantastique/boss ile 4.glb",
        "soldiers": ["res://assets/royaumes/04_royaume_fantastique/1 er commandant robot.glb"],
        "ship": "res://assets/bateaux_glb/iles_animes/glb/ile_04_roc_des_mers_anime.glb",
        "population": true,
        "fog": true
    },
    {
        "id": 5,
        "slug": "royaume_marvel",
        "name": "Royaume Marvel",
        "size": Vector2(2200.0, 1700.0),
        "color": Color("586477"),
        "accent": Color("ef594f"),
        "weather": "orage_urbain",
        "folder": "res://assets/royaumes/05_royaume_marvel",
        "visual": "res://assets/royaumes/05_royaume_marvel/visuel ile 5.png",
        "boss": "res://assets/royaumes/05_royaume_marvel/boss ultime Boruto.glb",
        "soldiers": ["res://assets/royaumes/05_royaume_marvel/himawarie 1 er commedan .glb"],
        "ship": "res://assets/bateaux_glb/iles_animes/glb/ile_05_volcan_rouge_anime.glb",
        "population": true,
        "fog": false
    },
    {
        "id": 6,
        "slug": "royaume_pokemon",
        "name": "Royaume Pokémon",
        "size": Vector2(1900.0, 1500.0),
        "color": Color("58a26b"),
        "accent": Color("f2dc4f"),
        "weather": "pluie_forestiere",
        "folder": "res://assets/royaumes/06_royaume_pokemon",
        "visual": "res://assets/royaumes/06_royaume_pokemon/visuel royaume 6.png",
        "boss": "res://assets/royaumes/06_royaume_pokemon/brok boss .glb",
        "soldiers": ["res://assets/royaumes/06_royaume_pokemon/brok boss .glb"],
        "ship": "res://assets/bateaux_glb/iles_animes/glb/ile_06_brume_des_marais_anime.glb",
        "population": true,
        "fog": false
    },
    {
        "id": 7,
        "slug": "ile_des_pirates",
        "name": "Île des pirates",
        "size": Vector2(2400.0, 1800.0),
        "color": Color("8d7048"),
        "accent": Color("d6a94c"),
        "weather": "tempete_pirate",
        "folder": "res://assets/royaumes/07_ile_des_pirates",
        "visual": "res://assets/royaumes/07_ile_des_pirates/visuel royaume 7.jpg",
        "boss": "res://assets/royaumes/07_ile_des_pirates/baggy boss .glb",
        "soldiers": ["res://assets/royaumes/07_ile_des_pirates/jigen_anime_compresse.glb"],
        "ship": "res://assets/bateaux_glb/iles_animes/glb/ile_07_forteresse_flottante_anime.glb",
        "population": true,
        "fog": false
    },
    {
        "id": 8,
        "slug": "royaume_des_neiges",
        "name": "Royaume des neiges",
        "size": Vector2(2200.0, 1800.0),
        "color": Color("c7dce8"),
        "accent": Color("8cb8d6"),
        "weather": "neige",
        "folder": "res://assets/royaumes/08_royaume_des_neiges",
        "visual": "res://assets/royaumes/08_royaume_des_neiges/visuel royaume 8.jpg",
        "boss": "res://assets/royaumes/08_royaume_des_neiges/solda pharaon.glb",
        "soldiers": ["res://assets/royaumes/08_royaume_des_neiges/solda pharaon.glb"],
        "ship": "res://assets/bateaux_glb/iles_animes/glb/ile_08_jungle_emeraude_anime.glb",
        "population": true,
        "fog": true
    },
    {
        "id": 9,
        "slug": "royaume_de_feu",
        "name": "Royaume de feu",
        "size": Vector2(2300.0, 1800.0),
        "color": Color("4d3935"),
        "accent": Color("ff6038"),
        "weather": "cendres",
        "folder": "res://assets/royaumes/09_royaume_de_feu",
        "visual": "res://assets/royaumes/09_royaume_de_feu/visuel royaume 9.jpg",
        "boss": "res://assets/royaumes/09_royaume_de_feu/boss Sangoku.glb",
        "soldiers": [
            "res://assets/royaumes/09_royaume_de_feu/logan 1 er commandant de goku.glb",
            "res://assets/royaumes/09_royaume_de_feu/zian_anime 2 ème commandant.glb"
        ],
        "ship": "res://assets/bateaux_glb/iles_animes/glb/ile_09_abysses_bleus_anime.glb",
        "population": true,
        "fog": false
    },
    {
        "id": 10,
        "slug": "royaume_de_la_terre",
        "name": "Royaume de la terre",
        "size": Vector2(2600.0, 2000.0),
        "color": Color("665c43"),
        "accent": Color("9fbd68"),
        "weather": "poussiere",
        "folder": "res://assets/royaumes/10_royaume_de_la_terre",
        "visual": "res://assets/royaumes/10_royaume_de_la_terre/visuel royaume 10.jpg",
        "boss": "res://assets/royaumes/10_royaume_de_la_terre/brok boss .glb",
        "soldiers": [
            "res://assets/royaumes/10_royaume_de_la_terre/Shelly solda .glb",
            "res://assets/royaumes/10_royaume_de_la_terre/drako_ameliore_anime_compresse.glb"
        ],
        "ship": "res://assets/bateaux_glb/iles_animes/glb/ile_10_galion_royal_anime.glb",
        "population": true,
        "fog": false
    },
    {
        "id": 11,
        "slug": "royaume_trouble_final",
        "name": "Royaume troublé",
        "size": Vector2(3000.0, 2300.0),
        "color": Color("554b3c"),
        "accent": Color("d8b957"),
        "weather": "brume_doree",
        "folder": "res://assets/royaumes/11_royaume_trouble_final",
        "visual": "res://assets/royaumes/11_royaume_trouble_final/visuel royaume 11.jpg",
        "boss": "res://assets/royaumes/11_royaume_trouble_final/grande boss sorcière des cauchemars.glb",
        "soldiers": [
            "res://assets/royaumes/11_royaume_trouble_final/boss sorcière.glb",
            "res://assets/royaumes/11_royaume_trouble_final/ymu_sama_ 1er commandant de la grande boss sorcière.glb"
        ],
        "reward": "res://assets/royaumes/11_royaume_trouble_final/trophée jeux fin du jeux.glb",
        "ship": "res://assets/bateaux_glb/iles_animes/glb/ile_11_spectre_des_souvenirs_anime.glb",
        "population": false,
        "fog": true
    }
]

static func island(index: int) -> Dictionary:
    return ISLANDS[clampi(index, 0, ISLANDS.size() - 1)]

static func island_count() -> int:
    return ISLANDS.size()

static func world_positions() -> Array[Vector3]:
    var result: Array[Vector3] = []
    var z := 0.0
    for i in range(ISLANDS.size()):
        if i > 0:
            var prev_size: Vector2 = ISLANDS[i - 1]["size"]
            var current_size: Vector2 = ISLANDS[i]["size"]
            z -= prev_size.y * 0.5 + SEA_GAPS[i - 1] + current_size.y * 0.5
        var x := sin(float(i) * 1.37) * 720.0
        result.append(Vector3(x, 0.0, z))
    return result

static func required_asset_paths() -> PackedStringArray:
    var paths := PackedStringArray([
        "res://joueur 1 cheikh anime.glb",
        "res://Yvane_anime_Godot_Draco.glb",
        "res://player_3_Nelvyn_Godot_anime (1).glb",
        "res://assets/interface/logo_chk_pirate_warrior_2.png",
        "res://assets/interface/menu_principal_chk_pirate_warrior_2.png",
        "res://assets/interface/menu_choix difficulté_aventure_chk_pirate_warrior_2.png"
    ])
    for info in ISLANDS:
        paths.append(str(info["folder"]) + "/README.md")
        paths.append(str(info["visual"]))
        paths.append(str(info["boss"]))
        paths.append(str(info["ship"]))
        for soldier_path in info.get("soldiers", []):
            paths.append(str(soldier_path))
        if info.has("reward"):
            paths.append(str(info["reward"]))
    return paths
