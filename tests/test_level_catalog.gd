extends SceneTree

const EXPECTED_NEW_TITLES := [
	"Tetracontiplier",
	"Maximization Room",
	"Absolute Positivity",
	"Exclusive Lounge",
	"Multiplication Workshop",
	"Zero Terminated Sum",
	"Fibonacci Visitor",
	"The Littlest Number",
	"Cumulative Countdown",
	"Small Divide",
]

const ALL_INSTRUCTIONS := [
	InstructionDef.Op.INBOX,
	InstructionDef.Op.OUTBOX,
	InstructionDef.Op.COPYFROM,
	InstructionDef.Op.COPYTO,
	InstructionDef.Op.ADD,
	InstructionDef.Op.SUB,
	InstructionDef.Op.BUMP_UP,
	InstructionDef.Op.BUMP_DOWN,
	InstructionDef.Op.JUMP,
	InstructionDef.Op.JUMP_IF_ZERO,
	InstructionDef.Op.JUMP_IF_NEG,
]

const PRE_BUMP_INSTRUCTIONS := [
	InstructionDef.Op.INBOX,
	InstructionDef.Op.OUTBOX,
	InstructionDef.Op.COPYFROM,
	InstructionDef.Op.COPYTO,
	InstructionDef.Op.ADD,
	InstructionDef.Op.SUB,
	InstructionDef.Op.JUMP,
	InstructionDef.Op.JUMP_IF_ZERO,
	InstructionDef.Op.JUMP_IF_NEG,
]

func _init() -> void:
	var levels := LevelLibrary.all_levels()
	var titles: Array[String] = []
	var passed := levels.size() == 24

	for level in levels:
		titles.append(level.title)
		passed = passed and not level.title.is_empty()
		passed = passed and not level.briefing.is_empty()
		passed = passed and not level.inbox.is_empty()
		passed = passed and not level.expected_outbox.is_empty()
		passed = passed and not level.palette.is_empty()

	for title in EXPECTED_NEW_TITLES:
		passed = passed and titles.has(title)

	passed = passed and _has_exact_palette(
		levels, "Tetracontiplier", [
			InstructionDef.Op.INBOX,
			InstructionDef.Op.OUTBOX,
			InstructionDef.Op.COPYFROM,
			InstructionDef.Op.COPYTO,
			InstructionDef.Op.ADD,
			InstructionDef.Op.JUMP,
		]
	)
	for title in ["Maximization Room", "Absolute Positivity", "Exclusive Lounge"]:
		passed = passed and _has_exact_palette(levels, title, PRE_BUMP_INSTRUCTIONS)
	for title in [
		"Multiplication Workshop",
		"Zero Terminated Sum",
		"Fibonacci Visitor",
		"The Littlest Number",
		"Cumulative Countdown",
		"Small Divide",
	]:
		passed = passed and _has_exact_palette(levels, title, ALL_INSTRUCTIONS)

	passed = passed and titles.size() == _unique_count(titles)
	print("RESULT: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)

func _has_exact_palette(levels: Array[Level], title: String, expected: Array) -> bool:
	for level in levels:
		if level.title == title:
			return level.palette == expected
	return false

func _unique_count(values: Array[String]) -> int:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique.size()
