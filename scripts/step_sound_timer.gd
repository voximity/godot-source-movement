extends Timer

func on_timeout() -> void:
	get_parent().play()
