class_name InteractionContext
extends RefCounted
## Small resolver shared by prompts and E/F dispatch; queries never perform actions.
static func food(held: Node) -> bool:
	if not is_instance_valid(held) or not held is GrabbableBody: return false
	var data := ProductCatalog.find(held.product_type)
	return data != null and data.is_food

static func feed_target(interaction: Node) -> PlayerHealth:
	if not food(interaction.held_object): return null
	var health: PlayerHealth = interaction.player.health
	var camera: Camera3D = interaction.camera
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * (health.feed_distance + 0.5), 1 | 64 | 128, [interaction.player.get_rid(), interaction.held_object.get_rid()])
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return null
	var target := hit.collider.get_node_or_null("PlayerHealth") as PlayerHealth
	if target != null and target != health and target.is_downed and health.can_use_food(interaction.held_object, target): return target
	return null

static func resolve(interaction: Node) -> Dictionary:
	var context := {"primary": "", "secondary": "", "mouse": "", "primary_call": Callable(), "secondary_call": Callable()}
	var held: RigidBody3D = interaction.held_object
	var health: PlayerHealth = interaction.player.get_node_or_null("PlayerHealth")
	if food(held) and health != null:
		var target := feed_target(interaction)
		if target != null:
			context.primary = "[E] FEED"
			context.primary_call = health.use_food.bind(held, target)
		if health.can_use_food(held):
			context.secondary = "[F] EAT"
			context.secondary_call = health.use_food.bind(held)
	if context.primary.is_empty():
		var customers: Node = interaction.player.get_parent().get_node_or_null("Customers")
		if customers != null:
			var station: Node = customers.checkout
			var action: String = station.available_action()
			if not action.is_empty():
				context.primary = "[E] " + action.to_upper()
				context.primary_call = station.use_station.bind(action)
	if context.primary.is_empty():
		var camera: Camera3D = interaction.camera
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * interaction.grab_distance)
		ray.exclude = [interaction.player.get_rid()]
		if is_instance_valid(held): ray.exclude.append(held.get_rid())
		var hit := camera.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider is WeaponCrate and not hit.collider.opened:
			context.primary = "[E] OPEN CRATE"
			context.primary_call = hit.collider.open_crate
	if held is WeaponBody:
		if not interaction.is_charging and not held.swinging() and held.cooldown_left <= 0: context.mouse = "[LMB] SWING"
	elif held is FireExtinguisher and held.capacity > 0 and not interaction.is_charging:
		context.secondary = "[F] SPRAY"
	elif held is GrabbableBody and not interaction.is_charging:
		context.mouse = "[RMB] THROW"
	elif not is_instance_valid(held):
		var candidate: PhysicsBody3D = interaction.find_candidate()
		if candidate != null: context.mouse = "[LMB] CAPTURE" if candidate is ThiefCustomer else "[LMB] GRAB"
	return context

static func prompt(context: Dictionary) -> String:
	var lines: Array[String] = []
	for key in ["primary", "secondary", "mouse"]:
		if not context[key].is_empty() and lines.size() < 2: lines.append(context[key])
	return "\n".join(lines)
