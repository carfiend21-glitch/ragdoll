-- Blood splatter. It's only drawn on your own screen (it's just for looks),
-- so it doesn't slow down the server. Drops fly out, fall, and leave splats
-- where they land on the walls, floor and ceiling.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Blood = {}

local MAX_SPLATS = 300
local DROP_LIFETIME = 3
local COLORS = {
	Color3.fromRGB(150, 0, 0),
	Color3.fromRGB(120, 0, 5),
	Color3.fromRGB(175, 10, 10),
}

local folder = nil
local drops = {} -- flying drops: { part, velocity, origin, age }
local splats = {} -- oldest first, so the oldest get cleaned up first

local function getFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "BloodFx"
		folder.Parent = Workspace
	end
	return folder
end

local function newBlob(shape, size, cframe)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = COLORS[math.random(#COLORS)]
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = getFolder()
	return part
end

-- A flat round splat on a surface. `normal` points out of the surface, into the room.
local function splat(position, normal, diameter)
	local side = normal:Cross(if math.abs(normal.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis).Unit
	-- The back wall has a stripe sticking out a little, so sit further off it
	local lift = if normal.Z > 0.9 then 0.25 else 0.04
	local cframe = CFrame.fromMatrix(position + normal * lift, normal, side)
		* CFrame.Angles(math.random() * math.pi * 2, 0, 0)
	table.insert(splats, newBlob(Enum.PartType.Cylinder, Vector3.new(0.05, diameter, diameter), cframe))
	if #splats > MAX_SPLATS then
		table.remove(splats, 1):Destroy()
	end
end

-- Sprays blood from `position` in room number `room`. `amount` is the damage done.
function Blood.spray(room, position, amount)
	if not Config.BLOOD_ENABLED then
		return
	end
	local origin = Config.getRoomOrigin(room)
	for _ = 1, math.clamp(math.floor(amount / 4), 3, 14) do
		local velocity = Vector3.new((math.random() - 0.5) * 24, math.random() * 15 + 3, (math.random() - 0.5) * 5)
		local size = 0.15 + math.random() * 0.25
		local part = newBlob(Enum.PartType.Ball, Vector3.one * size, CFrame.new(position))
		table.insert(drops, { part = part, velocity = velocity, origin = origin, age = 0 })
	end

	-- Splash on the back wall right behind the hit: the part you see most
	local size = Config.ROOM_SIZE
	local backZ = origin.Z - size.Z / 2
	for _ = 1, math.clamp(math.floor(amount / 10), 1, 5) do
		local x = math.clamp(position.X + (math.random() - 0.5) * 3, origin.X - size.X / 2, origin.X + size.X / 2)
		local y = math.clamp(position.Y + (math.random() - 0.5) * 3, origin.Y, origin.Y + size.Y)
		splat(Vector3.new(x, y, backZ), Vector3.zAxis, 0.4 + math.random() * math.min(amount / 15, 2))
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
		local o = drop.origin
		local relative = position - o

		local normal = nil
		if relative.Y <= 0 then
			normal, position = Vector3.yAxis, Vector3.new(position.X, o.Y, position.Z)
		elseif relative.Y >= size.Y then
			normal, position = -Vector3.yAxis, Vector3.new(position.X, o.Y + size.Y, position.Z)
		elseif relative.X <= -size.X / 2 then
			normal, position = Vector3.xAxis, Vector3.new(o.X - size.X / 2, position.Y, position.Z)
		elseif relative.X >= size.X / 2 then
			normal, position = -Vector3.xAxis, Vector3.new(o.X + size.X / 2, position.Y, position.Z)
		elseif relative.Z <= -size.Z / 2 then
			normal, position = Vector3.zAxis, Vector3.new(position.X, position.Y, o.Z - size.Z / 2)
		end

		if normal then
			splat(position, normal, drop.part.Size.X * 2.5)
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
