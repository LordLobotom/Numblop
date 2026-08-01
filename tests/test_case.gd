class_name NumblopTestCase
extends RefCounted

var failures: Array[String] = []


func check(condition: bool, message: String = "Check failed") -> void:
    if not condition:
        failures.append(message)


func equal(actual: Variant, expected: Variant, message: String = "") -> void:
    if actual != expected:
        failures.append("%s expected=%s actual=%s" % [message, expected, actual])


func contains(values: Variant, expected: Variant, message: String = "") -> void:
    if not values.has(expected):
        failures.append("%s missing=%s" % [message, expected])
