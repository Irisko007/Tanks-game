extends Node3D

class_name Player

# Signals
signal health_changed(new_health: int)
signal form_changed(is_robot: bool)

# Export variables for customization
@export_group("Movement")
@export var car_speed: float = 15.0
@export var robot_speed: float = 8.0
@export var sprint_multiplier: float = 1.8
@export var jump_force: float = 12.0
@export var rotation_speed: float = 10.0
@export var air_control: float = 0.3

@export_group("Combat")
@export var melee_damage: int = 25
@export var ranged_damage: int = 15
@export var melee_range: float = 3.0
@export var fire_rate: float = 0.3
@export var projectile_speed: float = 40.0

@export_group("Health")
@export var max_health: int = 100

# Private variables
var is_robot_form: bool = true  # Start in robot form
var velocity: Vector3 = Vector3.ZERO
var can_jump: bool = false
var jump_count: int = 0
const MAX_JUMPS: int = 2
var is_sprinting: bool = false
var current_health: int
var can_attack: bool = true
var last_fire_time: float = 0.0
var is_attacking: bool = false
var is_transforming: bool = false

# Animation state
var animation_state_machine: AnimationNodeStateMachinePlayback
var current_animation: String = ""

# Nodes
@onready var character_body: CharacterBody3D = $CharacterBody3D
@onready var collision_shape: CollisionShape3D = $CharacterBody3D/CollisionShape3D
@onready var mesh_container: Node3D = $CharacterBody3D/MeshContainer
@onready var car_mesh: Node3D = $CharacterBody3D/MeshContainer/CarMesh
@onready var robot_mesh: Node3D = $CharacterBody3D/MeshContainer/RobotMesh
@onready var camera_pivot: Node3D = $CharacterBody3D/CameraPivot
@onready var camera: Camera3D = $CharacterBody3D/CameraPivot/Camera
@onready var ray_cast: RayCast3D = $CharacterBody3D/RayCast3D
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var transform_timer: Timer = $TransformTimer
@onready var jet_particles: GPUParticles3D = $CharacterBody3D/MeshContainer/RobotMesh/JetParticles
@onready var muzzle_flash: GPUParticles3D = $CharacterBody3D/MeshContainer/RobotMesh/MuzzleFlash
@onready var animation_player: AnimationPlayer = $CharacterBody3D/AnimationPlayer

# Audio
@onready var jump_sound: AudioStreamPlayer3D = $CharacterBody3D/JumpSound
@onready var double_jump_sound: AudioStreamPlayer3D = $CharacterBody3D/DoubleJumpSound
@onready var transform_sound: AudioStreamPlayer3D = $CharacterBody3D/TransformSound
@onready var shoot_sound: AudioStreamPlayer3D = $CharacterBody3D/ShootSound
@onready var melee_sound: AudioStreamPlayer3D = $CharacterBody3D/MeleeSound

func _ready() -> void:
    current_health = max_health
    character_body.gravity_scale = 1.0
    
    # Initialize animations
    if animation_player.has_animation("idle_robot"):
        animation_player.play("idle_robot")
    
    # Setup input
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    if is_transforming:
        return
    
    handle_movement(delta)
    handle_camera()
    handle_attacks()
    
    # Apply gravity
    if not character_body.is_on_floor():
        velocity.y -= character_body.gravity * character_body.gravity_scale * delta
    
    character_body.velocity = velocity
    character_body.move_and_slide()
    
    # Check if on floor
    can_jump = character_body.is_on_floor()
    if can_jump:
        jump_count = 0

func handle_movement(delta: float) -> void:
    var input_dir := Vector3.ZERO
    
    # Get camera-relative input
    var camera_basis = camera_pivot.global_transform.basis
    var forward = -camera_basis.z.normalized()
    var right = camera_basis.x.normalized()
    
    if Input.is_action_pressed("move_forward"):
        input_dir += forward
    if Input.is_action_pressed("move_backward"):
        input_dir -= forward
    if Input.is_action_pressed("move_left"):
        input_dir -= right
    if Input.is_action_pressed("move_right"):
        input_dir += right
    
    # Normalize input
    if input_dir.length() > 1.0:
        input_dir = input_dir.normalized()
    
    # Determine speed based on form and sprint
    var base_speed = car_speed if not is_robot_form else robot_speed
    is_sprinting = Input.is_action_pressed("sprint") and is_robot_form
    var current_speed = base_speed * (sprint_multiplier if is_sprinting else 1.0)
    
    # Apply movement
    if input_dir.length() > 0.1:
        # Smooth rotation towards movement direction
        var target_rotation = atan2(input_dir.x, input_dir.z)
        var current_rotation = character_body.rotation.y
        var rotation_diff = wrapf(target_rotation - current_rotation, -PI, PI)
        character_body.rotation.y += rotation_diff * rotation_speed * delta
        
        # Move
        var move_velocity = input_dir * current_speed
        if character_body.is_on_floor() or not is_robot_form:
            velocity.x = lerp(velocity.x, move_velocity.x, 10.0 * delta)
            velocity.z = lerp(velocity.z, move_velocity.z, 10.0 * delta)
        else:
            # Air control
            velocity.x = lerp(velocity.x, move_velocity.x, air_control * 10.0 * delta)
            velocity.z = lerp(velocity.z, move_velocity.z, air_control * 10.0 * delta)
    
    # Jump handling
    if Input.is_action_just_pressed("jump"):
        if can_jump:
            # First jump
            velocity.y = jump_force
            jump_count = 1
            play_jump_animation(false)
            if jump_sound:
                jump_sound.play()
        elif jump_count == 1 and is_robot_form:
            # Double jump (robot only)
            velocity.y = jump_force * 0.8
            jump_count = 2
            play_jump_animation(true)
            if double_jump_sound:
                double_jump_sound.play()
            # Activate jet particles
            if jet_particles:
                jet_particles.emitting = true
                await get_tree().create_timer(0.5).timeout
                jet_particles.emitting = false

