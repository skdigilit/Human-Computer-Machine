class_name SnakeStepAction
extends StepAction

## StepAction for Snake. The arena redraws from `state` rather than from
## per-field deltas, so this only adds what the HUD and status line need.

## Board after the step ran (shared reference, read-only for the view).
var state: SnakeState = null
## Snapshot for the student memory tiles after this instruction.
var memory_values: Array[int] = []
## Whether each value represents a captured key rather than a numeric counter.
var memory_key_flags: Array[bool] = []
## True when this step changed something visible (move / eat / face).
var board_changed: bool = false
## True when this step ate food, for the score pop.
var ate: bool = false
