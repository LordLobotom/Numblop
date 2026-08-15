extends Node

var profile := LearningProfile.new()
var active_session: Array[PracticeQuestion] = []
var active_session_result: SessionResult
var session_controller: SessionController
var progress := LocalProgress.new()
var cosmetics := LocalCosmetics.new()
var streak := LocalStreak.new()
var achievements := LocalAchievements.new()
var onboarding := LocalOnboarding.new()

var _pending_answer_milestone: Dictionary = {}
var _session_bonus_coins := 0
var _pending_achievement_unlocks: Array[Dictionary] = []
var _achievements_loaded := false
var _nickname := ""


func _ready() -> void:
    _load_runtime_state()
    _adopt_pre_tutorial_save()
    _create_session_controller()
    _achievements_loaded = true
    # Older saves predate the achievement list; award everything they already earned once, but
    # without a celebration the player never triggered.
    sync_achievements()
    _pending_achievement_unlocks.clear()


func _load_runtime_state() -> void:
    profile = SaveManager.load_profile()
    progress = LocalProgress.new(SaveManager.load_progress())
    cosmetics = LocalCosmetics.new(SaveManager.load_cosmetics())
    streak = LocalStreak.new(SaveManager.load_streak())
    achievements = LocalAchievements.new(SaveManager.load_achievements())
    onboarding = LocalOnboarding.new(SaveManager.load_onboarding())
    _nickname = SaveManager.load_nickname()


## Rebuilds the in-memory models after a validated external save has reached disk.
##
## The method is provider-agnostic: it knows nothing about Play Games or networking. Keeping the
## reload here prevents an external merge from being overwritten by the stale models that were
## already running before the merge.
func reload_profile_from_disk() -> void:
    _interrupt_unfinished_session()
    _pending_answer_milestone.clear()
    _session_bonus_coins = 0
    _pending_achievement_unlocks.clear()
    _achievements_loaded = false
    _load_runtime_state()
    _adopt_pre_tutorial_save()
    _create_session_controller()
    _achievements_loaded = true
    sync_achievements()
    _pending_achievement_unlocks.clear()
    EventBus.progress_changed.emit(progress.coins, progress.experience, progress.level())
    EventBus.streak_changed.emit(streak.current_count, streak.all_time_high)
    EventBus.cosmetics_changed.emit(cosmetics_state())
    EventBus.nickname_changed.emit(_nickname)
    EventBus.profile_reloaded.emit()


## Treats a save from before the tutorial existed as already onboarded.
##
## Such a profile belongs to a child who has finished rounds and knows the game; walking
## them from the Play button on the next launch would teach nothing. The flag is only kept
## in memory here and lands on disk with the next ordinary save, so booting an old profile
## never writes to it.
func _adopt_pre_tutorial_save() -> void:
    if onboarding.completed or onboarding.step > 0:
        return
    if progress.completed_sessions > 0:
        onboarding.completed = true


func nickname() -> String:
    return _nickname


func onboarding_state() -> Dictionary:
    return onboarding.to_dictionary()


## Remembers which tutorial step is on screen so a restart resumes there.
func record_onboarding_step(step: int) -> bool:
    if onboarding.completed or onboarding.step == step:
        return true
    onboarding.step = maxi(0, step)
    return _save_game_state(profile, progress.coins, progress.experience) == OK


func complete_onboarding() -> bool:
    if onboarding.completed:
        return true
    onboarding.completed = true
    if _save_game_state(profile, progress.coins, progress.experience) == OK:
        return true
    # The tutorial is only really finished once that is on disk; otherwise it resumes.
    onboarding.completed = false
    return false


func set_nickname(raw_nickname: String) -> bool:
    var sanitized := LocalNickname.sanitize(raw_nickname)
    var save_error := SaveManager.save_game_state(
        profile,
        progress.coins,
        progress.experience,
        SaveManager.PROFILE_PATH,
        cosmetics.to_dictionary(),
        streak.to_dictionary(),
        sanitized,
        achievements.to_dictionary(),
        progress.completed_sessions,
        onboarding.to_dictionary(),
        progress.ledger()
    )
    if save_error != OK:
        return false
    _nickname = sanitized
    EventBus.nickname_changed.emit(_nickname)
    return true


