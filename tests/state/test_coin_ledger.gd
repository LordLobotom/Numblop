extends NumblopTestCase

## The ledger exists so a cloud merge cannot invent or destroy a child's coins. Its whole value
## rests on one invariant: the buckets always imply the balance the game actually stored. These
## cases walk the real earning and spending paths and check that invariant after each of them.

const TEST_PATH := "user://numblop_ledger_test.json"


func test_a_fresh_profile_has_earned_and_spent_nothing() -> void:
    var progress := LocalProgress.new()
    equal(progress.earned_rounds, 0, "No rounds yet")
    equal(progress.earned_milestones, 0, "No milestones yet")
    equal(CoinLedger.spent_coins(LocalCosmetics.new()), 0, "Free defaults cost nothing")
    equal(CoinLedger.achievement_coins([]), 0, "Nothing granted")


func test_a_finished_round_moves_the_round_bucket_with_the_balance() -> void:
    var progress := LocalProgress.new()
    var result := _completed_result(7)
    progress.apply_completed_session(result, LearningProfile.new(), Callable())

    equal(progress.coins, 7, "Seven correct answers pay seven coins")
    equal(progress.earned_rounds, 7, "The round bucket matches")
    _check_balance_matches(progress, [], LocalCosmetics.new(), "after one round")


func test_a_failed_save_rolls_the_round_bucket_back_with_the_counter() -> void:
    # A reward that never reached disk must not survive in the ledger either, or the next merge
    # would credit coins the child was never given.
    var progress := LocalProgress.new()
    var failing_save := func(_p: LearningProfile, _c: int, _e: int) -> int: return FAILED
    var reward := progress.apply_completed_session(
        _completed_result(5),
        LearningProfile.new(),
        failing_save
    )
    check(reward.is_empty(), "A failed save grants nothing")
    equal(progress.earned_rounds, 0, "The round bucket rolled back")
    equal(progress.completed_sessions, 0, "The session counter rolled back with it")


func test_a_mastery_milestone_moves_its_own_bucket() -> void:
    var progress := LocalProgress.new()
    progress.grant_mastery_milestone()
    progress.grant_mastery_milestone()

    equal(progress.coins, 10, "Two milestones pay ten coins")
    equal(progress.earned_milestones, 10, "The milestone bucket matches")
    equal(progress.earned_rounds, 0, "Rounds are untouched by a milestone")
    _check_balance_matches(progress, [], LocalCosmetics.new(), "after two milestones")


func test_an_achievement_payout_is_derived_rather_than_stored() -> void:
    # Storing it as well would give the merge two sources for the same number, and nothing would
    # keep them in step.
    var progress := LocalProgress.new()
    var achievements := LocalAchievements.new()
    var awarded := achievements.grant(AchievementCatalog.FIRST_STEPS_ID)
    progress.grant_achievement_reward(awarded)

    equal(progress.coins, 100, "The achievement paid its coins")
    equal(progress.earned_rounds, 0, "No bucket moved")
    equal(progress.earned_milestones, 0, "No bucket moved")
    equal(
        CoinLedger.achievement_coins(achievements.granted),
        100,
        "The payout is recoverable from the granted set alone"
    )
    _check_balance_matches(progress, achievements.granted, LocalCosmetics.new(), "after a grant")


func test_spending_is_derived_from_what_is_owned() -> void:
    var cosmetics := LocalCosmetics.new()
    cosmetics.purchase_and_equip_item(CosmeticCatalog.CATEGORY_HAT, "hat_pirat", 1000)
    cosmetics.purchase_and_equip_item(CosmeticCatalog.CATEGORY_NECKLACE, "necklace_moon", 1000)
    cosmetics.purchase_and_equip_item(CosmeticCatalog.CATEGORY_BELLY_COLOR, "pink", 1000)

    equal(CoinLedger.spent_coins(cosmetics), 300, "Three paid items cost 300")
    # Equipping the free default of a category must not read as a purchase.
    cosmetics.equip_item(CosmeticCatalog.CATEGORY_HAT, CosmeticCatalog.DEFAULT_HAT_ID)
    equal(CoinLedger.spent_coins(cosmetics), 300, "Unequipping does not refund")


