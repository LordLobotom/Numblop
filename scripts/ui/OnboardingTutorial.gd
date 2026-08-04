class_name OnboardingTutorial
extends Control

## The one-time guided finger that walks a new child through the whole loop once.
##
## Every step names a control to point at and a condition that ends it. Nothing here blocks
## input: the overlay ignores the mouse, so a child who ignores the finger just plays the
## game, and the finger waits on the control it is pointing at rather than on a timer.
##
## Steps end on state the app already publishes -- a started session, a correct answer, a
## visible screen, an owned hat -- so a rebuilt grid, a reordered scene or an interrupted
## round cannot leave the sequence pointing at a stale node. The finger simply hides
## whenever its target is not on screen, which is what covers the long gaps: the eight
## questions between the first answer and the chest, and the whole second round.

## Drawn size of the finger and where its drawn tip sits inside that square.
const FINGER_SIZE := Vector2(96.0, 96.0)
const FINGER_TIP := Vector2(0.14, 0.78)
## The tip hovers this far above the target and bobs by this much, this fast.
const HOVER_GAP := 6.0
const BOB_DISTANCE := 9.0
const BOB_SPEED := 3.4
## Kept off the display edge so the hand never reads as half cut off.
const SCREEN_PADDING := 4.0

@onready var _finger: TextureRect = $Finger
@onready var _main: Control = get_parent()
@onready var _home: HomeScreen = _main.get_node("HomeScreen")
@onready var _map: MapScreen = _main.get_node("MapScreen")
@onready var _cosmetics: CosmeticsScreen = _main.get_node("CosmeticsScreen")
@onready var _practice: PracticeScreen = _main.get_node("PracticeScreen")
@onready var _reward: RewardScreen = _main.get_node("RewardScreen")

var _steps: Array[Dictionary] = []
var _step_index := 0
var _elapsed := 0.0
## The hat the shop steps point at. Latched once so buying it does not move the finger on
## to the next unowned hat mid-step.
var _target_hat_id := ""

# Counted since the current step began, then cleared by _enter_step.
var _sessions_started := 0
var _correct_answers := 0
var _chests_opened := 0
var _rounds_completed := 0


func _ready() -> void:
    _finger.visible = false
    _steps = _build_steps()
    if AppState.onboarding.completed:
        set_process(false)
        return
    _step_index = clampi(AppState.onboarding.step, 0, _steps.size() - 1)
    EventBus.session_started.connect(_on_session_started)
    EventBus.answer_recorded.connect(_on_answer_recorded)
    EventBus.reward_applied.connect(_on_reward_applied)
    _reward.chest_button.pressed.connect(_on_chest_pressed)
    _enter_step()


func _process(delta: float) -> void:
    _elapsed += delta
    while _step_index < _steps.size() and _current_step_done():
        _step_index += 1
        if _step_index >= _steps.size():
            _finish()
            return
        _enter_step()
    _update_finger()


## The guided sequence, in order. `target` resolves the control to point at, `done` reports
## whether the child has performed that step's action.
func _build_steps() -> Array[Dictionary]:
    return [
        {
            "id": &"play",
            "target": _target_play_button,
            "done": func() -> bool: return _sessions_started > 0,
        },
        {
            "id": &"correct_answer",
            "target": _target_correct_answer,
            "done": func() -> bool: return _correct_answers > 0,
        },
        {
            "id": &"chest",
            "target": _target_chest,
            "done": func() -> bool: return _chests_opened > 0,
        },
        {
            "id": &"cosmetics",
            "target": _target_outfit_nav,
            "done": func() -> bool: return _cosmetics.visible,
        },
        {
            "id": &"hats_tab",
            "target": _target_hats_tab,
            "done": func() -> bool: return _cosmetics.hats_page.visible,
        },
        {
            "id": &"first_hat",
            "target": _target_first_hat,
            "done": _is_target_hat_previewed,
        },
        {
            "id": &"buy",
            "target": _target_purchase_button,
            "done": _is_target_hat_settled,
        },
        {
            "id": &"home",
            "target": _target_home_nav,
            "done": func() -> bool: return _home.visible,
        },
        {
            "id": &"play_again",
            "target": _target_play_button,
            # A round, not a tap: the finger returns to Play if the child leaves one early.
            "done": func() -> bool: return _rounds_completed > 0,
        },
        {
            "id": &"map",
            "target": _target_map_nav,
            "done": func() -> bool: return _map.visible,
        },
        {
            "id": &"island",
            "target": _target_island,
            "done": func() -> bool: return _map.fact_detail_overlay.visible,
        },
    ]


