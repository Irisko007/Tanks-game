extends CharacterBody3D

class_name BossEnemy

signal health_changed(new_health: int)
signal died()

@export var max_health: int = 500
@export var damage: int = 30
@export var melee_range: float = 4.0
@export var ranged_range: float = 50.0
@export var attack_cooldown: float = 2.0
@export var move_speed: float = 6.0
@export var spawn_minion_interval: float = 10.0

var current_health: int
var can_attack: bool = true
var is_attacking: bool = false
var target: Node3D = null
var last_attack_time: float = 0.0
var last_spawn_time: float = 0.0
var state: String = "idle"  # idle, chase, attack_melee, attack_ranged

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var detection_range: Area3D = $DetectionRange
@onready var attack_range: Area3D = $AttackRange
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var muzzle: Node3D = $Muzzle
@onready var minion_spawn_point: Node3D = $MinionSpawnPoint

func _ready() -> void:
    current_health = max_health
    add_to_group("enemies")
    add_to_group("boss")
    
    if detection_range:
        detection_range.body_entered.connect(_on_detection_body_entered)
        detection_range.body_exited.connect(_on_detection_body_exited)
    
    if attack_range:
        attack_range.body_entered.connect(_on_attack_body_entered)
        attack_range.body_exited.connect(_on_attack_body_exited)

func _physics_process(delta: float) -> void:
    if not target or current_health <= 0:
        return
    
    var distance = global_position.distance_to(target.global_position)
    var current_time = Time.get_ticks_msec() / 1000.0
    
    # State machine
    match state:
        "idle":
            if target and distance < ranged_range:
                state = "chase"
        
        "chase":
            if distance <= melee_range:
                state = "attack_melee"
            elif distance <= ranged_range:
                state = "attack_ranged"
            else:
                move_towards_target(delta)
        
        "attack_melee":
            if distance > melee_range * 1.5:
                state = "chase"
            elif can_attack and current_time - last_attack_time >= attack_cooldown:
                perform_melee_attack()
        
        "attack_ranged":
            if distance <= melee_range:
                state = "attack_melee"
            elif can_attack and current_time - last_attack_time >= attack_cooldown:
                perform_ranged_attack()
    
    # Spawn minions periodically
    if current_time - last_spawn_time >= spawn_minion_interval:
        spawn_minion()
        last_spawn_time = current_time

func move_towards_target(delta: float) -> void:
    if not target:
        return
    
    var direction = (target.global_position - global_position).normalized()
    direction.y = 0  # Keep on ground
    velocity = direction * move_speed
    
    # Rotate towards target
    look_at(target.global_position)
    
    move_and_slide()

func perform_melee_attack() -> void:
    if not target or is_attacking:
        return
    
    is_attacking = true
    can_attack = false
    
    # Play attack animation
    if animation_player and animation_player.has_animation("attack_melee"):
        animation_player.play("attack_melee")
    
    # Deal damage after delay
    await get_tree().create_timer(0.5).timeout
    
    if target and target.has_method("take_damage"):
        target.take_damage(damage)
        
        # Special knockback effect - throw player up and away
        if target is CharacterBody3D or target.has_method("apply_knockback"):
            var knockback_dir = (target.global_position - global_position).normalized()
            knockback_dir.y = 1.5  # Launch upward
            target.velocity.y = 15.0  # Launch up
            if target.has_method("apply_knockback"):
                target.apply_knockback(knockback_dir * 30.0)
    
    last_attack_time = Time.get_ticks_msec() / 1000.0
    
    await get_tree().create_timer(0.8).timeout
    is_attacking = false
    can_attack = true

func perform_ranged_attack() -> void:
    if not target or is_attacking:
        return
    
    is_attacking = true
    can_attack = false
    
    # Play shoot animation
    if animation_player and animation_player.has_animation("attack_shoot"):
        animation_player.play("attack_shoot")
    
    # Shoot projectile
    await get_tree().create_timer(0.3).timeout
    
    if muzzle:
        var projectile_scene = preload("res://scenes/Projectile.tscn")
        if projectile_scene:
            var projectile = projectile_scene.instantiate()
            get_parent().add_child(projectile)
            projectile.global_transform = Transform3D(Basis(), muzzle.global_position)
            
            var direction = (target.global_position - muzzle.global_position).normalized()
            projectile.set_direction(direction, damage, 30.0)
    
    last_attack_time = Time.get_ticks_msec() / 1000.0
    
    await get_tree().create_timer(0.5).timeout
    is_attacking = false
    can_attack = true

func spawn_minion() -> void:
    var minion_scene = preload("res://scenes/Minion.tscn")
    if minion_scene and minion_spawn_point:
        var minion = minion_scene.instantiate()
        get_parent().add_child(minion)
        minion.global_position = minion_spawn_point.global_position
        minion.target = target

func take_damage(amount: int) -> void:
    current_health = max(0, current_health - amount)
    emit_signal("health_changed", current_health)
    
    # Flash effect
    if mesh:
        var original_material = mesh.surface_get_material(0)
        # Create flash material
        var flash_material = StandardMaterial3D.new()
        flash_material.albedo_color = Color.WHITE
        flash_material.emission_enabled = true
        flash_material.emission = Color.WHITE * 2.0
        mesh.surface_set_material(0, flash_material)
        
        await get_tree().create_timer(0.1).timeout
        
        if original_material:
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
    
    # Drop loot or effects
    await get_tree().create_timer(2.0).timeout
    queue_free()

func apply_knockback(force: Vector3) -> void:
    # Boss is heavy, reduced knockback
    velocity = force * 0.3

func _on_detection_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        target = body
        state = "chase"

func _on_detection_body_exited(body: Node3D) -> void:
    if body == target:
        target = null
        state = "idle"

func _on_attack_body_entered(body: Node3D) -> void:
    if body == target:
        state = "attack_melee"

func _on_attack_body_exited(body: Node3D) -> void:
    if body == target and state == "attack_melee":
        state = "attack_ranged"
