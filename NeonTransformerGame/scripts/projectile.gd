extends RigidBody3D

class_name Projectile

var damage: int = 10
var speed: float = 40.0
var direction: Vector3 = Vector3.ZERO
var lifetime: float = 3.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var trail_particles: GPUParticles3D = $TrailParticles
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var timer: Timer = $LifetimeTimer

func _ready() -> void:
    # Set up physics
    linear_damp = 0.0
    angular_damp = 0.0
    gravity_scale = 0.0
    
    # Setup collision
    collision_layer = 4  # Projectiles layer
    collision_mask = 3  # Enemies and World
    
    if timer:
        timer.wait_time = lifetime
        timer.timeout.connect(_on_lifetime_timeout)
        timer.start()
    
    if trail_particles:
        trail_particles.emitting = true

func set_direction(dir: Vector3, dmg: int, spd: float) -> void:
    direction = dir.normalized()
    damage = dmg
    speed = spd
    
    # Rotate projectile to face direction
    look_at(global_position + direction)

func _physics_process(delta: float) -> void:
    # Move projectile
    position += direction * speed * delta
    
    # Rotate for visual effect
    rotate_z(PI * delta * 2)

func _on_lifetime_timeout() -> void:
    explode()

func explode() -> void:
    # Create explosion effect
    create_explosion_effect()
    queue_free()

func create_explosion_effect() -> void:
    # Spawn explosion particles
    var explosion_scene = preload("res://effects/Explosion.tscn")
    if explosion_scene:
        var explosion = explosion_scene.instantiate()
        get_parent().add_child(explosion)
        explosion.global_position = global_position

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("enemies"):
        if body.has_method("take_damage"):
            body.take_damage(damage)
        explode()
    elif body.is_in_group("world") and not body.is_in_group("player"):
        explode()
