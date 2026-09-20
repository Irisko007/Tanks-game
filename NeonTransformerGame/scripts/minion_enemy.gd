extends CharacterBody3D

class_name MinionEnemy

signal died()

@export var max_health: int = 50
@export var damage: int = 10
@export var move_speed: float = 4.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5

var current_health: int
var can_attack: bool = true
var target: Node3D = null
var last_attack_time: float = 0.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var detection_area: Area3D = $DetectionArea

func _ready() -> void:
    current_health = max_health
    add_to_group("enemies")
    add_to_group("minions")
    
    if detection_area:
        detection_area.body_entered.connect(_on_detection_body_entered)
        detection_area.body_exited.connect(_on_detection_body_exited)

func _physics_process(delta: float) -> void:
    if not target or current_health <= 0:
        return
    
    var distance = global_position.distance_to(target.global_position)
    var current_time = Time.get_ticks_msec() / 1000.0
    
    # Move towards target
    if distance > attack_range:
        var direction = (target.global_position - global_position).normalized()
        direction.y = 0
        velocity = direction * move_speed
        look_at(target.global_position)
        move_and_slide()
    else:
        # Attack
        if can_attack and current_time - last_attack_time >= attack_cooldown:
            perform_attack()

func perform_attack() -> void:
    if not target:
        return
    
    can_attack = false
    
    if animation_player and animation_player.has_animation("attack"):
        animation_player.play("attack")
    
    await get_tree().create_timer(0.3).timeout
    
    if target and target.has_method("take_damage"):
        target.take_damage(damage)
    
    last_attack_time = Time.get_ticks_msec() / 1000.0
    
    await get_tree().create_timer(0.5).timeout
    can_attack = true

func take_damage(amount: int) -> void:
    current_health = max(0, current_health - amount)
    
    # Flash effect
    if mesh:
        var flash_material = StandardMaterial3D.new()
        flash_material.albedo_color = Color.RED
        flash_material.emission_enabled = true
        flash_material.emission = Color.RED * 2.0
        mesh.surface_set_material(0, flash_material)
        
        await get_tree().create_timer(0.1).timeout
        
        # Restore original material
        var original_material = StandardMaterial3D.new()
        original_material.albedo_color = Color(0.8, 0.0, 0.0)
        original_material.emission_enabled = true
        original_material.emission = Color(0.5, 0.0, 0.0)
        mesh.surface_set_material(0, original_material)
    
    if current_health <= 0:
        die()

func die() -> void:
    emit_signal("died")
    
    # Death animation
    if animation_player and animation_player.has_animation("death"):
        animation_player.play("death")
    else:
        queue_free()
    
    await get_tree().create_timer(1.0).timeout
    queue_free()

func apply_knockback(force: Vector3) -> void:
    velocity = force * 0.5

func _on_detection_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        target = body

func _on_detection_body_exited(body: Node3D) -> void:
    if body == target:
        target = null
