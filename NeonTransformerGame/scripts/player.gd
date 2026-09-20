extends CharacterBody3D

@export var car_speed: float = 15.0
@export var robot_speed: float = 8.0
@export var sprint_multiplier: float = 1.8
@export var jump_force: float = 12.0
@export var rotation_speed: float = 10.0
@export var transform_duration: float = 1.5

enum Form { CAR, ROBOT }
var current_form: Form = Form.CAR
var is_transforming: bool = false
var can_double_jump: bool = false
var jump_count: int = 0
var health: float = 100.0
var max_health: float = 100.0
var is_attacking: bool = false
var attack_timer: Timer = null

@onready var car_mesh: MeshInstance3D = $CarForm/CarMesh
@onready var robot_mesh: MeshInstance3D = $RobotForm/RobotMesh
@onready var car_collision: CollisionShape3D = $CarForm/CarCollision
@onready var robot_collision: CollisionShape3D = $RobotForm/RobotCollision
@onready var engine_particles: GPUParticles3D = $RobotForm/EngineParticles
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera_pivot: Node3D = $CameraPivot
@onready var ray_cast: RayCast3D = $RayCast3D

var target_rotation: float = 0.0
var velocity_input: Vector2 = Vector2.ZERO

signal form_changed(new_form: Form)
signal health_changed(new_health: float)
signal attacked(attack_type: String)

func _ready() -> void:
    set_form_visibility()
    engine_particles.emitting = false
    
    attack_timer = Timer.new()
    attack_timer.wait_time = 0.5
    attack_timer.one_shot = true
    attack_timer.timeout.connect(_on_attack_timer_timeout)
    add_child(attack_timer)

func _physics_process(delta: float) -> void:
    if is_transforming:
        return
    
    handle_input(delta)
    apply_movement(delta)
    apply_gravity_and_jump(delta)
    update_camera()
    
    if global_position.y < -10:
        take_damage(20.0)
        global_position.y = 5.0
        velocity.y = 0

func handle_input(delta: float) -> void:
    var forward = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
    var right = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    velocity_input = Vector2(right, forward).normalized()
    
    if velocity_input.length() > 0.1:
        target_rotation = atan2(-velocity_input.x, -velocity_input.y)
    
    if Input.is_action_just_pressed("transform") and not is_transforming:
        transform_form()
    
    if Input.is_action_just_pressed("jump"):
        perform_jump()
    
    if current_form == Form.ROBOT:
        handle_robot_actions()

func handle_robot_actions() -> void:
    if Input.is_action_just_pressed("attack_primary") and not is_attacking:
        perform_melee_attack()
    
    if Input.is_action_pressed("attack_secondary") and not is_attacking:
        perform_ranged_attack()

func perform_jump() -> void:
    if is_on_floor():
        velocity.y = jump_force
        jump_count = 1
        can_double_jump = true
        engine_particles.emitting = false
    elif jump_count == 1 and can_double_jump:
        velocity.y = jump_force * 1.2
        jump_count = 2
        can_double_jump = false
        engine_particles.emitting = true
        engine_particles.restart()

func apply_movement(delta: float) -> void:
    var speed = car_speed if current_form == Form.CAR else robot_speed
    
    if Input.is_action_pressed("sprint"):
        speed *= sprint_multiplier
    
    if velocity_input.length() > 0.1:
        var move_dir = transform.basis * Vector3(-velocity_input.x, 0, -velocity_input.y)
        velocity.x = move_dir.x * speed
        velocity.z = move_dir.z * speed
        
        var current_rot = rotation.y
        var diff = wrapf(target_rotation - current_rot, -PI, PI)
        rotation.y = lerp_angle(current_rot, current_rot + diff, delta * rotation_speed)
    else:
        velocity.x = lerp(velocity.x, 0, delta * 5.0)
        velocity.z = lerp(velocity.z, 0, delta * 5.0)

func apply_gravity_and_jump(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= 25.0 * delta

func update_camera() -> void:
    var target_pos = global_position + Vector3(0, 8, 12)
    camera_pivot.global_position = lerp(camera_pivot.global_position, target_pos, 0.1)

func transform_form() -> void:
    if is_transforming:
        return
    
    is_transforming = true
    
    var tween = create_tween()
    tween.set_parallel(true)
    
    if current_form == Form.CAR:
        current_form = Form.ROBOT
        tween.tween_property(car_mesh, "scale", Vector3.ZERO, transform_duration * 0.5)
        tween.tween_property(robot_mesh, "scale", Vector3.ONE, transform_duration * 0.5).set_delay(transform_duration * 0.3)
        
        var rotate_tween = create_tween()
        rotate_tween.tween_property(robot_mesh, "rotation:y", PI, transform_duration * 0.3).set_delay(transform_duration * 0.2)
        rotate_tween.tween_property(robot_mesh, "rotation:y", 0, transform_duration * 0.2).set_delay(transform_duration * 0.5)
    else:
        current_form = Form.CAR
        tween.tween_property(robot_mesh, "scale", Vector3.ZERO, transform_duration * 0.5)
        tween.tween_property(car_mesh, "scale", Vector3.ONE, transform_duration * 0.5).set_delay(transform_duration * 0.3)
    
    tween.tween_callback(func(): 
        is_transforming = false
        set_form_visibility()
        form_changed.emit(current_form)
    )

func set_form_visibility() -> void:
    car_mesh.visible = (current_form == Form.CAR)
    robot_mesh.visible = (current_form == Form.ROBOT)
    car_collision.disabled = (current_form != Form.CAR)
    robot_collision.disabled = (current_form != Form.ROBOT)

func perform_melee_attack() -> void:
    if current_form != Form.ROBOT:
        return
    
    is_attacking = true
    attacked.emit("melee")
    
    var tween = create_tween()
    tween.tween_property(robot_mesh, "position:y", 0.5, 0.15)
    tween.tween_property(robot_mesh, "position:y", 0, 0.15)
    
    await get_tree().create_timer(0.3).timeout
    is_attacking = false

func perform_ranged_attack() -> void:
    if current_form != Form.ROBOT or attack_timer.time_left > 0:
        return
    
    attacked.emit("ranged")
    attack_timer.start()
    
    var projectile = preload("res://scenes/Projectile.tscn").instantiate()
    var spawn_pos = global_position + transform.basis * Vector3(0, 1, 2)
    projectile.global_position = spawn_pos
    projectile.direction = -transform.basis.z
    get_tree().current_scene.add_child(projectile)

func take_damage(amount: float) -> void:
    health = max(0, health - amount)
    health_changed.emit(health)
    
    if health <= 0:
        die()

func die() -> void:
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector3.ZERO, 1.0)
    tween.tween_callback(queue_free)

func _on_attack_timer_timeout() -> void:
    pass
