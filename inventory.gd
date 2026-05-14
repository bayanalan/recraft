class_name Inventory

const HOTBAR_SIZE:  int = 9
const STORAGE_SIZE: int = 27
const TOTAL_SLOTS:  int = 36

var ids:      Array[int] = []
var counts:   Array[int] = []
var armor_ids: Array[int] = []


func _init() -> void:
	ids.resize(TOTAL_SLOTS)
	ids.fill(0)
	counts.resize(TOTAL_SLOTS)
	counts.fill(0)
	armor_ids.resize(4)
	armor_ids.fill(0)


func get_hotbar_id(slot: int) -> int:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return 0
	return ids[slot]


func get_hotbar_count(slot: int) -> int:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return 0
	return counts[slot]


func set_slot(slot: int, id: int, count: int) -> void:
	if slot < 0 or slot >= TOTAL_SLOTS:
		return
	var max_s: int = Items.get_max_stack(id) if id > 0 else 64
	var clamped: int = clampi(count, 0, max_s)
	if clamped == 0 or id == 0:
		ids[slot] = 0
		counts[slot] = 0
	else:
		ids[slot] = id
		counts[slot] = clamped


func give_item(id: int, amount: int) -> int:
	if id == 0 or amount <= 0:
		return 0
	var remaining: int = amount
	var max_s: int = Items.get_max_stack(id)

	# Try stacking into existing slots (hotbar first, then storage)
	if max_s > 1:
		for i: int in TOTAL_SLOTS:
			if remaining <= 0:
				break
			if ids[i] == id and counts[i] < max_s:
				var space: int = max_s - counts[i]
				var add: int = mini(remaining, space)
				counts[i] += add
				remaining -= add

	# Fill empty slots (hotbar first, then storage)
	for i: int in TOTAL_SLOTS:
		if remaining <= 0:
			break
		if ids[i] == 0:
			var add: int = mini(remaining, max_s)
			ids[i] = id
			counts[i] = add
			remaining -= add

	return remaining


func take_from_slot(slot: int, amount: int) -> void:
	if slot < 0 or slot >= TOTAL_SLOTS:
		return
	counts[slot] = maxi(0, counts[slot] - amount)
	if counts[slot] == 0:
		ids[slot] = 0


func get_total_count(id: int) -> int:
	var total: int = 0
	for i: int in TOTAL_SLOTS:
		if ids[i] == id:
			total += counts[i]
	return total


func consume_items(id: int, amount: int) -> bool:
	if get_total_count(id) < amount:
		return false
	var remaining: int = amount
	for i: int in TOTAL_SLOTS:
		if remaining <= 0:
			break
		if ids[i] == id:
			var take: int = mini(remaining, counts[i])
			counts[i] -= take
			remaining -= take
			if counts[i] == 0:
				ids[i] = 0
	return true


func swap_slots(a: int, b: int) -> void:
	if a < 0 or a >= TOTAL_SLOTS or b < 0 or b >= TOTAL_SLOTS:
		return
	var tmp_id: int = ids[a]
	var tmp_count: int = counts[a]
	ids[a] = ids[b]
	counts[a] = counts[b]
	ids[b] = tmp_id
	counts[b] = tmp_count


func to_dict() -> Dictionary:
	return {
		"ids":      ids,
		"counts":   counts,
		"armor_ids": armor_ids,
	}


func from_dict(d: Dictionary) -> void:
	if d.has("ids"):
		var src: Array = d["ids"]
		for i: int in mini(src.size(), TOTAL_SLOTS):
			ids[i] = int(src[i])
	if d.has("counts"):
		var src: Array = d["counts"]
		for i: int in mini(src.size(), TOTAL_SLOTS):
			counts[i] = int(src[i])
	if d.has("armor_ids"):
		var src: Array = d["armor_ids"]
		for i: int in mini(src.size(), 4):
			armor_ids[i] = int(src[i])
