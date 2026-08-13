extends Node

signal session_started(question_count: int)
signal answer_recorded(fact_key: String, correct: bool, mastery: int)
signal table_unlocked(completed_table: int, new_table: int)
signal progress_changed(coins: int, experience: int, level: int)
signal reward_applied(coins: int, experience: int)
signal cosmetics_changed(state: Dictionary)
signal streak_changed(current_count: int, all_time_high: int)
signal achievements_unlocked(entries: Array)
signal nickname_changed(nickname: String)
signal session_interrupted
signal application_resumed
signal back_requested
signal profile_saved
signal profile_reloaded
signal application_paused
signal locale_changed(locale: String)
signal audio_settings_changed(music_volume: float, sfx_volume: float, muted: bool)
