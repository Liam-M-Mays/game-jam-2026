class_name OldGame
extends Object
## Tells the old global scripts whether the old jam game is on screen.
##
## During the core rewrite the old game and the new one share one project.
## The old global scripts (audio, music, dev speed) must stay quiet in every
## scene that is not part of the old game. Issue #36 removes this file together
## with the old game.

const OLD_MENU := "res://Main_Menu.tscn"
const OLD_FOLDER := "res://assets/"


## True when the scene on screen belongs to the old jam game.
static func is_running(tree: SceneTree) -> bool:
	var scene := tree.current_scene
	if scene == null:
		return false
	var path := scene.scene_file_path
	return path == OLD_MENU or path.begins_with(OLD_FOLDER)
