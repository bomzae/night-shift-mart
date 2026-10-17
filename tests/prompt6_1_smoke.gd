extends "res://tests/prompt6_smoke.gd"

func reunite_at(child: LostChild, offset: Vector3) -> bool:
	var parent: LostParent = child.parent_npc
	await place(child, parent.global_position + offset)
	child.begin_carry(interaction, player)
	interaction.held_object = child
	interaction.drop_held(true)
	return child.reunited

func bilateral(a: PhysicsBody3D, b: PhysicsBody3D) -> bool:
	return a.get_collision_exceptions().has(b) and b.get_collision_exceptions().has(a)

func run_checks() -> void:
	await setup_mart()
	var families: Node = mart.get_node("LostFamilies")
	var child: LostChild = families.spawn_pair()
	var parent: LostParent = child.parent_npc
	check(not bilateral(child, parent), "no family-specific exception before reunion; human layer policy applies")
	check(await reunite_at(child, Vector3(0, 0.6, -0.5)), "reunion with child immediately in parent's path")
	check(bilateral(child, parent), "reunion installs bilateral parent-child exception")
	# Baseline reproduction can run before the new follow API exists.
	if not child.has_method("follow_position"):
		check(false, "child exposes an offset follow target")
		print("Prompt 6.1 baseline completed; failures: ", failures)
		quit(1)
		return
	await frames(65)
	var start := parent.global_position
	var follower_start := child.global_position
	await frames(100)
	check(parent.global_position.distance_to(start) > 0.8, "parent progresses despite child in initial path")
	check(child.global_position.distance_to(follower_start) > 0.6, "child physically follows moving parent")
	var target: Vector3 = child.follow_position()
	var offset := target - parent.global_position
	check(is_equal_approx(offset.dot(parent.exit_direction), -child.follow_distance), "follow target behind parent's departure direction")
	check(is_equal_approx(offset.dot(parent.exit_direction.cross(Vector3.UP)), child.lateral_offset), "follow target has lateral offset")
	check(child.collision_mask == (1 | HumanSeparation.MONSTER_LAYER) and parent.collision_mask == (1 | HumanSeparation.MONSTER_LAYER), "world collision masks unchanged")
	check(not child.get_collision_exceptions().has(player) and not parent.get_collision_exceptions().has(player), "player collision retained after carry separation")
	var cart: ShoppingCart = mart.get_node("Cart")
	check(not child.get_collision_exceptions().has(cart) and not parent.get_collision_exceptions().has(cart), "cart collision retained")
	# Spawn customers AFTER reunion, directly on opposite entrance trajectories.
	await stock("can", Vector3(-0.5, 0, 0))
	await stock("can", Vector3(0.5, 0, 0))
	var incoming := manager.spawn_customer([&"can"])
	check(bilateral(parent, incoming) and bilateral(child, incoming), "new customer immediately receives both collision directions")
	parent.global_position = Vector3(-3, 0.01, 9)
	parent.waypoints = [Vector3(-3, 0.01, 11)]
	parent.state = BasicCustomer.State.EXIT
	incoming.global_position = Vector3(-3, 0.01, 11)
	incoming.waypoints = [Vector3(-3, 0.01, 8), Vector3(-7.65, 0, 3.1)]
	await frames(15)
	var another := manager.spawn_customer([&"can"])
	if another == null:
		await frames(25)
		another = manager.spawn_customer([&"can"])
	check(another != null and not bilateral(incoming, another), "normal customers need no pair exceptions")
	var crossed := false
	for tick in range(300):
		await frames(1)
		if is_instance_valid(parent) and parent.global_position.z > incoming.global_position.z:
			crossed = true
		if not is_instance_valid(parent): break
	check(crossed and incoming.global_position.z < 10, "incoming customer and departing family cross head-on")
	check(not is_instance_valid(parent) and not is_instance_valid(child), "parent arrival completes entire family")
	check(incoming.get_collision_exceptions().is_empty(), "temporary NPC exceptions cleaned after family exit")
	check(families.lost_children_found == 1, "exit never duplicates reunion statistic")

	# Multiple families, including overlapping drop and recovery without teleport.
	await setup_mart()
	families = mart.get_node("LostFamilies")
	child = families.spawn_pair()
	var other: LostChild = families.spawn_pair()
	parent = child.parent_npc
	var other_parent: LostParent = other.parent_npc
	check(not bilateral(parent, other_parent), "unresolved families need no pair exceptions")
	check(await reunite_at(child, Vector3(0, 0.65, 0)), "overlapping child drop reunites safely")
	check(not bilateral(child, other_parent) and not bilateral(parent, other), "unresolved other family needs no pair exceptions")
	check(await reunite_at(other, Vector3(0.2, 0.65, 0.3)), "second family reunites nearby")
	check(bilateral(parent, other_parent) and bilateral(child, other_parent) and bilateral(child, other), "all departing family bodies have bilateral exceptions")
	await place(child, Vector3(6, 0.55, 2))
	var child_start := child.global_position
	await frames(1)
	check(child.global_position.distance_to(child_start) < 0.3, "large separation does not teleport follower")
	await frames(45)
	check(child.linear_velocity.length() <= child.recovery_speed + 1, "recovery speed bounded")
	for tick in range(1200):
		await frames(1)
		if families.pairs.is_empty(): break
	check(families.pairs.is_empty() and families.lost_children_found == 2, "both families exit without mutual blocking or waiting for child trigger")
	check(families._npc_exceptions.is_empty(), "all family exception records released")
	# Pre-existing customers use the same exceptions; geometry must still block.
	await setup_mart()
	families = mart.get_node("LostFamilies")
	var product := await stock("can")
	var existing := manager.spawn_customer([&"can"])
	existing.set_physics_process(false)
	child = families.spawn_pair()
	parent = child.parent_npc
	# Keep this isolated wall test east of the real checkout counter (x=5,z=10).
	parent.global_position = Vector3(7.5, 0.01, 8)
	check(not bilateral(child, existing) and not bilateral(parent, existing), "waiting family needs no customer exceptions")
	check(await reunite_at(child, Vector3(0, 0.65, 0)), "reunion with customer already in scene")
	check(bilateral(child, existing) and bilateral(parent, existing), "existing customer receives reciprocal exceptions")
	check(not child.get_collision_exceptions().has(product) and not parent.get_collision_exceptions().has(product), "physical product collision retained")
	families.pairs[0].reunion_left = -1.0
	var wall := Graybox.box(mart, "ExitWallFixture", Vector3(2, 2, 0.2), Vector3(7.5, 1, 8.9), Color.GRAY)
	parent.waypoints = [Vector3(7.5, 0.01, 10.5)]
	parent.state = BasicCustomer.State.EXIT
	await frames(140)
	check(parent.global_position.z < 8.7 and not parent.exit_arrived, "departing parent remains blocked by solid world geometry")
	wall.queue_free()
	await frames(220)
	if is_instance_valid(parent):
		print("EXIT obstacle diagnostic position=", parent.global_position, " velocity=", parent.velocity)
		for index in parent.get_slide_collision_count():
			print("EXIT remaining collider=", parent.get_slide_collision(index).get_collider().get_path())
	check(families.pairs.is_empty(), "family resumes and exits after physical obstacle removed")
	check(existing.get_collision_exceptions().is_empty(), "existing customer's collision exceptions restored")
	print("Prompt 6.1 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
