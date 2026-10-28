class_name CombatDecision
extends RefCounted
## Stateless distance policy; attack execution and locomotion belong to the actor.
enum Action { APPROACH, ATTACK, REPOSITION }

static func choose(distance: float, clear_attack_lane: bool, attack_ready: bool, too_close: float, attack_range: float) -> Action:
	if not clear_attack_lane: return Action.APPROACH
	if distance < too_close: return Action.REPOSITION
	if distance > attack_range: return Action.APPROACH
	return Action.ATTACK if attack_ready else Action.REPOSITION
