extends Node

signal session_started(question_count: int)
signal answer_recorded(fact_key: String, correct: bool, mastery: int)
signal progress_changed(coins: int, experience: int, level: int)
signal reward_applied(coins: int, experience: int)
signal session_interrupted
signal application_resumed
signal back_requested
signal profile_saved
signal locale_changed(locale: String)
signal audio_settings_changed(music_volume: float, sfx_volume: float, muted: bool)
