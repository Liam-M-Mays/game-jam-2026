class_name SettingsButton
extends TextureButton
## The SETTINGS button art that opens a SettingsMenu. Point `menu` at the menu.
## The main menu uses the gray version to match its other buttons; everywhere else uses terracotta.

@export var menu: SettingsMenu
@export var gray := false


func _ready() -> void:
	UiArt.apply(self, "settings_gray" if gray else "settings")
	size = custom_minimum_size
	if menu:
		pressed.connect(menu.open)
