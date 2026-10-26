-- Settings shared by the server and every player's device.
local RunService = game:GetService("RunService")

local Config = {}

-- Round timing, in seconds
Config.ROUND_TIME = 90
Config.INTERMISSION_TIME = if RunService:IsStudio() then 5 else 15
Config.RESULTS_TIME = 8

Config.ROOM_COUNT = 4
Config.MAX_ITEMS_PER_ROOM = 8

-- Weapon hits closer together than this (seconds) build a combo
Config.COMBO_WINDOW = 2
Config.MAX_COMBO_MULTIPLIER = 3

-- Inside size of each room: width (X), height (Y), depth (Z)
Config.ROOM_SIZE = Vector3.new(48, 27, 10)
Config.WALL_THICKNESS = 4

-- Top of the lobby floor
Config.LOBBY_POSITION = Vector3.new(0, 1, 0)

Config.DATASTORE_NAME = "RagdollNoob_PlayerData_v1"

-- Center of room `index`'s floor. Rooms sit in a row behind the lobby.
function Config.getRoomOrigin(index)
	return Vector3.new((index - (Config.ROOM_COUNT + 1) / 2) * 80, 2, -150)
end

-- Keeps a weapon of `size` inside room `index`, on the room's middle plane.
-- Floor weapons get snapped down onto the floor.
function Config.clampToRoom(index, worldPosition, size, onFloor)
	local origin = Config.getRoomOrigin(index)
	local room = Config.ROOM_SIZE
	local half = size / 2
	local relative = worldPosition - origin
	local x = math.clamp(relative.X, -room.X / 2 + half.X, room.X / 2 - half.X)
	local y = if onFloor then half.Y else math.clamp(relative.Y, half.Y, room.Y - half.Y)
	return origin + Vector3.new(x, y, 0)
end

return Config
