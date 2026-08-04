extends SceneTree

const TEST_DIRECTORIES: Array[String] = [
    "res://tests/core",
    "res://tests/state",
    "res://tests/ui",
    "res://tests/smoke",
]

var _has_run := false


func _process(_delta: float) -> bool:
    if _has_run:
        # Returning true here would end the main loop, and a test that spans frames would
        # never resume. The suite ends itself with quit() once it has scored everything.
        return false
    _has_run = true
    _run_suite()
    return false


func _run_suite() -> void:
    var passed := 0
    var failed := 0
    for path in _discover_test_files():
        var script: GDScript = load(path)
        if script == null:
            failed += 1
            print("FAIL %s could not load" % path)
            continue
        var test: NumblopTestCase = script.new()
        for method in test.get_method_list():
            var method_name: String = method.name
            if not method_name.begins_with("test_"):
                continue
            var failure_count := test.failures.size()
            # Awaited so a test may span frames. A gesture, an animation or a screen
            # transition cannot be judged inside one call, and a coroutine test that was
            # merely called would report its result after the runner had already scored it.
            await test.call(method_name)
            if test.failures.size() == failure_count:
                passed += 1
                print("PASS %s :: %s" % [path.get_file(), method_name])
            else:
                failed += 1
                print("FAIL %s :: %s" % [path.get_file(), method_name])
                for index in range(failure_count, test.failures.size()):
                    print("     %s" % test.failures[index])

    print("NUMBLOP_TESTS: %d passed, %d failed" % [passed, failed])
    if failed == 0:
        print("NUMBLOP_TESTS_OK")
    quit(0 if failed == 0 else 1)


func _discover_test_files() -> Array[String]:
    var paths: Array[String] = []
    for directory in TEST_DIRECTORIES:
        var access := DirAccess.open(directory)
        if access == null:
            continue
        access.list_dir_begin()
        var file_name := access.get_next()
        while not file_name.is_empty():
            if not access.current_is_dir() and file_name.begins_with("test_") \
                    and file_name.ends_with(".gd"):
                paths.append("%s/%s" % [directory, file_name])
            file_name = access.get_next()
        access.list_dir_end()
    paths.sort()
    return paths
