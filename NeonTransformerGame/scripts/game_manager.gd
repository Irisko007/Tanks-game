extends Node

class_name GameManager

signal game_started
signal game_over
signal menu_requested

enum GameState { MENU, LOADING, PLAYING, GAME_OVER }

var current_state: GameState = GameState.MENU
var player_health: int = 100
var boss_defeated: bool = false
var enemies_defeated: int = 0

@onready var loading_screen: Control = $LoadingScreen
@onready var main_menu: Control = $MainMenu
@onready var hud: Control = $HUD
@onready var game_over_screen: Control = $GameOverScreen

func _ready() -> void:
    # Start with menu
    show_menu()
    
    # Connect signals if nodes exist
    if loading_screen:
        loading_screen.visible = false
    if main_menu:
        main_menu.visible = true
    if hud:
        hud.visible = false
    if game_over_screen:
        game_over_screen.visible = false

func show_loading_screen() -> void:
    current_state = GameState.LOADING
    if loading_screen:
        loading_screen.visible = true
    if main_menu:
        main_menu.visible = false
    
    # Simulate loading
    await get_tree().create_timer(2.0).timeout
    
    start_game()

func show_menu() -> void:
    current_state = GameState.MENU
    if main_menu:
        main_menu.visible = true
    if loading_screen:
        loading_screen.visible = false
    if hud:
        hud.visible = false
    if game_over_screen:
        game_over_screen.visible = false
    
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func start_game() -> void:
    current_state = GameState.PLAYING
    if loading_screen:
        loading_screen.visible = false
    if hud:
        hud.visible = true
    
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    
    emit_signal("game_started")

func end_game(victory: bool = false) -> void:
    current_state = GameState.GAME_OVER
    if hud:
        hud.visible = false
    if game_over_screen:
        game_over_screen.visible = true
        
        # Update game over text
        var label = game_over_screen.get_node_or_null("VictoryLabel")
        if label:
            label.text = "VICTORY!" if victory else "GAME OVER"
        
        var subtitle = game_over_screen.get_node_or_null("SubtitleLabel")
        if subtitle:
            subtitle.text = "The boss has been defeated!" if victory else "Try again!"
    
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    emit_signal("game_over")

func restart_game() -> void:
    # Reload current scene
    get_tree().reload_current_scene()

func quit_game() -> void:
    get_tree().quit()

func update_player_health(new_health: int) -> void:
    player_health = new_health
    if hud:
        var health_label = hud.get_node_or_null("HealthLabel")
        if health_label:
            health_label.text = "HP: %d / 100" % player_health

func update_boss_health(new_health: int, max_health: int) -> void:
    if hud:
        var boss_health_label = hud.get_node_or_null("BossHealthLabel")
        if boss_health_label:
            boss_health_label.text = "BOSS: %d / %d" % [new_health, max_health]
