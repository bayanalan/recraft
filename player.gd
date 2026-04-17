class_name Player
extends CharacterBody3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

# Base radian-per-pixel rate at the "normal" sensitivity slider value (100).
# `mouse_sens` is the actual rate consumed by _unhandled_input and gets scaled
# from this base by the settings slider: value/100 → multiplier, so slider=1
# → 0.01× (basically frozen — "Sleepy"), slider=200 → 2× (very fast — "WEEEEEE").
const MOUSE_SENS_BASE: float = 0.002
var mouse_sens: float = MOUSE_SENS_BASE
const PITCH_LIMIT: float = 1.5533

# Minecraft-like movement with momentum
const WALK_SPEED: float = 4.317
const SPRINT_SPEED: float = 6.6
const CROUCH_SPEED: float = 1.3        # Minecraft sneak pace (~30% of walk)
const JUMP_VELOCITY: float = 8.4
const GRAVITY: float = 28.0
const GROUND_ACCEL_RATE: float = 22.0  # lerp rate toward target velocity on ground
const AIR_ACCEL_RATE: float = 2.5      # much slower in air — preserves momentum
const STEP_HEIGHT: float = 0.55

# Sprint FOV bump (Minecraft's "running FOV"): base * 1.10 while sprinting,
# lerped so the zoom feels smooth. Crouch does NOT change FOV.
const SPRINT_FOV_MULT: float = 1.10
const FOV_LERP_RATE: float = 10.0

# Crouch (Minecraft sneak): head drops 0.3 blocks, camera eases down with
# the same rate used by step-up smoothing so crouching feels connected to
# the existing motion language.
const CROUCH_HEAD_DROP: float = 0.3
const CROUCH_SMOOTH_RATE: float = 14.0

# Hold LMB/RMB to continuously break/place. Cooldown matches Minecraft
# creative-mode pacing (~5 actions/sec when holding).
const ACTION_COOLDOWN: float = 0.20
# Short grace after re-capturing the mouse so the click that re-captured
# doesn't also immediately fire a break/place.
const CAPTURE_GRACE: float = 0.15

# Double-tap jump (Space) within this window toggles flying.
const DOUBLE_JUMP_WINDOW: float = 0.30
# Flight constants. Horizontal a touch faster than sprint on ground so flying
# actually feels like flying; vertical matches horizontal for responsive feel.
const FLY_SPEED: float = 10.9
const FLY_VERTICAL_SPEED: float = 10.0

var world: World = null
var hud: Node = null
var block_outline: BlockOutline = null
# Cache last outline position so we only touch the node when it changes
var _outline_last_pos: Vector3i = Vector3i(-999, -999, -999)
var _outline_visible: bool = false

var _break_cooldown: float = 0.0
var _place_cooldown: float = 0.0
var _capture_cooldown: float = 0.0
var _lmb_held_last: bool = false
var _rmb_held_last: bool = false

# Flying (Minecraft creative style). Toggled by double-tapping Space.
# Gated by the `Enable Flying` settings toggle so the user can disable the
# double-tap entirely for survival-like play.
var is_flying: bool = false
var flying_enabled: bool = true
var _last_jump_time: float = -999.0

# Sprint state. `sprint_toggle_mode=false` → Hold: pressing Shift while
# moving latches sprint until you stop moving (Minecraft behavior);
# `sprint_toggle_mode=true` → Toggle: Shift flips always-sprint on/off.
# `is_sprinting` is the resolved per-frame state consumed by the speed pick
# and the FOV bump.
var is_sprinting: bool = false
var sprint_toggle_mode: bool = false
var _sprint_latched: bool = false

# Crouch state (bound to the `descend` action = Ctrl by default). Same
# Hold/Toggle semantics as sprint. `_crouch_smooth` drives the camera dip
# and composes with `_step_head_offset` in `head.position.y`.
var is_crouching: bool = false
var crouch_toggle_mode: bool = false
var _crouch_latched: bool = false
var _crouch_smooth: float = 0.0

# Tunable FOV from settings. camera.fov smoothly chases `_target_fov` which
# is `base_fov` normally and `base_fov * SPRINT_FOV_MULT` when sprinting.
var base_fov: float = 70.0

