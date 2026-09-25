class_name Level
extends RefCounted

## Pure description of a puzzle: its briefing text, the inbox the worker starts
## with, the outbox the boss expects, how many memory tiles are on the floor,
## and which instructions are available in the palette.

var title: String = ""
## Multi-line briefing shown on the "sticky note" above the program.
var briefing: String = ""

## Values that arrive on the inbox conveyor, front first.
var inbox: Array[int] = []
## The exact sequence the outbox must contain to win.
var expected_outbox: Array[int] = []

## Alternate inbox/outbox pairs used to test that a program solves the rule,
## rather than only the values shown when the level first opens. The first
## call to add_test_case preserves the level's original pair as case zero.
var test_cases: Array[Dictionary] = []
var active_test_case: int = 0

## Number of memory tiles on the floor.
var memory_size: int = 0
## Pre-filled memory tiles, keyed by tile index (e.g. a constant "0" tile).
var initial_memory: Dictionary = {}

## Opcodes offered in the palette for this level.
var palette: Array[InstructionDef.Op] = []

func add_test_case(case_inbox: Array[int], case_outbox: Array[int]) -> void:
	if test_cases.is_empty():
		test_cases.append({
			"inbox": inbox.duplicate(),
			"outbox": expected_outbox.duplicate(),
		})
	test_cases.append({
		"inbox": case_inbox.duplicate(),
		"outbox": case_outbox.duplicate(),
	})

func test_case_count() -> int:
	return maxi(1, test_cases.size())

func select_test_case(index: int) -> void:
	if test_cases.is_empty():
		active_test_case = 0
		return
	active_test_case = posmod(index, test_cases.size())
	var test_case: Dictionary = test_cases[active_test_case]
	inbox = (test_case["inbox"] as Array[int]).duplicate()
	expected_outbox = (test_case["outbox"] as Array[int]).duplicate()

func select_next_test_case() -> void:
	select_test_case(active_test_case + 1)
