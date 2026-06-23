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

## Number of memory tiles on the floor.
var memory_size: int = 0
## Pre-filled memory tiles, keyed by tile index (e.g. a constant "0" tile).
var initial_memory: Dictionary = {}

## Opcodes offered in the palette for this level.
var palette: Array[InstructionDef.Op] = []