# Smooth step-up: when _try_step_up snaps the player up a ledge we push the
# head down by the same amount, then lerp it back to 0 each frame. The
# player's feet jump instantly (so physics stays clean) but the camera
# appears to glide up smoothly, matching Minecraft's step-up feel.
const STEP_SMOOTH_RATE: float = 14.0  # higher = snappier recovery
var _step_head_offset: float = 0.0
var _head_base_y: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world = get_parent().get_node("World") as World
	hud = get_parent().get_node_or_null("HUD")
	block_outline = get_parent().get_node_or_null("BlockOutline") as BlockOutline
	_head_base_y = head.position.y
	camera.fov = base_fov


## Apply a slider value (1-200) from the settings screen. 100 = normal
## sensitivity; endpoints clamp into Sleepy / WEEEEEE territory.
func set_mouse_sensitivity(slider_value: int) -> void:
	var v: float = float(clampi(slider_value, 1, 200))
	mouse_sens = MOUSE_SENS_BASE * (v / 100.0)


## Apply a new base FOV from the settings screen. Sprint still multiplies
## this, so passing a new base correctly updates both idle and running FOV.
func set_base_fov(fov: float) -> void:
	base_fov = fov
	# Snap to the new base immediately if we're not sprinting; sprinting keeps
	# the current value and the smoothing kicks in next frame.
	if not is_sprinting:
		camera.fov = base_fov


## True when the chat input bar is focused — blocks game input (mouse look,
## break/place, movement keys) so typing doesn't fire actions.
func _is_chat_open() -> bool:
	return hud != null and hud.has_method("is_chat_open") and hud.is_chat_open()


func _unhandled_input(event: InputEvent) -> void:
	if _is_chat_open():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * mouse_sens)
		camera.rotate_x(-event.relative.y * mouse_sens)
		camera.rotation.x = clampf(camera.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# Clicking to re-capture the mouse shouldn't also immediately
			# break/place — grace window skips the continuous action loop
			# until the button has likely been released.
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_capture_cooldown = CAPTURE_GRACE
			get_viewport().set_input_as_handled()
			return

		if world == null:
			return

		# Middle-click pick is single-shot and stays event-driven. LMB/RMB are
		# handled in _physics_process so they fire continuously while held.
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			var ray_origin: Vector3 = camera.global_position
			var ray_dir: Vector3 = -camera.global_basis.z
			var hit: Dictionary = world.raycast_voxel(ray_origin, ray_dir)
			if hit.get("hit", false) and hud != null:
				var block: int = hit["block"]
				if block == Chunk.Block.WORLD_BEDROCK:
					get_viewport().set_input_as_handled()
					return
				var found: bool = false
				for i: int in hud.slots.size():
					if hud.slots[i] == block:
						hud.selected_slot = i
						hud.get_node("Hotbar").queue_redraw()
						found = true
						break
				if not found:
					hud.set_selected_block(block)
			get_viewport().set_input_as_handled()


## Get the player's axis-aligned bounding box in world space.
## Used to prevent placing blocks inside the player. global_position is at the
## player's feet, so the box spans from the feet up 1.8 blocks to the head.
func _get_player_aabb() -> AABB:
	return AABB(global_position + Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 1.8, 0.6))


