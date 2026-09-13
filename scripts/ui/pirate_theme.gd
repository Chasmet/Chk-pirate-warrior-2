class_name CHKPirateTheme
extends RefCounted

static func create() -> Theme:
    var theme := Theme.new()
    theme.default_font_size = 20
    theme.set_color("font_color", "Label", Color("edf4ee"))
    for type in ["Button", "OptionButton"]:
        theme.set_stylebox("normal", type, _box("102d3c", "436071"))
        theme.set_stylebox("hover", type, _box("1c4855", "b6c991"))
        theme.set_stylebox("pressed", type, _box("23616a", "f4d477"))
        theme.set_stylebox("disabled", type, _box("152430", "293d4a"))
        var focus := _box("00000000", "f4d477")
        focus.set_border_width_all(2)
        theme.set_stylebox("focus", type, focus)
        theme.set_color("font_color", type, Color("f4e9cf"))
        theme.set_color("font_hover_color", type, Color("ffffff"))
        theme.set_color("font_pressed_color", type, Color("ffffff"))
        theme.set_color("font_disabled_color", type, Color("8396a0"))
    theme.set_stylebox("panel", "PanelContainer", _box("102532", "436071"))
    theme.set_stylebox("panel", "TabContainer", _box("0c202c", "385364"))
    theme.set_stylebox("tab_selected", "TabContainer", _box("23616a", "e5cd8e"))
    theme.set_stylebox("tab_unselected", "TabContainer", _box("122e3c", "385364"))
    theme.set_color("font_selected_color", "TabContainer", Color("fff1c6"))
    theme.set_color("font_unselected_color", "TabContainer", Color("b7cbd3"))
    theme.set_stylebox("background", "ProgressBar", _box("142d3b", "385364"))
    theme.set_stylebox("fill", "ProgressBar", _box("38a29b", "75d5b6"))
    return theme

static func _box(background: String, border: String) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color(background)
    box.border_color = Color(border)
    box.set_border_width_all(1)
    box.set_corner_radius_all(9)
    box.content_margin_left = 16
    box.content_margin_right = 16
    box.content_margin_top = 10
    box.content_margin_bottom = 10
    return box
