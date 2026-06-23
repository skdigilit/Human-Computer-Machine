class_name StepAction
extends RefCounted

## A pure description of the side effects of executing one instruction.
## The VM produces these; the RoomView reads them to animate the worker.
## Decoupling "what happened" from "how it looks" keeps the VM testable
## headlessly and keeps the visuals free of execution logic.

## Where the worker should pick a value up from this step.
enum Source { NONE, INBOX, MEMORY }
## Where the worker should put the held value down this step.
enum Sink { NONE, OUTBOX, MEMORY }

var op: InstructionDef.Op
## Index in the program of the instruction that just ran.
var line_index: int = -1

var source: Source = Source.NONE
var sink: Sink = Sink.NONE
## Memory tile involved (for MEMORY source/sink or arithmetic reads).
var address: int = -1
## The value the worker is holding after this step (NULL_VALUE if empty-handed).
var held_value: int = NULL_VALUE
## Whether a memory tile's value changed (bump / copyto), and to what.
var memory_changed: bool = false
var memory_value: int = 0

## Set when the program finished (successfully or with an error).
var halted: bool = false
var success: bool = false
var message: String = ""

## Sentinel meaning "the worker's hands are empty".
const NULL_VALUE := -2147483648

func has_value() -> bool:
	return held_value != NULL_VALUE
