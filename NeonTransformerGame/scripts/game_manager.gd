extends Node

@export var player_scene: PackedScene
@export var boss_scene: PackedScene
@export var minion_scene: PackedScene

var player: Node3D = null
var boss: Node3D = null
var game_state: String = "loading"

@onready var loading_screen: Control = $LoadingScreen
@onready var main_menu: Control = $MainMenu
@onready var game_ui: Control = $GameUI
@onready var health_bar: ProgressBar = $GameUI/HealthBar
@onready var form_label: Label = $GameUI/FormLabel
@onready var pause_menu: Control = $PauseMenu

func _ready() -> void:
    game_state = "loading"
    show_loading_screen()
    
    await get_tree().create_timer(2.0).timeout
    
    show_main_menu()

func show_loading_screen() -> void:
    if loading_screen:
        loading_screen.visible = true
    if main_menu:
        main_menu.visible = false
    if game_ui:
        game_ui.visible = false

func show_main_menu() -> void:
    if loading_screen:
        loading_screen.visible = false
    if main_menu:
        main_menu.visible = true
    if game_ui:
        game_ui.visible = false
    game_state = "menu"

func start_game() -> void:
    if main_menu:
        main_menu.visible = false
    if game_ui:
        game_ui.visible = true
    
    spawn_player()
    spawn_boss()
    
    game_state = "playing"

func spawn_player() -> void:
    if player and is_instance_valid(player):
        player.queue_free()
    
    if player_scene:
        player = player_scene.instantiate()
        player.add_to_group("player")
        
        var spawn_point = get_node_or_null("SpawnPoints/PlayerSpawn")
        if spawn_point:
            player.global_position = spawn_point.global_position
        else:
            player.global_position = Vector3(0, 2, 0)
        
        add_child(player)
        
        player.health_changed.connect(_on_player_health_changed)
        player.form_changed.connect(_on_player_form_changed)
        update_ui()

func spawn_boss() -> void:
    if boss and is_instance_valid(boss):
        boss.queue_free()
    
    if boss_scene:
        boss = boss_scene.instantiate()
        
        var spawn_point = get_node_or_null("SpawnPoints/BossSpawn")
        if spawn_point:
            boss.global_position = spawn_point.global_position
        else:
            boss.global_position = Vector3(0, 2, -20)
        
        add_child(boss)

func spawn_minion(position: Vector3) -> void:
    if minion_scene:
        var minion = minion_scene.instantiate()
        minion.global_position = position
        add_child(minion)

func _on_player_health_changed(new_health: float) -> void:
    update_ui()
    
    if new_health <= 0:
        await get_tree().create_timer(2.0).timeout
        game_over()

func _on_player_form_changed(new_form: int) -> void:
    update_ui()

func update_ui() -> void:
    if not player or not is_instance_valid(player):
        return
    
    if health_bar:
        health_bar.value = player.health if player.has_node("health") else 100
        health_bar.max_value = player.max_health if player.has_node("max_health") else 100
    
    if form_label and player.has_signal("form_changed"):
        var form_name = "CAR" if player.current_form == 0 else "ROBOT"
        form_label.text = "Form: " + form_name

func game_over() -> void:
    game_state = "gameover"
    if game_ui:
        game_ui.visible = false
    if main_menu:
        main_menu.visible = true

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        if game_state == "playing":
            toggle_pause()
        elif game_state == "paused":
            toggle_pause()

func toggle_pause() -> void:
    if game_state == "playing":
        game_state = "paused"
        get_tree().paused = true
        if pause_menu:
            pause_menu.visible = true
    elif game_state == "paused":
        game_state = "playing"
        get_tree().paused = false
        if pause_menu:
            pause_menu.visible = false
