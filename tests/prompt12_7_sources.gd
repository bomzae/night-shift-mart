extends "res://tests/prompt11_smoke.gd"

func boss_setup() -> void:
	await super.boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(0,0.01,20)
	rat.provoke(player)
	rat.update_awareness(0)
	rat.begin_telegraph()
	rat.advance_committed_attack(rat.telegraph_time)
	check(rat.state == KingRat.State.CHARGE and rat.attack_instance_id == 1, "source fixture has a committed executed charge")
	# Freeze only target motor for repeatable projectile/cart trajectories.
	# Delivery, rigid-body collision and receive_impact are actual Main paths.
	rat.set_physics_process(false)
	rat.receive_impact(0,Vector3.RIGHT)
	check(rat.attack_committed and rat.charge_interrupt_count == 0, "zero damage force cannot interrupt charge")

func interrupted(label: String) -> void:
	check(not rat.attack_committed and rat.state != KingRat.State.CHARGE and not rat._charge_started, "actual damage cancels charge " + label)
	check(rat.ended_attack_instance_id == 1 and rat.charge_interrupt_count == 1 and rat.telegraph_start_count == 1 and rat.charge_start_count == 1, "source ends original instance exactly once " + label)
	check(rat._recoil_left > 0 and rat._flash > 0, "source keeps recoil and flash " + label)

func run_checks() -> void:
	await projectile_trial(&"frying_pan",1)
	interrupted("product")
	for loaded in [false,true]:
		await cart_trial(loaded)
		interrupted("cart bomb" if loaded else "cart")
	print("P127 sources complete failures=",failures)
	quit(1 if failures else 0)
