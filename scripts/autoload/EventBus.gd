extends Node

signal session_started(question_count: int)
signal answer_recorded(fact_key: String, correct: bool, mastery: int)
signal profile_saved
signal locale_changed(locale: String)
