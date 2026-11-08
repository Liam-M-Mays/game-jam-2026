extends Hut
class_name TownHall

signal upgraded(new_level : int)

var _level := 1

func level() -> int:
	return _level

func max_level() -> int:
	return hframes - last_stage()

func upgrade() -> bool:
	if _level >= max_level():
		return false
	_level += 1
	_show_frame(last_stage() + _level - 1)
	upgraded.emit(_level)
	return true
