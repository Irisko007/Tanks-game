extends Area3D

var speed: float = 25.0
var damage: float = 25.0
var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 3.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var trail: GPUParticles3D = $TrailParticles

var timer: float = 0.0

func _ready() -> void:
    timer = lifetime
    look_at(global_position + direction)

func _process(delta: float) -> void:
    global_position += direction * speed * delta
    timer -= delta
    
    if timer <= 0:
        queue_free()

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("enemies"):
        if body.has_method("take_damage"):
            body.take_damage(damage)
        queue_free()
    elif body.is_in_group("boss"):
        if body.has_method("take_damage"):
            body.take_damage(damage * 0.5)
        queue_free()