func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_PAUSED:
            handle_application_paused()
        NOTIFICATION_APPLICATION_RESUMED:
            handle_application_resumed()
        NOTIFICATION_WM_GO_BACK_REQUEST:
            handle_go_back_request()


func begin_session(seed: int = -1) -> Array[PracticeQuestion]:
    var actual_seed := seed
    if actual_seed < 0:
        actual_seed = int(Time.get_ticks_usec() & 0x7FFFFFFF)
    _session_bonus_coins = 0
    active_session_result = session_controller.begin_session(actual_seed)
    active_session = active_session_result.questions.duplicate()
    return active_session


func submit_answer(
    submitted_answer: int,
    elapsed_seconds: float
) -> SessionResult.AnswerRecord:
    _pending_answer_milestone.clear()
    return session_controller.submit_answer(submitted_answer, elapsed_seconds)


func record_answer(question: PracticeQuestion, correct: bool, elapsed_seconds: float) -> int:
    assert(question == session_controller.current_question(), "Answers must be submitted in order")
    var submitted_answer := question.answer() if correct else question.answer() + 1
    var record := submit_answer(submitted_answer, elapsed_seconds)
    return record.mastery_delta


func abandon_session() -> void:
    var had_session := active_session_result != null
    _session_bonus_coins = 0
    session_controller.abandon_active_session()
    active_session_result = null
    active_session.clear()
    if had_session:
        EventBus.session_ended.emit()


func handle_application_paused() -> bool:
    var interrupted := _interrupt_unfinished_session()
    EventBus.application_paused.emit()
    return interrupted


func handle_application_resumed() -> void:
    EventBus.application_resumed.emit()


func handle_go_back_request() -> bool:
    if _interrupt_unfinished_session():
        return true
    EventBus.back_requested.emit()
    return false


func claim_completed_session_reward() -> Dictionary:
    var mastery_gains: Array[Dictionary] = (
        active_session_result.mastery_gains() if active_session_result != null else []
    )
    var reward := progress.apply_completed_session(
        active_session_result,
        profile,
        _save_game_state
    )
    if reward.is_empty():
        return {}
    reward["mastery_gains"] = mastery_gains
    EventBus.reward_applied.emit(int(reward["coins"]), int(reward["experience"]))
    EventBus.progress_changed.emit(progress.coins, progress.experience, progress.level())

    # The finished round can itself complete achievements, so evaluate before the chest opens
    # and hand every unlock to the one reward presentation.
    sync_achievements()
    var unlocks := consume_achievement_unlocks()
    var achievement_coins := 0
    for unlock in unlocks:
        achievement_coins += int(unlock.get("reward_coins", 0))
    reward["bonus_coins"] = _session_bonus_coins
    reward["achievements"] = unlocks
    reward["achievement_coins"] = achievement_coins
    reward["total_reward_coins"] = int(reward["coins"]) + _session_bonus_coins + achievement_coins

    _session_bonus_coins = 0
    session_controller.clear_completed_session()
    active_session_result = null
    active_session.clear()
    EventBus.session_ended.emit()
    return reward


func progress_totals() -> Dictionary:
    return progress.totals()


func consume_answer_milestone() -> Dictionary:
    var milestone := _pending_answer_milestone.duplicate(true)
    _pending_answer_milestone.clear()
    return milestone


func streak_state() -> Dictionary:
    return streak.to_dictionary()


func achievements_state() -> Dictionary:
    var entries: Array[Dictionary] = []
    for entry in AchievementCatalog.evaluate(profile, _achievement_statistics()):
        entry["granted"] = achievements.has_granted(String(entry["id"]))
        entries.append(entry)
    return {
        # The record the trophy screen shows rises during the run that sets it, rather than
        # waiting for the mistake that ends it.
        "best_streak": streak.best_count(),
        "achievements": entries,
    }