func step_id() -> StringName:
    if _step_index >= _steps.size():
        return &""
    return _steps[_step_index]["id"]


func _enter_step() -> void:
    _sessions_started = 0
    _correct_answers = 0
    _chests_opened = 0
    _rounds_completed = 0
    AppState.record_onboarding_step(_step_index)


func _finish() -> void:
    _finger.visible = false
    set_process(false)
    AppState.complete_onboarding()


func _current_step_done() -> bool:
    var is_done: Callable = _steps[_step_index]["done"]
    return bool(is_done.call())


func _current_target() -> Control:
    var resolve_target: Callable = _steps[_step_index]["target"]
    return resolve_target.call() as Control


func _update_finger() -> void:
    var target := _current_target()
    if target == null or not target.is_visible_in_tree() or target.size == Vector2.ZERO:
        _finger.visible = false
        return
    # The opening overlay draws below this node, so the finger would sit on top of it.
    if _main.has_node("OpeningScreen"):
        _finger.visible = false
        return

    var target_rect := target.get_global_rect()
    var bob := (sin(_elapsed * BOB_SPEED) * 0.5 + 0.5) * BOB_DISTANCE
    var tip := Vector2(
        target_rect.get_center().x,
        target_rect.position.y - HOVER_GAP - bob
    )
    var limit := get_viewport_rect().size - FINGER_SIZE - Vector2.ONE * SCREEN_PADDING
    _finger.size = FINGER_SIZE
    _finger.global_position = (tip - FINGER_TIP * FINGER_SIZE).clamp(
        Vector2.ONE * SCREEN_PADDING,
        limit.max(Vector2.ONE * SCREEN_PADDING)
    )
    _finger.visible = true


func _target_play_button() -> Control:
    return _home.play_button


func _target_correct_answer() -> Control:
    return _practice.correct_answer_control()


func _target_chest() -> Control:
    return _reward.chest_button


func _target_outfit_nav() -> Control:
    return _home.navigation.get_node("%OutfitButton")


func _target_home_nav() -> Control:
    return _cosmetics.navigation.get_node("%HomeButton")


func _target_map_nav() -> Control:
    return _home.navigation.get_node("%MapButton")


func _target_hats_tab() -> Control:
    return _cosmetics.hats_tab


func _target_purchase_button() -> Control:
    return _cosmetics.purchase_button


func _target_first_hat() -> Control:
    _latch_target_hat()
    if _target_hat_id.is_empty():
        return null
    return _cosmetics.item_card(CosmeticCatalog.CATEGORY_HAT, _target_hat_id)


func _target_island() -> Control:
    for stage_state in AppState.map_stage_states():
        if bool(stage_state.get("unlocked", false)):
            return _map.stage_button(int(stage_state.get("table", 0)))
    return null


## The first hat the child does not own yet; `hat_none` is theirs from the start, so the
## finger never points at the empty slot they are already wearing.
func _latch_target_hat() -> void:
    if not _target_hat_id.is_empty():
        return
    for item in CosmeticCatalog.items(CosmeticCatalog.CATEGORY_HAT):
        var item_id := String(item["id"])
        if not AppState.cosmetics.owns_item(CosmeticCatalog.CATEGORY_HAT, item_id):
            _target_hat_id = item_id
            return


func _is_target_hat_previewed() -> bool:
    _latch_target_hat()
    if _target_hat_id.is_empty():
        return true
    var previewed := _cosmetics.previewed_item()
    return (
        String(previewed["category"]) == CosmeticCatalog.CATEGORY_HAT
        and String(previewed["id"]) == _target_hat_id
    )


## Ends the buy step once the hat is bought -- or once it cannot be bought at all, so a
## child who spent their coins elsewhere is never left with a finger on a dead button.
func _is_target_hat_settled() -> bool:
    _latch_target_hat()
    if _target_hat_id.is_empty():
        return true
    if AppState.cosmetics.owns_item(CosmeticCatalog.CATEGORY_HAT, _target_hat_id):
        return true
    var item := CosmeticCatalog.item(CosmeticCatalog.CATEGORY_HAT, _target_hat_id)
    return AppState.progress.coins < int(item.get("price", 0))


func _on_session_started(_question_count: int) -> void:
    _sessions_started += 1


func _on_answer_recorded(_fact_key: String, correct: bool, _mastery: int) -> void:
    if correct:
        _correct_answers += 1


func _on_reward_applied(_coins: int, _experience: int) -> void:
    _rounds_completed += 1


func _on_chest_pressed() -> void:
    _chests_opened += 1