func _physics_process(delta: float) -> void:
	# Block all gameplay input while the chat bar is focused so typing
	# doesn't fire break/place or trigger movement.
	var chat_open: bool = _is_chat_open()
	# Continuous break/place. Holding LMB keeps breaking, RMB keeps placing,
	# both paced by ACTION_COOLDOWN. The first click fires immediately because
	# cooldowns start at 0. Capture grace prevents the click that re-captures
	# a released mouse cursor from also triggering an action.
	_break_cooldown = maxf(0.0, _break_cooldown - delta)
	_place_cooldown = maxf(0.0, _place_cooldown - delta)
	_capture_cooldown = maxf(0.0, _capture_cooldown - delta)
	var lmb: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not chat_open
	var rmb: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not chat_open
	if world != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _capture_cooldown <= 0.0:
		# Press-edge fires immediately (rapid clicking works), held fires on
		# cooldown expiry (steady ~5 Hz auto-repeat like Minecraft creative).
		var lmb_edge: bool = lmb and not _lmb_held_last
		var rmb_edge: bool = rmb and not _rmb_held_last
		if lmb and (lmb_edge or _break_cooldown <= 0.0):
			var ray_origin: Vector3 = camera.global_position
			var ray_dir: Vector3 = -camera.global_basis.z
			world.break_block(ray_origin, ray_dir)
			_break_cooldown = ACTION_COOLDOWN
		if rmb and (rmb_edge or _place_cooldown <= 0.0):
			var ray_origin: Vector3 = camera.global_position
			var ray_dir: Vector3 = -camera.global_basis.z
			var player_aabb := _get_player_aabb()
			var block_type: int = hud.get_selected_block() if hud != null else Chunk.Block.STONE
			world.place_block(ray_origin, ray_dir, block_type, player_aabb)
			_place_cooldown = ACTION_COOLDOWN
	_lmb_held_last = lmb
	_rmb_held_last = rmb

	# Double-tap Space → toggle flying (Minecraft creative).
	# Disabled by the settings toggle? Then skip the double-tap logic
	# entirely — Space stays a plain jump.
	if not chat_open and flying_enabled and Input.is_action_just_pressed(&"jump"):
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _last_jump_time < DOUBLE_JUMP_WINDOW:
			is_flying = not is_flying
			velocity.y = 0.0
			# Entering flight cancels crouch — `descend` (Ctrl) is now the
			# fly-down action and we don't want a latched crouch lingering.
			_crouch_latched = false
			is_crouching = false
			# Reset to avoid a triple-tap also toggling back.
			_last_jump_time = -999.0
		else:
			_last_jump_time = now

	var on_floor: bool = is_on_floor() and not is_flying

	# Input direction — resolved first because sprint Hold mode de-latches
	# when the player stops moving.
	var input_dir: Vector2
	if chat_open:
		input_dir = Vector2.ZERO
	else:
		input_dir = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	var wish_dir := (head.global_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var moving: bool = wish_dir.length_squared() > 0.01

	# --- Sprint latching (Hold vs Toggle) ---
	if not chat_open:
		if sprint_toggle_mode:
			if Input.is_action_just_pressed(&"sprint"):
				_sprint_latched = not _sprint_latched
			is_sprinting = _sprint_latched and moving
		else:
			if not moving:
				_sprint_latched = false
			elif Input.is_action_pressed(&"sprint"):
				_sprint_latched = true
			is_sprinting = _sprint_latched
	else:
		is_sprinting = false

	# --- Crouch latching (Hold vs Toggle) ---
	if chat_open:
		is_crouching = false
	elif is_flying:
		is_crouching = false
	elif crouch_toggle_mode:
		if Input.is_action_just_pressed(&"descend"):
			_crouch_latched = not _crouch_latched
		is_crouching = _crouch_latched
	else:
		is_crouching = Input.is_action_pressed(&"descend")
	if is_crouching:
		is_sprinting = false

	# Vertical movement.
	if is_flying:
		var vy: float = 0.0
		if not chat_open and Input.is_action_pressed(&"jump"):
			vy += FLY_VERTICAL_SPEED
		if not chat_open and Input.is_action_pressed(&"descend"):
			vy -= FLY_VERTICAL_SPEED
		velocity.y = vy
	else:
		# Gravity + held-jump-on-ground (Minecraft-style autojump pattern).
		if not on_floor:
			velocity.y -= GRAVITY * delta
		if not chat_open and on_floor and Input.is_action_pressed(&"jump"):
			velocity.y = JUMP_VELOCITY

	# Speed — crouch overrides walk/sprint; flight has its own ladder.
	var speed: float
	if is_flying:
		speed = FLY_SPEED * 2.0 if is_sprinting else FLY_SPEED
	elif is_crouching:
		speed = CROUCH_SPEED
	else:
		speed = SPRINT_SPEED if is_sprinting else WALK_SPEED

	# Minecraft-style momentum. Flight uses the crisp ground rate so control
	# feels precise; in-air (falling) preserves momentum at the low air rate.
	var target_x: float = wish_dir.x * speed
	var target_z: float = wish_dir.z * speed
	var rate: float
	if is_flying:
		rate = GROUND_ACCEL_RATE
	else:
		rate = GROUND_ACCEL_RATE if on_floor else AIR_ACCEL_RATE
	var t: float = 1.0 - exp(-rate * delta)
	velocity.x = lerp(velocity.x, target_x, t)
	velocity.z = lerp(velocity.z, target_z, t)

	# Crouch ledge safety: project velocity a short distance ahead and, if
	# that would strand the player over air, zero the offending component so
	# they can't walk off a ledge. Exception: if the block directly under
	# the player is a slab, allow walking off (only a half-block drop).
	if is_crouching and on_floor:
		_apply_crouch_ledge_safety()

	# Step-up (only meaningful when walking on the ground). Disabled while
	# crouching — sneak should not auto-hop up ledges.
	if on_floor and not is_crouching and moving:
		_try_step_up(wish_dir)

	# --- Crouch head dip smoothing ---
	# Ease `_crouch_smooth` toward the target crouch offset so the camera
	# glides down/up rather than snapping.
	var crouch_target: float = CROUCH_HEAD_DROP if is_crouching else 0.0
	if not is_equal_approx(_crouch_smooth, crouch_target):
		var tc: float = 1.0 - exp(-CROUCH_SMOOTH_RATE * delta)
		_crouch_smooth = lerpf(_crouch_smooth, crouch_target, tc)
		if absf(_crouch_smooth - crouch_target) < 0.0005:
			_crouch_smooth = crouch_target

	# Blend any accumulated step-up head offset back toward zero. The final
	# head y is the base minus both the step-up residual and the crouch dip,
	# so step-ups while crouched compose cleanly.
	if _step_head_offset > 0.0001:
		var t2: float = 1.0 - exp(-STEP_SMOOTH_RATE * delta)
		_step_head_offset = lerpf(_step_head_offset, 0.0, t2)
	elif _step_head_offset != 0.0:
		_step_head_offset = 0.0
	head.position.y = _head_base_y - _step_head_offset - _crouch_smooth

	# --- Sprint FOV bump ---
	# Smoothly lerp camera.fov to base_fov * multiplier while sprinting,
	# back to base_fov otherwise. Rate chosen to feel like Minecraft's quick
	# zoom without being snappy.
	var target_fov: float = base_fov * SPRINT_FOV_MULT if is_sprinting else base_fov
	if not is_equal_approx(camera.fov, target_fov):
		camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-FOV_LERP_RATE * delta))

	move_and_slide()

	# Block outline raycast — ran at 60 Hz (physics rate) rather than render
	# rate to avoid per-frame dict lookups at 1500+ fps.
	_update_block_outline()

	# Underwater overlay — check whether the camera is inside a water cell.
	_update_underwater()