## Awards every newly completed achievement exactly once and returns the fresh unlocks.
func sync_achievements() -> Array[Dictionary]:
    # Grants write the live save, so never award anything before the real state is loaded.
    if not _achievements_loaded:
        return []
    var newly_unlocked: Array[Dictionary] = []
    var awarded_coins := 0
    for entry in AchievementCatalog.evaluate(profile, _achievement_statistics()):
        var achievement_id := String(entry["id"])
        if not bool(entry["completed"]) or achievements.has_granted(achievement_id):
            continue
        awarded_coins += achievements.grant(achievement_id)
        entry["granted"] = true
        newly_unlocked.append(entry)
    if newly_unlocked.is_empty():
        return []

    progress.grant_achievement_reward(awarded_coins)
    if _save_game_state(profile, progress.coins, progress.experience) != OK:
        # The award is only real once it is on disk; drop it and retry on the next evaluation.
        progress.coins -= awarded_coins
        for entry in newly_unlocked:
            achievements.granted.erase(String(entry["id"]))
        return []

    _pending_achievement_unlocks.append_array(newly_unlocked)
    EventBus.progress_changed.emit(progress.coins, progress.experience, progress.level())
    EventBus.achievements_unlocked.emit(newly_unlocked.duplicate(true))
    return newly_unlocked


func has_pending_achievement_unlocks() -> bool:
    return not _pending_achievement_unlocks.is_empty()


func consume_achievement_unlocks() -> Array[Dictionary]:
    var unlocks := _pending_achievement_unlocks.duplicate(true)
    _pending_achievement_unlocks.clear()
    return unlocks


func _achievement_statistics() -> Dictionary:
    return {
        "completed_sessions": progress.completed_sessions,
        # A streak counts the moment it is reached; it does not have to be ended by a mistake.
        "best_streak": streak.best_count(),
        # One experience point per correct answer, so this is the lifetime correct-answer count.
        "experience": progress.experience,
        "owned_cosmetics": _owned_paid_cosmetics(),
    }


## Purchased item count per cosmetic category. Free default items are never counted, so a fresh
## profile starts every collection at zero.
func _owned_paid_cosmetics() -> Dictionary:
    var owned: Dictionary = {}
    for category in AchievementCatalog.COLLECTION_TARGETS:
        var category_name := String(category)
        var count := 0
        for item in CosmeticCatalog.items(category_name):
            if int(item["price"]) > 0 and cosmetics.owns_item(category_name, String(item["id"])):
                count += 1
        owned[category_name] = count
    return owned


func cosmetics_state() -> Dictionary:
    return {
        "coins": progress.coins,
        "selected_body_color": cosmetics.selected_body_color,
        "selected_belly_color": cosmetics.selected_belly_color,
        "selected_hat": cosmetics.selected_hat,
        "selected_glasses": cosmetics.selected_glasses,
        "selected_necklace": cosmetics.selected_necklace,
        "selected_footwear": cosmetics.selected_footwear,
        "colors": _cosmetic_items_state(
            CosmeticCatalog.CATEGORY_BODY_COLOR,
            cosmetics.selected_body_color
        ),
        "belly_colors": _cosmetic_items_state(
            CosmeticCatalog.CATEGORY_BELLY_COLOR,
            cosmetics.selected_belly_color
        ),
        "hats": _cosmetic_items_state(
            CosmeticCatalog.CATEGORY_HAT,
            cosmetics.selected_hat
        ),
        "glasses": _cosmetic_items_state(
            CosmeticCatalog.CATEGORY_GLASSES,
            cosmetics.selected_glasses
        ),
        "necklaces": _cosmetic_items_state(
            CosmeticCatalog.CATEGORY_NECKLACE,
            cosmetics.selected_necklace
        ),
        "footwear": _cosmetic_items_state(
            CosmeticCatalog.CATEGORY_FOOTWEAR,
            cosmetics.selected_footwear
        ),
    }


