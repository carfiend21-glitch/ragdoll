-- Blood splatter. It's only drawn on your own screen (it's just for looks),
-- so it doesn't slow down the server. Drops fly out, fall, and leave splats
-- where they land on the walls, floor and ceiling.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ShopItems = require(Shared.ShopItems)

local Blood = {}

local MAX_SPLATS = 300
local DROP_LIFETIME = 3
local CLASSIC_BLOOD = ShopItems.byId.ClassicBlood

local folder = nil
local drops = {} -- flying drops: { part, velocity, room (CFrame), age, style }
local splats = {} -- oldest first, so the oldest get cleaned up first

local function getFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "BloodFx"
		folder.Parent = Workspace
	end
	return folder
end

-- `style` = a blood style from ShopItems (the room owner's, bought with Noob Bucks)
local function newBlob(shape, size, cframe, style)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = ShopItems.bloodColor(style)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = getFolder()
	return part
end

-- A flat round splat on a surface of a room. `position` and `normal` are in the room's
-- own directions (X across, Y up, Z toward the camera); `normal` points out of the
-- surface, into the room.
local function splat(room, position, normal, diameter, style)
	local side = normal:Cross(if math.abs(normal.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis).Unit
	-- The back wall has a stripe sticking out a little, so sit further off it
	local lift = if normal.Z > 0.9 then 0.25 else 0.04
	local cframe = room
		* CFrame.fromMatrix(position + normal * lift, normal, side)
		* CFrame.Angles(math.random() * math.pi * 2, 0, 0)
	table.insert(splats, newBlob(Enum.PartType.Cylinder, Vector3.new(0.05, diameter, diameter), cframe, style))
	if #splats > MAX_SPLATS then
		table.remove(splats, 1):Destroy()
	end
end

-- Sprays blood from `position` in room number `room`. `amount` is the damage done.
function Blood.spray(room, position, amount)
	if not Config.BLOOD_ENABLED then
		return
	end
	-- Worked out in the room's own directions, whichever way round the ring it faces
	local roomCFrame = Config.getRoomCFrame(room)
	local roomModel = Workspace:FindFirstChild("Rooms") and Workspace.Rooms:FindFirstChild("Room" .. room)
	local style = roomModel and ShopItems.byId[roomModel:GetAttribute("BloodStyle")] or CLASSIC_BLOOD
	for _ = 1, math.clamp(math.floor(amount / 4), 3, 14) do
		local velocity = Vector3.new((math.random() - 0.5) * 24, math.random() * 15 + 3, (math.random() - 0.5) * 5)
		local size = 0.15 + math.random() * 0.25
		local part = newBlob(Enum.PartType.Ball, Vector3.one * size, CFrame.new(position), style)
		table.insert(drops, {
			part = part,
			velocity = roomCFrame:VectorToWorldSpace(velocity),
			room = roomCFrame,
			age = 0,
			style = style,
		})
	end

	-- Splash on the back wall right behind the hit: the part you see most
	local size = Config.ROOM_SIZE
	local hit = roomCFrame:PointToObjectSpace(position)
	for _ = 1, math.clamp(math.floor(amount / 10), 1, 5) do
		local x = math.clamp(hit.X + (math.random() - 0.5) * 3, -size.X / 2, size.X / 2)
		local y = math.clamp(hit.Y + (math.random() - 0.5) * 3, 0, size.Y)
		splat(roomCFrame, Vector3.new(x, y, -size.Z / 2), Vector3.zAxis, 0.4 + math.random() * math.min(amount / 15, 2), style)
	end
end

-- Removes all blood (between rounds)
function Blood.clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
	drops = {}
	splats = {}
end

-- Moves the flying drops; when one reaches a wall, floor or ceiling it becomes a splat
RunService.RenderStepped:Connect(function(dt)
	local size = Config.ROOM_SIZE
	local gravity = Vector3.new(0, -Config.NOOB_GRAVITY, 0) -- same gentle gravity as the noob
	for index = #drops, 1, -1 do
		local drop = drops[index]
		drop.age += dt
		drop.velocity += gravity * dt
		local position = drop.part.Position + drop.velocity * dt
		-- Where it is in the room's own directions (X across, Y up, Z toward the camera)
		local p = drop.room:PointToObjectSpace(position)

		local normal = nil
		if p.Y <= 0 then
			normal, p = Vector3.yAxis, Vector3.new(p.X, 0, p.Z)
		elseif p.Y >= size.Y then
			normal, p = -Vector3.yAxis, Vector3.new(p.X, size.Y, p.Z)
		elseif p.X <= -size.X / 2 then
			normal, p = Vector3.xAxis, Vector3.new(-size.X / 2, p.Y, p.Z)
		elseif p.X >= size.X / 2 then
			normal, p = -Vector3.xAxis, Vector3.new(size.X / 2, p.Y, p.Z)
		elseif p.Z <= -size.Z / 2 then
			normal, p = Vector3.zAxis, Vector3.new(p.X, p.Y, -size.Z / 2)
		end

		if normal then
			splat(drop.room, p, normal, drop.part.Size.X * 2.5, drop.style)
		end
		if normal or drop.age > DROP_LIFETIME then
			drop.part:Destroy()
			table.remove(drops, index)
		else
			drop.part.Position = position
		end
	end
end)

return Blood
