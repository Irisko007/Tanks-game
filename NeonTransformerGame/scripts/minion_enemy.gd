extends CharacterBody3D

@export var move_speed: float = 5.0
@export var damage: float = 10.0
@export var health: float = 20.0
@export var detection_range: float = 15.0

var player: Node3D = null
var is_active: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var detection_area: Area3D = $DetectionArea

func _ready() -> void:
    add_to_group("minions")
    add_to_group("enemies")
    detection_area.body_entered.connect(_on_detection_body_entered)
    detection_area.body_exited.connect(_on_detection_body_exited)

func _physics_process(delta: float) -> void:
    if health <= 0:
        return
    
    if player and is_active:
        chase_player(delta)
    
    apply_gravity(delta)
    
    if global_position.y < -10:
        queue_free()

func chase_player(delta: float) -> void:
    var direction = (player.global_position - global_position).normalized()
    direction.y = 0
    velocity.x = direction.x * move_speed
    velocity.z = direction.z * move_speed
    look_at(player.global_position)
    move_and_slide()

func apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= 15.0 * delta

func take_damage(amount: float) -> void:
    health -= amount
    
    var flash_tween = create_tween()
    flash_tween.tween_property(mesh, "modulate", Color(2, 0, 0, 1), 0.05)
    flash_tween.tween_property(mesh, "modulate", Color(1, 1, 1, 1), 0.1)
    
    if health <= 0:
        die()

func die() -> void:
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
    tween.tween_callback(queue_free)

func _on_detection_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        player = body
        is_active = true

func _on_detection_body_exited(body: Node3D) -> void:
    if body == player:
        player = null
        is_active = false