func equip_body_color(color_id: String) -> bool:
    var updated_cosmetics := LocalCosmetics.new(cosmetics.to_dictionary())
    if not updated_cosmetics.equip_body_color(color_id):
        return false
    if _save_state_with_cosmetics(updated_cosmetics, progress.coins) != OK:
        return false
    cosmetics = updated_cosmetics
    _emit_cosmetics_changed()
    return true


func purchase_body_color(color_id: String) -> bool:
    return purchase_cosmetic(CosmeticCatalog.CATEGORY_BODY_COLOR, color_id)


func equip_cosmetic(category: String, item_id: String) -> bool:
    var updated_cosmetics := LocalCosmetics.new(cosmetics.to_dictionary())
    if not updated_cosmetics.equip_item(category, item_id):
        return false
    if _save_state_with_cosmetics(updated_cosmetics, progress.coins) != OK:
        return false
    cosmetics = updated_cosmetics
    _emit_cosmetics_changed()
    return true


func purchase_cosmetic(category: String, item_id: String) -> bool:
    var updated_cosmetics := LocalCosmetics.new(cosmetics.to_dictionary())
    var price := updated_cosmetics.purchase_and_equip_item(
        category,
        item_id,
        progress.coins
    )
    if price < 0:
        return false
    var updated_coins := progress.coins - price
    if _save_state_with_cosmetics(updated_cosmetics, updated_coins) != OK:
        return false
    progress.coins = updated_coins
    cosmetics = updated_cosmetics
    EventBus.progress_changed.emit(progress.coins, progress.experience, progress.level())
    _emit_cosmetics_changed()
    # Buying the last paid item of a category completes its collection achievement. The coins are
    # banked here; the unlock itself is announced with the next finished round like every other.
    sync_achievements()
    return true


func map_stage_states() -> Array[Dictionary]:
    var stage_states: Array[Dictionary] = []
    var progress_max := LearningRules.UNLOCK_MASTERY * LearningRules.MULTIPLIERS.size()
    for index in LearningRules.TABLES.size():
        var table_value: int = LearningRules.TABLES[index]
        var mastered_facts := 0
        var progress_points := 0
        var facts: Array[Dictionary] = []
        for multiplier in LearningRules.MULTIPLIERS:
            var mastery := profile.get_mastery(table_value, multiplier)
            progress_points += mini(mastery, LearningRules.UNLOCK_MASTERY)
            if mastery >= LearningRules.UNLOCK_MASTERY:
                mastered_facts += 1
            facts.append({
                "multiplier": multiplier,
                "mastery": mastery,
                "status": _fact_mastery_status(mastery),
            })
        var final_stage_complete := (
            index == LearningRules.TABLES.size() - 1
            and mastered_facts >= LearningRules.REQUIRED_FACTS_TO_UNLOCK
        )
        var completed := index < profile.highest_unlocked_index or final_stage_complete
        if completed:
            progress_points = progress_max
        var progress_percent := int(round(
            100.0 * float(progress_points) / float(progress_max)
        ))
        if not completed:
            progress_percent = mini(progress_percent, 99)
        stage_states.append({
            "table": table_value,
            "unlocked": index <= profile.highest_unlocked_index,
            "current": index == profile.highest_unlocked_index and not completed,
            "completed": completed,
            "mastered_facts": mastered_facts,
            "progress_points": progress_points,
            "progress_max": progress_max,
            "progress_percent": progress_percent,
            "facts": facts,
        })
    return stage_states


func _fact_mastery_status(mastery: int) -> StringName:
    if mastery >= LearningRules.AUTOMATED_MASTERY:
        return &"automated"
    if mastery >= LearningRules.UNLOCK_MASTERY:
        return &"mastered"
    if LearningRules.mode_for_mastery(mastery) == LearningRules.QuestionMode.CHOICE_SIX:
        return &"practicing"
    return &"building"


