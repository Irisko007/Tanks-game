extends CharacterBody3D

@export var move_speed: float = 6.0
@export var chase_speed: float = 10.0
@export var attack_range: float = 4.0
@export var shoot_range: float = 25.0
@export var damage: float = 15.0
@export var health: float = 50.0
@export var minion_spawn_interval: float = 8.0
@export var max_minions: int = 4

var player: Node3D = null
var state: String = "idle"
var attack_cooldown: float = 0.0
var minion_timer: float = 0.0
var current_minions: int = 0
var is_attacking: bool = false
var knockback_force: float = 30.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var detection_area: Area3D = $DetectionArea
@onready var attack_area: Area3D = $AttackArea
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var shoot_point: Marker3D = $ShootPoint
@onready var health_bar: ProgressBar = $HealthBar

signal died()

func _ready() -> void:
    add_to_group("boss")
    add_to_group("enemies")
    minion_timer = minion_spawn_interval
    detection_area.body_entered.connect(_on_detection_body_entered)
    detection_area.body_exited.connect(_on_detection_body_exited)
    attack_area.body_entered.connect(_on_attack_body_entered)

func _physics_process(delta: float) -> void:
    if health <= 0:
        return
    
    update_state(delta)
    apply_behavior(delta)
    apply_gravity(delta)
    
    if global_position.y < -10:
        global_position.y = 5
        velocity.y = 0

func update_state(delta: float) -> void:
    attack_cooldown = max(0, attack_cooldown - delta)
    minion_timer -= delta
    
    if minion_timer <= 0 and current_minions < max_minions:
        spawn_minion()
        minion_timer = minion_spawn_interval

func apply_behavior(delta: float) -> void:
    if not player:
        return
    
    var distance = global_position.distance_to(player.global_position)
    var direction = (player.global_position - global_position).normalized()
    direction.y = 0
    
    match state:
        "idle":
            if distance < shoot_range:
                state = "chase"
        "chase":
            if distance > attack_range:
                velocity.x = direction.x * chase_speed
                velocity.z = direction.z * chase_speed
                look_at(player.global_position)
            else:
                state = "attack"
                velocity.x = lerp(velocity.x, 0, delta * 5)
                velocity.z = lerp(velocity.z, 0, delta * 5)
        "attack":
            velocity.x = lerp(velocity.x, 0, delta * 5)
            velocity.z = lerp(velocity.z, 0, delta * 5)
            
            if distance > attack_range * 1.5:
                state = "chase"
            elif attack_cooldown <= 0:
                perform_attack()
    
    move_and_slide()

func apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= 20.0 * delta

func perform_attack() -> void:
    if is_attacking:
        return
    
    is_attacking = true
    attack_cooldown = 2.0
    
    var distance = global_position.distance_to(player.global_position)
    
    if distance <= attack_range:
        state = "melee"
        var tween = create_tween()
        tween.tween_property(mesh, "scale", Vector3(1.2, 0.8, 1.2), 0.15)
        tween.tween_property(mesh, "scale", Vector3.ONE, 0.15)
        
        await get_tree().create_timer(0.2).timeout
        
        if player and player.has_method("take_damage"):
            var knockback_dir = (player.global_position - global_position).normalized()
            knockback_dir.y = 0.5
            player.velocity = knockback_dir * knockback_force
            player.velocity.y = 15
            player.take_damage(damage)
    else:
        state = "shoot"
        shoot_projectile()
    
    await get_tree().create_timer(0.5).timeout
    is_attacking = false
    state = "chase"

func shoot_projectile() -> void:
    if not player or not shoot_point:
        return
    
    var projectile = preload("res://scenes/Projectile.tscn").instantiate()
    projectile.global_position = shoot_point.global_position
    var dir = (player.global_position - shoot_point.global_position).normalized()
    projectile.direction = dir
    projectile.damage = damage * 0.7
    get_tree().current_scene.add_child(projectile)

func spawn_minion() -> void:
    var minion_scene = preload("res://scenes/MinionEnemy.tscn")
    if minion_scene == null:
        return
    
    for i in range(minion_spawn_interval):
        pass
    current_minions += 1

func take_damage(amount: float) -> void:
    health -= amount
    if health_bar:
        health_bar.value = health
    
    var flash_tween = create_tween()
    flash_tween.tween_property(mesh, "modulate", Color(2, 0, 0, 1), 0.1)
    flash_tween.tween_property(mesh, "modulate", Color(1, 1, 1, 1), 0.1)
    
    if health <= 0:
        die()

func die() -> void:
    died.emit()
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector3.ZERO, 0.5)
    tween.tween_property(mesh, "modulate", Color(0, 0, 0, 0), 0.3)
    tween.tween_callback(queue_free)

func _on_detection_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        player = body
        state = "chase"

func _on_detection_body_exited(body: Node3D) -> void:
    if body == player:
        player = null
        state = "idle"

func _on_attack_body_entered(body: Node3D) -> void:
    pass
