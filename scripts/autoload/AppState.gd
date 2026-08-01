extends Node

var profile := LearningProfile.new()
var active_session: Array[PracticeQuestion] = []
var active_session_result: SessionResult
var session_controller: SessionController
var progress := LocalProgress.new()
var cosmetics := LocalCosmetics.new()


func _ready() -> void:
    profile = SaveManager.load_profile()
    progress = LocalProgress.new(SaveManager.load_progress())
    cosmetics = LocalCosmetics.new(SaveManager.load_cosmetics())
    _create_session_controller()


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
    active_session_result = session_controller.begin_session(actual_seed)
    active_session = active_session_result.questions.duplicate()
    return active_session


func submit_answer(
    submitted_answer: int,
    elapsed_seconds: float
) -> SessionResult.AnswerRecord:
    return session_controller.submit_answer(submitted_answer, elapsed_seconds)


func record_answer(question: PracticeQuestion, correct: bool, elapsed_seconds: float) -> int:
    assert(question == session_controller.current_question(), "Answers must be submitted in order")
    var submitted_answer := question.answer() if correct else question.answer() + 1
    var record := submit_answer(submitted_answer, elapsed_seconds)
    return record.mastery_delta


func abandon_session() -> void:
    session_controller.abandon_active_session()
    active_session_result = null
    active_session.clear()


func handle_application_paused() -> bool:
    return _interrupt_unfinished_session()


func handle_application_resumed() -> void:
    EventBus.application_resumed.emit()


func handle_go_back_request() -> bool:
    if _interrupt_unfinished_session():
        return true
    EventBus.back_requested.emit()
    return false


func claim_completed_session_reward() -> Dictionary:
    var reward := progress.apply_completed_session(
        active_session_result,
        profile,
        _save_game_state
    )
    if reward.is_empty():
        return {}
    EventBus.reward_applied.emit(int(reward["coins"]), int(reward["experience"]))
    EventBus.progress_changed.emit(progress.coins, progress.experience, progress.level())
    session_controller.clear_completed_session()
    active_session_result = null
    active_session.clear()
    return reward


func progress_totals() -> Dictionary:
    return progress.totals()


func cosmetics_state() -> Dictionary:
    return {
        "coins": progress.coins,
        "selected_body_color": cosmetics.selected_body_color,
        "selected_hat": cosmetics.selected_hat,
        "selected_glasses": cosmetics.selected_glasses,
        "colors": _cosmetic_items_state(
            CosmeticCatalog.CATEGORY_BODY_COLOR,
            cosmetics.selected_body_color
        ),
        "hats": _cosmetic_items_state(
            CosmeticCatalog.CATEGORY_HAT,
            cosmetics.selected_hat
        ),
        "glasses": _cosmetic_items_state(
            CosmeticCatalog.CATEGORY_GLASSES,
            cosmetics.selected_glasses
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
    return true


func map_stage_states() -> Array[Dictionary]:
    var stage_states: Array[Dictionary] = []
    var progress_max := LearningRules.UNLOCK_MASTERY * LearningRules.MULTIPLIERS.size()
    for index in LearningRules.TABLES.size():
        var table_value: int = LearningRules.TABLES[index]
        var mastered_facts := 0
        var progress_points := 0
        for multiplier in LearningRules.MULTIPLIERS:
            var mastery := profile.get_mastery(table_value, multiplier)
            progress_points += mini(mastery, LearningRules.UNLOCK_MASTERY)
            if mastery >= LearningRules.UNLOCK_MASTERY:
                mastered_facts += 1
        var final_stage_complete := (
            index == LearningRules.TABLES.size() - 1
            and mastered_facts == LearningRules.MULTIPLIERS.size()
        )
        var completed := index < profile.highest_unlocked_index or final_stage_complete
        if completed:
            progress_points = progress_max
        var progress_percent := int(round(
            100.0 * float(progress_points) / float(progress_max)
        ))
        stage_states.append({
            "table": table_value,
            "unlocked": index <= profile.highest_unlocked_index,
            "current": index == profile.highest_unlocked_index and not completed,
            "completed": completed,
            "mastered_facts": mastered_facts,
            "progress_points": progress_points,
            "progress_max": progress_max,
            "progress_percent": progress_percent,
        })
    return stage_states


func reset_local_profile() -> void:
    abandon_session()
    profile = LearningProfile.new()
    progress = LocalProgress.new()
    cosmetics = LocalCosmetics.new()
    _save_game_state(profile, progress.coins, progress.experience)
    _create_session_controller()


func _create_session_controller() -> void:
    session_controller = SessionController.new(profile, _save_profile)
    session_controller.session_started.connect(_on_session_started)
    session_controller.answer_recorded.connect(_on_answer_recorded)
    session_controller.table_unlocked.connect(_on_table_unlocked)


func _on_session_started(question_count: int) -> void:
    EventBus.session_started.emit(question_count)


func _on_answer_recorded(record: SessionResult.AnswerRecord) -> void:
    EventBus.answer_recorded.emit(record.fact_key, record.correct, record.mastery_after)


func _on_table_unlocked(completed_table: int, new_table: int) -> void:
    EventBus.table_unlocked.emit(completed_table, new_table)


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
        cosmetics.to_dictionary()
    )


func _save_state_with_cosmetics(updated_cosmetics: LocalCosmetics, coins: int) -> Error:
    return SaveManager.save_game_state(
        profile,
        coins,
        progress.experience,
        SaveManager.PROFILE_PATH,
        updated_cosmetics.to_dictionary()
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