func reset_local_profile() -> void:
    abandon_session()
    profile = LearningProfile.new()
    progress = LocalProgress.new()
    cosmetics = LocalCosmetics.new()
    streak = LocalStreak.new()
    achievements = LocalAchievements.new()
    # A reset profile is a new child, so the guided tutorial runs again for them.
    onboarding = LocalOnboarding.new()
    _pending_achievement_unlocks.clear()
    _nickname = ""
    _save_game_state(profile, progress.coins, progress.experience)
    _create_session_controller()
    EventBus.nickname_changed.emit(_nickname)


func _create_session_controller() -> void:
    session_controller = SessionController.new(profile, _save_profile)
    session_controller.session_started.connect(_on_session_started)
    session_controller.answer_recorded.connect(_on_answer_recorded)
    session_controller.table_unlocked.connect(_on_table_unlocked)


func _on_session_started(question_count: int) -> void:
    EventBus.session_started.emit(question_count)


func _on_answer_recorded(record: SessionResult.AnswerRecord) -> void:
    var time_zone := Time.get_time_zone_from_system()
    streak.record_answer(
        record.correct,
        int(Time.get_unix_time_from_system()),
        int(time_zone.get("bias", 0))
    )
    _apply_mastery_milestone_reward(record)
    sync_achievements()
    EventBus.streak_changed.emit(streak.current_count, streak.all_time_high)
    EventBus.answer_recorded.emit(record.fact_key, record.correct, record.mastery_after)


func _on_table_unlocked(completed_table: int, new_table: int) -> void:
    EventBus.table_unlocked.emit(completed_table, new_table)


func _apply_mastery_milestone_reward(record: SessionResult.AnswerRecord) -> void:
    if record.mastery_after <= record.mastery_before:
        return
    var previous_status := _fact_mastery_status(record.mastery_before)
    var current_status := _fact_mastery_status(record.mastery_after)
    if current_status == previous_status or current_status == &"building":
        return
    var reward_coins := progress.grant_mastery_milestone()
    _session_bonus_coins += reward_coins
    _pending_answer_milestone = {
        "fact_key": record.fact_key,
        "table_value": record.table_value,
        "multiplier": record.multiplier,
        "status": current_status,
        "mastery": record.mastery_after,
        "reward_coins": reward_coins,
    }
    EventBus.progress_changed.emit(progress.coins, progress.experience, progress.level())


func _save_profile(updated_profile: LearningProfile) -> Error:
    return _save_game_state(updated_profile, progress.coins, progress.experience)


func _save_game_state(
    updated_profile: LearningProfile,
    coins: int,
    experience: int
) -> Error:
    return SaveManager.save_game_state(
        updated_profile,
        coins,
        experience,
        SaveManager.PROFILE_PATH,
        cosmetics.to_dictionary(),
        streak.to_dictionary(),
        _nickname,
        achievements.to_dictionary(),
        progress.completed_sessions,
        onboarding.to_dictionary(),
        progress.ledger()
    )


func _save_state_with_cosmetics(updated_cosmetics: LocalCosmetics, coins: int) -> Error:
    return SaveManager.save_game_state(
        profile,
        coins,
        progress.experience,
        SaveManager.PROFILE_PATH,
        updated_cosmetics.to_dictionary(),
        streak.to_dictionary(),
        _nickname,
        achievements.to_dictionary(),
        progress.completed_sessions,
        onboarding.to_dictionary(),
        progress.ledger()
    )


func _emit_cosmetics_changed() -> void:
    EventBus.cosmetics_changed.emit(cosmetics_state())


func _cosmetic_items_state(category: String, selected_id: String) -> Array[Dictionary]:
    var state_items: Array[Dictionary] = []
    for catalog_item in CosmeticCatalog.items(category):
        var item := catalog_item.duplicate(true)
        var item_id := String(item["id"])
        item["owned"] = cosmetics.owns_item(category, item_id)
        item["selected"] = selected_id == item_id
        state_items.append(item)
    return state_items


func _interrupt_unfinished_session() -> bool:
    if session_controller == null or not session_controller.has_active_question():
        return false
    abandon_session()
    EventBus.session_interrupted.emit()
    return true
