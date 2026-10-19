extends CharacterBody3D
var health := PlayerHealth.new()
var knockdown := KnockdownState.new()

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var visual := CapsuleMesh.new()
	visual.radius = 0.35
	visual.height = 1.8
	mesh.mesh = visual
	mesh.position.y = 0.9
	add_child(mesh)
	knockdown.setup(self, mesh)
	add_child(health)
	var sign := Graybox.sign(self, "[G] FOOD → ♥", Vector3(0, 2, 0), Color.PINK)
	health.restored.connect(func(): sign.text = "♥ %.0f HP" % health.current_health)

func _physics_process(delta: float) -> void:
	knockdown.tick(delta)
	velocity = knockdown.damp_motion(velocity, delta)
	velocity.y = 0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
