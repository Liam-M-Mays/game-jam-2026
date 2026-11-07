extends resource

#func _on_mouse_entered() -> void:
	#modulate = Color.RED
	#for cell in cells:
		#cell.set_trans(0.5)
#
#func _on_mouse_exited() -> void:
	#modulate = Color.WHITE
	#for cell in cells:
		#cell.set_trans(0)