func handle_camera() -> void:
    # Mouse look for camera
    var mouse_sensitivity: float = 0.002
    var rot_x = -Input.get_mouse_relative().y * mouse_sensitivity
    var rot_y = -Input.get_mouse_relative().x * mouse_sensitivity
    
    camera_pivot.rotate_x(rot_x)
    camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-60), deg_to_rad(60))
    
    character_body.rotate_y(rot_y)

func handle_attacks() -> void:
    if not is_robot_form or is_attacking:
        return
    
    var current_time = Time.get_ticks_msec() / 1000.0
    
    # Primary attack (melee - LMB)
    if Input.is_action_just_pressed("attack_primary") and can_attack:
        perform_melee_attack()
    
    # Secondary attack (ranged - RMB)
    if Input.is_action_pressed("attack_secondary") and can_attack:
        if current_time - last_fire_time >= fire_rate:
            perform_ranged_attack()
            last_fire_time = current_time

func perform_melee_attack() -> void:
    is_attacking = true
    can_attack = false
    
    # Play melee animation
    if animation_player.has_animation("attack_melee"):
        animation_player.play("attack_melee")
    
    if melee_sound:
        melee_sound.play()
    
    # Check for hits
    await get_tree().create_timer(0.2).timeout
    
    var space_state = character_body.get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        character_body.global_position,
        character_body.global_position + character_body.global_transform.basis * Vector3(0, 0, -melee_range),
        [character_body.collision_layer]
    )
    query.exclude = [character_body.get_instance_id()]
    
    var result = space_state.intersect_ray(query)
    if result and result.collider:
        if result.collider.is_in_group("enemies"):
            # Apply damage and knockback
            var enemy = result.collider
            if enemy.has_method("take_damage"):
                enemy.take_damage(melee_damage)
            
            # Knockback effect
            var knockback_dir = (enemy.global_position - character_body.global_position).normalized()
            knockback_dir.y = 0.5
            if enemy is RigidBody3D or enemy.has_method("apply_knockback"):
                enemy.apply_knockback(knockback_dir * 20.0)
    
    await get_tree().create_timer(0.5).timeout
    is_attacking = false
    can_attack = true

func perform_ranged_attack() -> void:
    # Play shoot animation
    if animation_player.has_animation("attack_shoot"):
        animation_player.play("attack_shoot")
    
    if shoot_sound:
        shoot_sound.play()
    
    # Spawn projectile
    var projectile_scene = preload("res://scenes/Projectile.tscn")
    if projectile_scene:
        var projectile = projectile_scene.instantiate()
        get_parent().add_child(projectile)
        
        # Position at muzzle
        var muzzle_pos = muzzle_flash.global_position if muzzle_flash else character_body.global_position
        projectile.global_transform = Transform3D(Basis(), muzzle_pos)
        
        # Set direction
        var direction = -character_body.global_transform.basis.z
        projectile.set_direction(direction, ranged_damage, projectile_speed)
    
    # Muzzle flash
    if muzzle_flash:
        muzzle_flash.emitting = true
        await get_tree().create_timer(0.1).timeout
        muzzle_flash.emitting = false

func transform_form() -> void:
    if is_transforming:
        return
    
    is_transforming = true
    
    if transform_sound:
        transform_sound.play()
    
    # Play transformation animation
    if is_robot_form:
        # Robot to Car
        if animation_player.has_animation("transform_to_car"):
            animation_player.play("transform_to_car")
        car_mesh.visible = true
        robot_mesh.visible = false
        # Shrink collision
        collision_shape.shape.size = Vector3(2.0, 1.0, 4.0)
    else:
        # Car to Robot
        if animation_player.has_animation("transform_to_robot"):
            animation_player.play("transform_to_robot")
        robot_mesh.visible = true
        car_mesh.visible = false
        # Expand collision
        collision_shape.shape.size = Vector3(1.5, 3.0, 1.5)
    
    await get_tree().create_timer(1.0).timeout
    is_robot_form = !is_robot_form
    is_transforming = false
    
    emit_signal("form_changed", is_robot_form)

func take_damage(amount: int) -> void:
    current_health = max(0, current_health - amount)
    emit_signal("health_changed", current_health)
    
    if current_health <= 0:
        die()

func die() -> void:
    # Death animation/logic
    queue_free()

func play_jump_animation(is_double: bool) -> void:
    if is_double:
        if animation_player.has_animation("jump_double"):
            animation_player.play("jump_double")
    else:
        if animation_player.has_animation("jump"):
            animation_player.play("jump")

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("transform"):
        transform_form()
    
    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