var _was_underwater: bool = false
var _was_in_lava: bool = false
func _update_underwater() -> void:
	if world == null or hud == null:
		return
	var cp: Vector3 = camera.global_position
	var b: int = world.get_voxel(int(floor(cp.x)), int(floor(cp.y)), int(floor(cp.z)))
	var in_water: bool = b == Chunk.Block.WATER
	var in_lava: bool = b == Chunk.Block.LAVA
	if in_water != _was_underwater:
		_was_underwater = in_water
		if hud.has_method("set_underwater"):
			hud.set_underwater(in_water)
	if in_lava != _was_in_lava:
		_was_in_lava = in_lava
		if hud.has_method("set_in_lava"):
			hud.set_in_lava(in_lava)


func _update_block_outline() -> void:
	if world == null or block_outline == null:
		return
	var ray_origin: Vector3 = camera.global_position
	var ray_dir: Vector3 = -camera.global_basis.z
	var hit: Dictionary = world.raycast_voxel(ray_origin, ray_dir)
	if not hit.get("hit", false):
		if _outline_visible:
			block_outline.hide_outline()
			_outline_visible = false
		return
	var pos: Vector3i = hit["position"]
	if not _outline_visible or pos != _outline_last_pos:
		block_outline.show_at(pos)
		_outline_last_pos = pos
		_outline_visible = true


