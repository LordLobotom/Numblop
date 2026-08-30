class_name PracticeSetupScreen
extends Control

signal start_requested(question_count: int, selected_tables: Array[int])
signal back_requested
signal outfit_requested
signal map_requested
signal home_requested
signal trophy_requested
signal settings_requested

@onready var back_button: Button = %BackButton
@onready var title_label: Label = %TitleLabel
@onready var question_count_label: Label = %QuestionCountLabel
@onready var tables_label: Label = %TablesLabel
@onready var selection_hint: Label = %SelectionHint
@onready var question_grid: GridContainer = %QuestionGrid
@onready var table_grid: GridContainer = %TableGrid
@onready var start_button: Button = %StartButton
@onready var navigation: NavBar = $SafeArea/Content/Navigation

var _question_count := 10
var _question_counts: Array[int] = []
var _table_states: Array[Dictionary] = []
var _selected_tables: Dictionary = {}
var _question_cards: Dictionary = {}
var _table_cards: Dictionary = {}


func _ready() -> void:
    back_button.pressed.connect(back_requested.emit)
    start_button.pressed.connect(_on_start_pressed)
    navigation.outfit_requested.connect(outfit_requested.emit)
    navigation.map_requested.connect(map_requested.emit)
    navigation.home_requested.connect(home_requested.emit)
    navigation.trophy_requested.connect(trophy_requested.emit)
    navigation.settings_requested.connect(settings_requested.emit)
    _refresh_text()


func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
        _refresh_text()
        _refresh_card_tooltips()


func present(state: Dictionary) -> void:
    _question_counts.clear()
    var raw_counts: Variant = state.get("question_counts", [])
    if raw_counts is Array:
        for raw_count in raw_counts:
            var count := int(raw_count)
            if LearningRules.is_free_practice_length(count):
                _question_counts.append(count)
    _question_count = int(state.get("default_question_count", 10))
    if not _question_counts.has(_question_count) and not _question_counts.is_empty():
        _question_count = _question_counts[0]

    _table_states.clear()
    _selected_tables.clear()
    var raw_tables: Variant = state.get("tables", [])
    if raw_tables is Array:
        for raw_state in raw_tables:
            if raw_state is not Dictionary:
                continue
            var table_state: Dictionary = raw_state.duplicate(true)
            var table_value := int(table_state.get("table", 0))
            var eligible := bool(table_state.get("practice_eligible", false))
            if eligible and bool(table_state.get("selected", false)):
                _selected_tables[table_value] = true
            _table_states.append(table_state)
    if is_node_ready():
        _rebuild_cards()
        _refresh_text()


func selected_tables() -> Array[int]:
    var values: Array[int] = []
    for table_value in LearningRules.TABLES:
        if _selected_tables.has(table_value):
            values.append(table_value)
    return values


func selected_question_count() -> int:
    return _question_count


func question_card(question_count: int) -> PracticeOptionCard:
    return _question_cards.get(question_count) as PracticeOptionCard


func table_card(table_value: int) -> PracticeOptionCard:
    return _table_cards.get(table_value) as PracticeOptionCard


func _rebuild_cards() -> void:
    _clear_grid(question_grid)
    _clear_grid(table_grid)
    _question_cards.clear()
    _table_cards.clear()
    for question_count in _question_counts:
        var card := PracticeOptionCard.new()
        card.name = "Questions%d" % question_count
        card.configure(str(question_count), question_count, question_count == _question_count, false)
        card.pressed.connect(_on_question_count_pressed.bind(question_count))
        question_grid.add_child(card)
        _question_cards[question_count] = card
    for table_state in _table_states:
        var table_value := int(table_state.get("table", 0))
        var eligible := bool(table_state.get("practice_eligible", false))
        var card := PracticeOptionCard.new()
        card.name = "Table%d" % table_value
        card.custom_minimum_size.x = 72.0
        card.configure(
            "%d×" % table_value,
            table_value,
            _selected_tables.has(table_value),
            not eligible
        )
        if eligible:
            card.pressed.connect(_on_table_pressed.bind(table_value))
        table_grid.add_child(card)
        _table_cards[table_value] = card
    start_button.disabled = not _has_eligible_table()
    _refresh_card_tooltips()


func _on_question_count_pressed(question_count: int) -> void:
    _question_count = question_count
    for value in _question_cards:
        var card: PracticeOptionCard = _question_cards[value]
        card.set_selected(int(value) == _question_count)


func _on_table_pressed(table_value: int) -> void:
    if _selected_tables.has(table_value):
        _selected_tables.erase(table_value)
    else:
        _selected_tables[table_value] = true
    var card := table_card(table_value)
    if card != null:
        card.set_selected(_selected_tables.has(table_value))
    _refresh_selection_hint()
    _refresh_card_tooltips()


func _on_start_pressed() -> void:
    start_requested.emit(_question_count, selected_tables())


func _refresh_text() -> void:
    title_label.text = tr("PRACTICE_SETUP_TITLE")
    question_count_label.text = tr("PRACTICE_SETUP_QUESTION_COUNT")
    tables_label.text = tr("PRACTICE_SETUP_TABLES")
    start_button.text = tr("PRACTICE_SETUP_START")
    back_button.tooltip_text = tr("PRACTICE_SETUP_BACK")
    _refresh_selection_hint()


func _refresh_selection_hint() -> void:
    if _selected_tables.is_empty():
        selection_hint.text = tr("PRACTICE_SETUP_SMART_HINT")
    else:
        selection_hint.text = tr("PRACTICE_SETUP_BALANCED_HINT").format({
            "count": _selected_tables.size(),
        })


func _refresh_card_tooltips() -> void:
    for table_state in _table_states:
        var table_value := int(table_state.get("table", 0))
        var card := table_card(table_value)
        if card == null:
            continue
        if bool(table_state.get("practice_eligible", false)):
            card.tooltip_text = tr("PRACTICE_SETUP_TABLE_READY").format({"table": table_value})
        else:
            card.tooltip_text = tr("PRACTICE_SETUP_TABLE_LOCKED").format({"table": table_value})


func _has_eligible_table() -> bool:
    for table_state in _table_states:
        if bool(table_state.get("practice_eligible", false)):
            return true
    return false


func _clear_grid(grid: GridContainer) -> void:
    for child in grid.get_children():
        grid.remove_child(child)
        child.queue_free()
