class_name SnakeState
extends RefCounted

## Pure board state for Snake: where the body is, which way it faces, where the
## food is, the score, and which arrow keys were pressed since the last tick.
## No scene dependencies, so SnakeVM tests run headless and SnakeArena only
## ever reads from it.

const MIN_GRID_SIZE := 5
const MAX_GRID_SIZE := 100
const DEFAULT_GRID_SIZE := 35

## Cell offset for each InstructionDef.Direction, indexed by the enum value.
const DIRECTION_STEPS: Array[Vector2i] = [
	Vector2i(-1, 0),  # LEFT
	Vector2i(0, -1),  # UP
	Vector2i(1, 0),   # RIGHT
	Vector2i(0, 1),   # DOWN
]

var grid_size: int = DEFAULT_GRID_SIZE
## Body cells, head first.
var body: Array[Vector2i] = []
var heading: InstructionDef.Direction = InstructionDef.Direction.RIGHT
var food: Vector2i = Vector2i(-1, -1)
var score: int = 0
## Extra cells the tail keeps on upcoming moves (one per food eaten).
var grow_pending: int = 0
## Directions whose arrow key was pressed since the last tick.
var pressed_keys: Dictionary = {}
var _rng := RandomNumberGenerator.new()

## Lay the snake horizontally in the middle of the board, facing right, with
## food placed by the seeded RNG.
func reset(p_grid_size: int, start_length: int, seed_value: int) -> void:
	grid_size = clampi(p_grid_size, MIN_GRID_SIZE, MAX_GRID_SIZE)
	_rng.seed = seed_value
	body.clear()
	var centre := grid_size / 2
	var length := clampi(start_length, 1, grid_size - 2)
	for i in length:
		body.append(Vector2i(centre - i, centre))
	heading = InstructionDef.Direction.RIGHT
	score = 0
	grow_pending = 0
	pressed_keys.clear()
	spawn_food()

func head() -> Vector2i:
	return body[0]

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size and cell.y < grid_size

func head_on_wall() -> bool:
	return not is_inside(head())

func head_on_food() -> bool:
	return head() == food

## True when the head overlaps any other body cell.
func head_on_tail() -> bool:
	var h := head()
	for i in range(1, body.size()):
		if body[i] == h:
			return true
	return false

## Turn the snake. A U-turn into its own neck is ignored (classic rule), and
## the call reports whether the heading actually changed.
func face(direction: InstructionDef.Direction) -> bool:
	if body.size() > 1 and _is_opposite(direction, heading):
		return false
	heading = direction
	return true

## Advance one cell. The tail only follows when no growth is pending.
func move() -> void:
	body.push_front(head() + DIRECTION_STEPS[heading])
	if grow_pending > 0:
		grow_pending -= 1
	else:
		body.pop_back()

## Consume the food under the head. Returns false when there is none.
func eat() -> bool:
	if not head_on_food():
		return false
	score += 1
	grow_pending += 1
	spawn_food()
	return true

## Put food on a random free cell (never under the body). Off the board when
## the snake has filled everything.
func spawn_food() -> void:
	var free: Array[Vector2i] = []
	var occupied := {}
	for cell in body:
		occupied[cell] = true
	for y in grid_size:
		for x in grid_size:
			var cell := Vector2i(x, y)
			if not occupied.has(cell):
				free.append(cell)
	if free.is_empty():
		food = Vector2i(-1, -1)
		return
	food = free[_rng.randi_range(0, free.size() - 1)]

## Remember an arrow press until the next tick clears it.
func press_key(direction: InstructionDef.Direction) -> void:
	pressed_keys[direction] = true

func key_pressed(direction: InstructionDef.Direction) -> bool:
	return pressed_keys.has(direction)

func clear_keys() -> void:
	pressed_keys.clear()

static func _is_opposite(a: InstructionDef.Direction, b: InstructionDef.Direction) -> bool:
	return DIRECTION_STEPS[a] == -DIRECTION_STEPS[b]