func _try_step_up(wish_dir: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position
	var step_up: Vector3 = from + Vector3.UP * STEP_HEIGHT
	var step_forward: Vector3 = step_up + wish_dir * 0.4

	# Check room above
	var up_params := PhysicsRayQueryParameters3D.create(from, step_up)
	up_params.exclude = [get_rid()]
	if space.intersect_ray(up_params):
		return

	# Check ledge is clear at step height
	var fwd_params := PhysicsRayQueryParameters3D.create(step_up, step_forward)
	fwd_params.exclude = [get_rid()]
	if space.intersect_ray(fwd_params):
		return

	# Find step surface
	var down_params := PhysicsRayQueryParameters3D.create(step_forward, step_forward + Vector3.DOWN * (STEP_HEIGHT + 0.1))
	down_params.exclude = [get_rid()]
	var down_result: Dictionary = space.intersect_ray(down_params)
	if down_result and down_result.position.y > global_position.y + 0.05:
		var delta_y: float = down_result.position.y - global_position.y
		global_position.y = down_result.position.y
		velocity.y = 0.0
		# Push the head down by the step so the camera glides back up over
		# the next frames (see _decay_step_smoothing). Compose with the
		# current crouch dip so a step-up while crouched still looks right.
		_step_head_offset += delta_y
		head.position.y = _head_base_y - _step_head_offset - _crouch_smooth


# --- Crouch ledge safety helpers ---

## Project the player's velocity a short distance ahead and, if that would
## strand us over air, zero the offending horizontal component. Exception:
## if the block directly under the player is a slab, allow walking off
## (slabs are half-blocks — the drop is safe).
func _apply_crouch_ledge_safety() -> void:
	if world == null:
		return
	# "It is a slab" exception — `it` being the block currently underfoot.
	var under_b: int = _voxel_at(global_position.x, global_position.y - 0.05, global_position.z)
	if under_b == Chunk.Block.SMOOTH_STONE_SLAB:
		return

	# Look-ahead constant comfortably longer than one physics tick of travel
	# at sneak speed, so the player stops well before committing to a fall.
	const LOOK_AHEAD: float = 0.12
	var fx: float = global_position.x + velocity.x * LOOK_AHEAD
	var fz: float = global_position.z + velocity.z * LOOK_AHEAD
	if _has_ground_support(fx, fz):
		return
	# Axis-separable probe so the player can still slide along an edge
	# (e.g. walking east along a north-facing cliff).
	var x_only: bool = _has_ground_support(fx, global_position.z)
	var z_only: bool = _has_ground_support(global_position.x, fz)
	if x_only and not z_only:
		velocity.z = 0.0
	elif z_only and not x_only:
		velocity.x = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0


## Does any of the player's 4 footprint corners at (x, z) have a solid
## block directly below? Any single supporting corner is enough — the
## player AABB is 0.6 wide so you can stand with one corner on a block.
func _has_ground_support(x: float, z: float) -> bool:
	if world == null:
		return true
	var y_below: int = int(floor(global_position.y - 0.05))
	for dx: float in [-0.3, 0.3]:
		for dz: float in [-0.3, 0.3]:
			var bx: int = int(floor(x + dx))
			var bz: int = int(floor(z + dz))
			var b: int = world.get_voxel(bx, y_below, bz)
			if _is_solid_support(b):
				return true
	return false


## Which blocks count as "you're standing on it" for sneak-ledge purposes.
## Non-solids (air, fluids, fire, flowers) don't — everything else does,
## including slabs (half-blocks are still a standing surface).
func _is_solid_support(b: int) -> bool:
	if b == Chunk.Block.AIR:
		return false
	if b == Chunk.Block.WATER or b == Chunk.Block.LAVA:
		return false
	if b == Chunk.Block.FIRE:
		return false
	if b == Chunk.Block.DANDELION or b == Chunk.Block.POPPY or b == Chunk.Block.TORCH:
		return false
	if b == Chunk.Block.NETHER_PORTAL:
		return false
	return true


func _voxel_at(x: float, y: float, z: float) -> int:
	if world == null:
		return 0
	return world.get_voxel(int(floor(x)), int(floor(y)), int(floor(z)))
