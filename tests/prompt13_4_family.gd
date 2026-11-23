extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	await setup_mart()
	var families = mart.get_node("LostFamilies")
	var spawned := 0
	for cycle in range(3):
		var child: LostChild = families.spawn_pair()
		check(child != null,"repeat family spawn "+str(cycle))
		if child == null: break
		var parent: LostParent = child.parent_npc
		child.position = parent.position + Vector3(0,0.7,0.7)
		await frames(2)
		if not child.reunited: families.try_reunion(child)
		check(child.reunited,"actual family reunion")
		var orphan := CharacterBody3D.new()
		var pairs_before: int = families._npc_exceptions.size()
		families._ignore_pair(child,orphan)
		check(families._npc_exceptions.size() == pairs_before,"out-of-tree body cannot enter exception pairs")
		orphan.free()
		for i in range(6):
			var buyer := manager.spawn_customer([&"can"])
			check(buyer != null,"customer continues spawning during family exit")
			if buyer == null: continue
			spawned += 1
			await frames(2)
			check(child.get_collision_exceptions().has(buyer) and buyer.get_collision_exceptions().has(child),"reunited child and new customer retain symmetric exclusion")
			check(parent.get_collision_exceptions().has(buyer) and buyer.get_collision_exceptions().has(parent),"reunited parent and new customer retain symmetric exclusion")
			manager.customers.erase(buyer)
			buyer.queue_free()
			await frames(2)
			# Reading these is exactly where stale engine RIDs previously raised body-null.
			check(not child.get_collision_exceptions().has(null) and not parent.get_collision_exceptions().has(null),"customer exit removes physics RID before free")
			for record in families._npc_exceptions:
				check(is_instance_valid(record[0].get_ref()) and is_instance_valid(record[1].get_ref()),"all tracked collision bodies remain live")
		await frames(1800)
		check(families.pairs.is_empty(),"family exits during continuing customer activity")
		check(families._npc_exceptions.is_empty(),"departed family leaves no pair references")
	check(spawned == 18 and families.lost_children_found == 3,"three clean family lifecycles and eighteen real customer spawns")
	print("FAMILY134 cycles=3 customers=",spawned," found=",families.lost_children_found)
	var abandoned: LostChild = families.spawn_pair()
	var parent: LostParent = abandoned.parent_npc
	abandoned.position = parent.position + Vector3(0,0.7,0.7)
	await frames(2)
	if not abandoned.reunited: families.try_reunion(abandoned)
	abandoned.queue_free()
	var buyer := manager.spawn_customer([&"can"])
	await frames(3)
	check(families.pairs.is_empty() and not is_instance_valid(parent),"externally removed family member clears stale pair and remaining actor")
	check(families._npc_exceptions.is_empty(),"queued family and concurrent spawn leave no exception references")
	check(is_instance_valid(buyer) and buyer.get_collision_exceptions().is_empty(),"surviving customer retains normal collision after family removal")
	quit(1 if failures else 0)