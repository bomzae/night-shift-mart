extends "res://tests/prompt12_3_contact.gd"

func directional_contact(label: String, point: Vector3, normal: Vector3, yaw: float = 0) -> void:
	await boss_setup()
	rat.position = Vector3(0, 0.01, 15)
	rat.rotation.y = yaw
	rat.clear_aggro()
	rat.state = KingRat.State.SPAWN
	rat._left = 100
	rat.close_threat_time = 100
	player.position = rat.to_global(point)
	player.velocity = rat.global_basis * Vector3.RIGHT * 5
	player.external_velocity = Vector3.ZERO
	await frames(2)
	var outward := rat.global_basis * normal
	check(player.health.current_health == 90 and rat.contact_damage_count == 1, label + " damage ten once")
	check(player.body_bump_velocity.normalized().dot(outward) > 0.9, label + " outside body direction")
	check(player.body_control_multiplier() < 0.5 and interaction.camera_impact > 0.025, label + " control and camera response")
	var start := player.position
	var rat_start := rat.position
	player.set_physics_process(true)
	await frames(10)
	check((player.position-start).dot(outward) > 0.15, label + " horizontal displacement")
	check(absf(player.velocity.y) < 0.2 and absf(player.position.y-start.y) < 0.05 and not player.knockdown.active(), label + " no vertical bounce or knockdown")
	check(rat.position.distance_to(rat_start) < 0.02 and rat._flash == 0 and not rat.is_aggro, label + " stable neutral unflashed rat")
	await frames(20)
	check(player.body_control_multiplier() == 1 and player.body_bump_left == 0 and interaction.camera_impact == 0, label + " control and camera restore")
	print("CONTACT124 ", label, " displacement=", player.position-start, " rat_displacement=", rat.position-rat_start)
	player.set_physics_process(false)

func run_checks() -> void:
	await directional_contact("front", Vector3(0,0,-1.2), Vector3.FORWARD)
	await directional_contact("side", Vector3(1.2,0,0), Vector3.RIGHT)
	await directional_contact("tail-tip", Vector3(0,0,2.2), Vector3.BACK)
	await directional_contact("tail-side", Vector3(0.4,0,1.6), Vector3.RIGHT)
	await directional_contact("rotated-tail", Vector3(0,0,2.2), Vector3.BACK, PI/2)
	await contact_setup()
	player.position = rat.position + Vector3.RIGHT * 1.2
	player.health.current_health = 100
	rat._contact_waits.clear()
	await frames(43)
	check(player.health.current_health == 90, "feedback retains per-player cooldown")
	await frames(24)
	check(player.health.current_health == 80, "persistent contact after cooldown")
	await contact_setup()
	player.position = rat.position + Vector3(0,0,2.2)
	player.health.current_health = 100
	rat._contact_waits.clear()
	Graybox.box(mart, "ContactWall", Vector3(3,2,0.12), rat.position + Vector3(0,1,1.95), Color.GRAY)
	await frames(4)
	check(player.health.current_health == 100, "tail contact cannot damage through wall")
	quit(1 if failures else 0)
