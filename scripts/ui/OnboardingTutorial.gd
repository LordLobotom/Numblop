class_name OnboardingTutorial
extends Control

## The one-time guided finger that walks a new child through the whole loop once.
##
## Every step names a control to point at and a condition that ends it. Nothing here blocks
## input: the overlay ignores the mouse, so a child who ignores the finger just plays the
## game, and the finger waits on the control it is pointing at rather than on a timer.
##
## Steps end on state the app already publishes -- a started session, a correct answer, a
## visible screen, a bought item -- so a rebuilt grid, a reordered scene or an interrupted
## round cannot leave the sequence pointing at a stale node. The finger simply hides
## whenever its target is not on screen, which is what covers the long gaps: the eight
## questions between the first answer and the chest, and the whole second round.
##
## The tutorial also yields to the save underneath it. A restore can arrive at any moment on a
## fresh install or a second device, and the profile it brings may already have been onboarded,
## so the overlay re-reads `AppState` whenever the profile is reloaded instead of trusting the
## state it happened to read at boot.

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
## True while a remote save could still replace this profile. Nobody here knows who is restoring
## it; the bus carries the fact alone.
var _restore_pending := false

# Counted since the current step began, then cleared by _enter_step.
var _sessions_started := 0
var _correct_answers := 0
var _chests_opened := 0
var _rounds_completed := 0
var _paid_items_at_step_start := 0


func _ready() -> void:
    _finger.visible = false
    _steps = _build_steps()
    # Connected even for a finished tutorial, so this node has exactly one rule about a reloaded
    # profile rather than two that can drift apart.
    EventBus.profile_reloaded.connect(_on_profile_reloaded)
    EventBus.external_restore_pending.connect(_on_external_restore_pending)
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
            "id": &"buy",
            "target": _target_purchase_button,
            # Showing the shop is the whole point of this step. Nothing has to be bought, so a
            # child who just looks around and leaves has done it correctly.
            "done": _is_shop_visit_settled,
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
    _paid_items_at_step_start = _owned_paid_count()
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
    if _is_waiting_for_restore():
        _finger.visible = false
        return
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


## Whether to hold the finger back because a restore may still cancel the tutorial outright.
##
## Only while the profile is genuinely untouched: nothing played, nothing tapped. Once the child
## has started, they are already being taught and a late restore stops the sequence on its own.
## Offline no restore is ever in flight, so this is never true and the finger appears at once.
static func waits_for_restore(
    restore_pending: bool,
    step_index: int,
    completed_sessions: int
) -> bool:
    return restore_pending and step_index == 0 and completed_sessions == 0


## Where the sequence stands after a profile reload, or `-1` once the restored save says the
## tutorial is over.
##
## Never rewinds: the merge already takes the further of the two devices' steps, and a child in
## the middle of a step must not be walked back to a control they have already used.
static func restored_step_index(
    step_index: int,
    saved_step: int,
    completed: bool,
    step_count: int
) -> int:
    if completed:
        return -1
    return clampi(maxi(step_index, saved_step), 0, maxi(0, step_count - 1))


func _is_waiting_for_restore() -> bool:
    return waits_for_restore(
        _restore_pending,
        _step_index,
        AppState.progress.completed_sessions
    )


## A reloaded profile replaces everything this node read at boot, including whether the child has
## already been onboarded on another device.
func _on_profile_reloaded() -> void:
    var restored_index := restored_step_index(
        _step_index,
        AppState.onboarding.step,
        AppState.onboarding.completed,
        _steps.size()
    )
    if restored_index < 0:
        _finish()
        return
    if not is_processing() or restored_index == _step_index:
        return
    _step_index = restored_index
    _enter_step()


func _on_external_restore_pending(pending: bool) -> void:
    _restore_pending = pending


func _target_play_button() -> Control:
    return _home.play_button


func _target_correct_answer() -> Control:
    return _practice.correct_answer_control()


func _target_chest() -> Control:
    return _reward.chest_button


func _target_outfit_nav() -> Control:
    return _home.navigation.get_node("%OutfitButton")


## The Home button of whichever screen is actually up.
##
## Every screen carries the same shared nav bar, and a child can leave the shop by any of its
## buttons. Pinning this to the shop's own copy would strand the finger off screen on a child who
## wandered to the map instead.
func _target_home_nav() -> Control:
    if _map.visible:
        return _map.navigation.get_node("%HomeButton")
    return _cosmetics.navigation.get_node("%HomeButton")


func _target_map_nav() -> Control:
    return _home.navigation.get_node("%MapButton")


func _target_purchase_button() -> Control:
    return _cosmetics.purchase_button


func _target_island() -> Control:
    for stage_state in AppState.map_stage_states():
        if bool(stage_state.get("unlocked", false)):
            return _map.stage_button(int(stage_state.get("table", 0)))
    return null


## Ends the shop step once the child has bought something or left the shop again.
##
## Affordability is deliberately not an exit. Everything costs more than a first round pays, so a
## price check here would end the step on the frame it began and the Buy button would never be
## pointed at -- which is the one thing this step exists to do. The child is shown where buying
## happens; whether they buy is theirs to decide, and leaving is always allowed.
func _is_shop_visit_settled() -> bool:
    if not _cosmetics.visible:
        return true
    return _owned_paid_count() > _paid_items_at_step_start


## How many paid items the profile owns. Free defaults never count, so a fresh profile starts at
## zero and any purchase in any category moves this.
func _owned_paid_count() -> int:
    var owned := 0
    for category in CosmeticCatalog.CATEGORIES:
        for item in CosmeticCatalog.items(category):
            if int(item["price"]) > 0 \
                    and AppState.cosmetics.owns_item(category, String(item["id"])):
                owned += 1
    return owned


func _on_session_started(_question_count: int) -> void:
    _sessions_started += 1


func _on_answer_recorded(_fact_key: String, correct: bool, _mastery: int) -> void:
    if correct:
        _correct_answers += 1


func _on_reward_applied(_coins: int, _experience: int) -> void:
    _rounds_completed += 1


func _on_chest_pressed() -> void:
    _chests_opened += 1
