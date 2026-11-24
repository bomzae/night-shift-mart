extends "res://tests/prompt13_1_context.gd"

func setup_mart() -> void:
	await super.setup_mart()
	Input.action_press("crouch")
	player.update_stance()
	check(player.crouched,"context regression runs with lowered camera and capsule")