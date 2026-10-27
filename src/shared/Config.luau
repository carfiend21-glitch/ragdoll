-- Settings shared by the server and every player's device.
local Config = {}

-- Round timing, in seconds
Config.ROUND_TIME = 90
Config.INTERMISSION_TIME = 30 -- break in the lobby between rounds
Config.RESULTS_TIME = 8

-- Replays speed up as they go: the first third plays at 2x, the middle third at 3x
-- and the last third at 4x
Config.REPLAY_SPEEDS = { 2, 3, 4 }
-- How many snapshots per second get recorded
Config.REPLAY_SAMPLE_RATE = 15

-- For a replay `duration` seconds long (in round time): after `elapsed` real seconds
-- of watching, how far into the round we are, and the speed it's playing at right then
function Config.replayProgress(elapsed, duration)
	local part = duration / #Config.REPLAY_SPEEDS
	local t = 0
	for _, speed in Config.REPLAY_SPEEDS do
		local partSeconds = part / speed -- real seconds this third takes to watch
		if elapsed <= partSeconds then
			return t + elapsed * speed, speed
		end
		elapsed -= partSeconds
		t += part
	end
	return duration, Config.REPLAY_SPEEDS[#Config.REPLAY_SPEEDS]
end

-- How many real seconds it takes to watch a replay `duration` seconds long
function Config.replayWatchTime(duration)
	local total = 0
	for _, speed in Config.REPLAY_SPEEDS do
		total += duration / #Config.REPLAY_SPEEDS / speed
	end
	return total
end

Config.ROOM_COUNT = 8 -- one room per player (set the server size to 8 on the Creator Dashboard too)
Config.REPLAYS_SHOWN = 3 -- only the top 3 rooms (by points) get replayed after a round
Config.MAX_ITEMS_PER_ROOM = 8

-- Weapon hits closer together than this (seconds) build a combo
Config.COMBO_WINDOW = 2
Config.MAX_COMBO_MULTIPLIER = 3

-- Inside size of each room: width (X), height (Y), depth (Z).
-- Same shape as the original game's test room.
Config.ROOM_SIZE = Vector3.new(44, 27.5, 10)
Config.WALL_THICKNESS = 4

-- The noob is bigger than a normal Roblox character so it fills the room like the original dummy
Config.NOOB_SCALE = 1.5

-- Gravity for the noob only (Roblox's normal gravity is 196.2). Roblox's gravity is tuned
-- for small characters; for a body this big it looks far too fast and twitchy.
-- Lower = floatier and slower. The lobby keeps normal gravity.
Config.NOOB_GRAVITY = 70

-- Body parts and their hit points. When a `vital` part runs out, the noob is destroyed;
-- other parts get torn off at their `joint`.
-- `stump` = where the red patches go when it's torn off: on the torso, and on the part
-- itself, each as { position, size } (before NOOB_SCALE).
Config.BODY_PARTS = {
	{
		name = "Head",
		key = "Head",
		joint = "Neck",
		maxHealth = 100,
		vital = true,
		stump = {
			torso = { Vector3.new(0, 1.03, 0), Vector3.new(1.2, 0.08, 0.8) },
			part = { Vector3.new(0, -0.53, 0), Vector3.new(1.2, 0.08, 0.8) },
		},
	},
	{ name = "Torso", key = "Torso", maxHealth = 200, vital = true },
	{
		name = "Left Arm",
		key = "LeftArm",
		joint = "Left Shoulder",
		maxHealth = 80,
		stump = {
			torso = { Vector3.new(-1.03, 0.5, 0), Vector3.new(0.08, 0.9, 0.9) },
			part = { Vector3.new(0, 1.03, 0), Vector3.new(0.9, 0.08, 0.9) },
		},
	},
	{
		name = "Right Arm",
		key = "RightArm",
		joint = "Right Shoulder",
		maxHealth = 80,
		stump = {
			torso = { Vector3.new(1.03, 0.5, 0), Vector3.new(0.08, 0.9, 0.9) },
			part = { Vector3.new(0, 1.03, 0), Vector3.new(0.9, 0.08, 0.9) },
		},
	},
	{
		name = "Left Leg",
		key = "LeftLeg",
		joint = "Left Hip",
		maxHealth = 100,
		stump = {
			torso = { Vector3.new(-0.5, -1.03, 0), Vector3.new(0.9, 0.08, 0.9) },
			part = { Vector3.new(0, 1.03, 0), Vector3.new(0.9, 0.08, 0.9) },
		},
	},
	{
		name = "Right Leg",
		key = "RightLeg",
		joint = "Right Hip",
		maxHealth = 100,
		stump = {
			torso = { Vector3.new(0.5, -1.03, 0), Vector3.new(0.9, 0.08, 0.9) },
			part = { Vector3.new(0, 1.03, 0), Vector3.new(0.9, 0.08, 0.9) },
		},
	},
}
-- The order the noob's parts are stored in (server/Noob) and recorded for replays
Config.NOOB_PART_ORDER = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
Config.BODY_PARTS_BY_NAME = {}
for _, info in Config.BODY_PARTS do
	Config.BODY_PARTS_BY_NAME[info.name] = info
end

-- Seconds before a destroyed noob is replaced with a fresh one
Config.RESPAWN_DELAY = 2

-- Blood splatter. Turning this off makes the game more kid-friendly.
-- (Blood affects the age rating you get from Roblox's Maturity questionnaire.)
Config.BLOOD_ENABLED = true

-- Top of the lobby floor
Config.LOBBY_POSITION = Vector3.new(0, 1, 0)

Config.DATASTORE_NAME = "RagdollNoob_PlayerData_v1"

-- Money ($). Small numbers, like the original game. Weapon prices are in Weapons.luau,
-- achievement rewards in Achievements.luau.
-- Cash is NOT saved: everyone starts every round with STARTING_CASH, and earns more
-- during the round. Roughly $50 per run. Weapons get used up, so that cash goes on
-- replacing them, and the Flamethrower ($200) takes a few runs of saving up.
-- All income was raised 50% (user, 2026-10-26: progress felt too slow in a 90s round).
-- Prices stayed the same, so expensive weapons still can't just be spammed.
Config.STARTING_CASH = 150 -- enough for 3 crossbows ($36 each) and 2 bounce pads ($20)
Config.AIRTIME_CASH_PER_SECOND = 6 -- the longer the noob stays in the air, the more you earn
Config.DAMAGE_PER_CASH = 20 / 3 -- you get $1 straight away for every this much damage (~6.7)
Config.ACHIEVEMENT_CASH_MULTIPLIER = 1.5 -- achievement cash rewards are worth this much more

-- The score shown to players is the real damage times this, just so the numbers feel
-- huge and exciting. It changes nothing in the game itself: body part hit points, cash,
-- blood and sounds all still go by the real damage.
Config.SCORE_MULTIPLIER = 50

-- 1234567 -> "1,234,567" (big scores are easier to read with commas)
function Config.formatScore(score)
	local text = tostring(math.floor(score))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Same idea for money: every cash amount players see is the real amount times this,
-- so a crossbow shows as $900 instead of $36. Like the score, it's only for show:
-- prices, earnings and rewards all really work in the small numbers below.
Config.CASH_DISPLAY_MULTIPLIER = 25

-- 36 -> "$900"
function Config.formatCash(cash)
	return "$" .. Config.formatScore(cash * Config.CASH_DISPLAY_MULTIPLIER)
end

-- The rooms stand in a ring around the lobby, side by side with the corners of their
-- open fronts touching, and the fronts facing the lobby so you can watch every room from
-- there. There's a gap between the lobby's edge and the ring, so you can see the void below.
-- (The camera for a room looks across the lobby, so the lobby is hidden on your own
-- screen while you're in a round: see client/CameraController.)
-- How far a room's middle is from the middle of the lobby:
local ROOM_HALF_WIDTH = (Config.ROOM_SIZE.X + 2 * Config.WALL_THICKNESS) / 2
local RING_INSIDE = ROOM_HALF_WIDTH / math.tan(math.pi / Config.ROOM_COUNT) -- where the fronts meet
Config.ROOM_RING_RADIUS = RING_INSIDE + Config.WALL_THICKNESS + Config.ROOM_SIZE.Z / 2
Config.ROOM_FLOOR_Y = 2

-- The angle (in radians, 0 = toward +Z) of room `index` around the lobby
local function roomAngle(index)
	return (index - 1) / Config.ROOM_COUNT * math.pi * 2
end

-- Where room `index` is, and which way it faces. In the room's own directions
-- (its "room space"): X runs across the room, Y is up, and +Z points out of the
-- open front toward the camera (and the lobby). The position is the middle of its floor.
function Config.getRoomCFrame(index)
	local angle = roomAngle(index)
	local center = Config.LOBBY_POSITION
	local outward = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local position = Vector3.new(center.X, Config.ROOM_FLOOR_Y, center.Z) + outward * Config.ROOM_RING_RADIUS
	-- Looking away from the lobby means the back (-Z) faces out and the front (+Z) faces in
	return CFrame.lookAt(position, position + outward)
end

-- Which room a spot in the world is in (or nil if it isn't in one)
function Config.roomAt(position)
	local center = Config.LOBBY_POSITION
	local flat = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	local distance = flat.Magnitude
	if distance < RING_INSIDE - 2 or distance > RING_INSIDE + Config.ROOM_SIZE.Z + 2 * Config.WALL_THICKNESS + 2 then
		return nil
	end
	local step = math.pi * 2 / Config.ROOM_COUNT
	local angle = math.atan2(flat.X, flat.Z) % (math.pi * 2)
	return math.floor(angle / step + 0.5) % Config.ROOM_COUNT + 1
end

-- Center of room `index`'s floor
function Config.getRoomOrigin(index)
	return Config.getRoomCFrame(index).Position
end

-- Keeps a weapon of `size` inside room `index`, on the room's middle plane.
-- Floor weapons get snapped down onto the floor. Returns a world position.
function Config.clampToRoom(index, worldPosition, size, onFloor)
	local room = Config.getRoomCFrame(index)
	local roomSize = Config.ROOM_SIZE
	local half = size / 2
	local relative = room:PointToObjectSpace(worldPosition)
	local x = math.clamp(relative.X, -roomSize.X / 2 + half.X, roomSize.X / 2 - half.X)
	local y = if onFloor then half.Y else math.clamp(relative.Y, half.Y, roomSize.Y - half.Y)
	return room:PointToWorldSpace(Vector3.new(x, y, 0))
end

-- Sticks a flat weapon of `size` (its top facing up) onto whichever surface of
-- room `index` is closest to `worldPosition`: floor, ceiling or a side wall.
-- It's turned so its top faces into the room. Returns a CFrame.
function Config.snapToSurface(index, worldPosition, size)
	local roomCFrame = Config.getRoomCFrame(index)
	local room = Config.ROOM_SIZE
	local relative = roomCFrame:PointToObjectSpace(worldPosition)
	local halfLength, halfThickness = size.X / 2, size.Y / 2
	local alongFloor = math.clamp(relative.X, -room.X / 2 + halfLength, room.X / 2 - halfLength)
	local alongWall = math.clamp(relative.Y, halfLength, room.Y - halfLength)

	local surfaces = {
		{ distance = relative.Y, at = Vector3.new(alongFloor, halfThickness, 0), turn = 0 },
		{ distance = room.Y - relative.Y, at = Vector3.new(alongFloor, room.Y - halfThickness, 0), turn = math.pi },
		{ distance = relative.X + room.X / 2, at = Vector3.new(-room.X / 2 + halfThickness, alongWall, 0), turn = -math.pi / 2 },
		{ distance = room.X / 2 - relative.X, at = Vector3.new(room.X / 2 - halfThickness, alongWall, 0), turn = math.pi / 2 },
	}
	local nearest = surfaces[1]
	for _, surface in surfaces do
		if surface.distance < nearest.distance then
			nearest = surface
		end
	end
	return roomCFrame * CFrame.new(nearest.at) * CFrame.Angles(0, 0, nearest.turn)
end

-- Where (and which way round) a weapon goes when it's placed or dragged to
-- `worldPosition` in room `index`. Returns a CFrame, turned to face the way the room does.
function Config.placementFor(index, weapon, worldPosition)
	if weapon.anySurface then
		return Config.snapToSurface(index, worldPosition, weapon.size)
	end
	local position = Config.clampToRoom(index, worldPosition, weapon.size, weapon.onFloor)
	return CFrame.new(position) * Config.getRoomCFrame(index).Rotation
end

return Config