func test_the_balance_never_goes_negative() -> void:
    var cosmetics := LocalCosmetics.new()
    cosmetics.purchase_and_equip_item(CosmeticCatalog.CATEGORY_HAT, "hat_crown", 1000)
    # A hand-edited or badly merged state that owns more than it ever earned.
    equal(CoinLedger.balance(0, 0, [], cosmetics), 0, "Clamped at zero rather than negative")


func test_a_full_play_history_keeps_the_ledger_and_the_balance_in_step() -> void:
    # Rounds, then a milestone, then an achievement, then two purchases -- the order a real child
    # would produce.
    var progress := LocalProgress.new()
    progress.apply_completed_session(_completed_result(9), LearningProfile.new(), Callable())
    progress.apply_completed_session(_completed_result(6), LearningProfile.new(), Callable())
    progress.grant_mastery_milestone()

    var achievements := LocalAchievements.new()
    progress.grant_achievement_reward(achievements.grant(AchievementCatalog.FIRST_STEPS_ID))

    var cosmetics := LocalCosmetics.new()
    var price := cosmetics.purchase_and_equip_item(
        CosmeticCatalog.CATEGORY_GLASSES,
        "glasses_moon",
        progress.coins
    )
    progress.coins -= price

    equal(progress.coins, 20, "9 + 6 round coins, 5 milestone, 100 achievement, 100 spent")
    _check_balance_matches(progress, achievements.granted, cosmetics, "after a full history")


func test_unknown_ids_in_a_tampered_save_are_worth_nothing() -> void:
    equal(
        CoinLedger.achievement_coins(["not_an_achievement", 42, null]),
        0,
        "Only real achievement ids pay out"
    )


func test_the_ledger_round_trips_through_a_save() -> void:
    _remove_test_file()
    equal(
        SaveManager.save_game_state(
            LearningProfile.new(),
            60,
            80,
            TEST_PATH,
            {},
            {},
            null,
            null,
            4,
            null,
            {"earned_rounds": 155, "earned_milestones": 5}
        ),
        OK,
        "Ledger save"
    )
    var loaded := SaveManager.load_progress(TEST_PATH)
    equal(loaded["earned_rounds"], 155, "Round bucket survives")
    equal(loaded["earned_milestones"], 5, "Milestone bucket survives")

    # A per-answer save passes no ledger; it must carry the stored one through rather than zero it.
    equal(SaveManager.save_profile(LearningProfile.new(), TEST_PATH), OK, "Mastery-only save")
    var after := SaveManager.load_progress(TEST_PATH)
    equal(after["earned_rounds"], 155, "A mastery save preserves the round bucket")
    equal(after["earned_milestones"], 5, "A mastery save preserves the milestone bucket")
    _remove_test_file()


func _completed_result(correct_answers: int) -> SessionResult:
    var profile := LearningProfile.new()
    var result := SessionResult.new(SessionGenerator.generate(profile, 4242))
    var answered := 0
    while not result.is_complete():
        var question := result.current_question()
        var correct := answered < correct_answers
        var submitted := question.answer() if correct else question.answer() + 1
        result.record_answer(
            submitted,
            1.0,
            profile.get_mastery(question.table_value, question.multiplier)
        )
        answered += 1
    return result


func _check_balance_matches(
    progress: LocalProgress,
    granted_ids: Array,
    cosmetics: LocalCosmetics,
    context: String
) -> void:
    equal(
        CoinLedger.balance(
            progress.earned_rounds,
            progress.earned_milestones,
            granted_ids,
            cosmetics
        ),
        progress.coins,
        "The ledger implies the stored balance %s" % context
    )


func _remove_test_file() -> void:
    SaveManager.delete_profile(TEST_PATH)
