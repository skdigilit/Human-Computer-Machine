class_name SnakeLevel
extends Level

## A Snake puzzle. Reuses Level's title / briefing / palette; the inbox and
## outbox fields stay empty because Snake has no expected output — the win is
## reaching `target_score` instead.

## Board is grid_size x grid_size cells. 0 means "use the Settings value".
var grid_size: int = 0
## How many cells long the snake starts.
var start_length: int = 3
## Score that completes the level; 0 means play forever.
var target_score: int = 5
## Seed for food placement so every RESET (and every headless test) plays the
## same. Levels pick their own so they don't all start with food in one spot.
var food_seed: int = 1
## Optional writable speed divisor for WAIT; -1 keeps fixed waits.
var wait_scale_slot: int = -1
## Optional slot the VM keeps in sync with how much food has been eaten so
## far; -1 means the level's briefing doesn't state a food count to track.
var food_count_slot: int = -1

## Set from Settings by SnakeGame; applies to every level whose grid_size is 0.
static var grid_size_override: int = SnakeState.DEFAULT_GRID_SIZE

## Grid size after applying the Settings override.
func effective_grid_size() -> int:
	var chosen := grid_size if grid_size > 0 else grid_size_override
	return maxi(chosen, SnakeState.MIN_GRID_SIZE)
