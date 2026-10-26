-- Builds the lobby and the rooms with code, so the Studio place file can stay
-- empty and everything lives in git.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local WorldBuilder = {}

-- density, friction, elasticity (bounciness), friction weight, elasticity weight
local WALL_PHYSICS = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)

local function newPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Decoration the noob passes straight through
local function newDecor(parent, name, size, cframe, color, material)
	local part = newPart(parent, name, size, cframe, color, material)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

local function newSign(part, face, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
	return label
end

function WorldBuilder.buildLobby()
	-- New places come with their own spawn point; we use the lobby's instead
	for _, child in Workspace:GetDescendants() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local top = Config.LOBBY_POSITION

	newPart(lobby, "Floor", Vector3.new(60, 2, 60), CFrame.new(top - Vector3.new(0, 1, 0)), Color3.fromRGB(120, 200, 255))
	newPart(lobby, "Rim", Vector3.new(64, 1.6, 64), CFrame.new(top - Vector3.new(0, 1.3, 0)), Color3.fromRGB(255, 200, 40))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(top + Vector3.new(0, 0.5, 10))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby

	-- Title sign at the back of the lobby, facing the spawn
	local sign = newPart(lobby, "Sign", Vector3.new(26, 7, 1), CFrame.new(top + Vector3.new(0, 7, -26)), Color3.fromRGB(35, 40, 60))
	newSign(sign, Enum.NormalId.Back, "RAGDOLL NOOB\nHurt the noob. Earn achievements!", Color3.fromRGB(255, 220, 60))
	for _, x in { -11, 11 } do
		newPart(lobby, "Post", Vector3.new(1, 4, 1), CFrame.new(top + Vector3.new(x, 2, -26)), Color3.fromRGB(35, 40, 60))
	end

	lobby.Parent = Workspace
end

-- Returns a list of { model = Model, label = TextLabel } for each room
function WorldBuilder.buildRooms()
	local folder = Instance.new("Folder")
	folder.Name = "Rooms"

	local size, t = Config.ROOM_SIZE, Config.WALL_THICKNESS
	local W, H, D = size.X, size.Y, size.Z
	local rooms = {}

	for index = 1, Config.ROOM_COUNT do
		local origin = Config.getRoomOrigin(index)
		local room = Instance.new("Model")
		room.Name = "Room" .. index

		-- `kind` is what the noob hit, used for achievements ("Floor", "Wall", "Ceiling")
		local function surface(name, kind, partSize, offset, color, material)
			local part = newPart(room, name, partSize, CFrame.new(origin + offset), color, material)
			part.CustomPhysicalProperties = WALL_PHYSICS
			if kind then
				part:SetAttribute("Surface", kind)
			end
			return part
		end

		local cream = Color3.fromRGB(245, 238, 215)
		surface("Floor", "Floor", Vector3.new(W + 2 * t, t, D + 2 * t), Vector3.new(0, -t / 2, 0), Color3.fromRGB(160, 110, 70), Enum.Material.WoodPlanks)
		surface("Ceiling", "Ceiling", Vector3.new(W + 2 * t, t, D + 2 * t), Vector3.new(0, H + t / 2, 0), Color3.fromRGB(200, 200, 205))
		surface("LeftWall", "Wall", Vector3.new(t, H, D), Vector3.new(-W / 2 - t / 2, H / 2, 0), Color3.fromRGB(230, 220, 195))
		surface("RightWall", "Wall", Vector3.new(t, H, D), Vector3.new(W / 2 + t / 2, H / 2, 0), Color3.fromRGB(230, 220, 195))
		surface("BackWall", nil, Vector3.new(W + 2 * t, H, t), Vector3.new(0, H / 2, -D / 2 - t / 2), cream)

		-- Invisible front wall: you look in through it, the noob can't fall out
		local glass = surface("Glass", nil, Vector3.new(W + 2 * t, H, t), Vector3.new(0, H / 2, D / 2 + t / 2), Color3.new(1, 1, 1))
		glass.Transparency = 1
		glass.CastShadow = false
		glass.CanQuery = false

		-- Stripe along the bottom of the back wall
		newDecor(room, "Stripe", Vector3.new(W, 4, 0.2), CFrame.new(origin + Vector3.new(0, 2, -D / 2 + 0.1)), Color3.fromRGB(90, 140, 200))

		-- Name sign at the top of the back wall
		local signPart = newDecor(room, "Sign", Vector3.new(22, 2.5, 0.2), CFrame.new(origin + Vector3.new(0, H - 2.5, -D / 2 + 0.1)), Color3.fromRGB(35, 40, 60))
		local label = newSign(signPart, Enum.NormalId.Back, "ROOM " .. index, Color3.new(1, 1, 1))

		for _, x in { -W / 4, W / 4 } do
			local lamp = newDecor(room, "Lamp", Vector3.new(4, 0.4, 2), CFrame.new(origin + Vector3.new(x, H - 0.2, 0)), Color3.fromRGB(255, 250, 230), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 40
			light.Brightness = 1.2
			light.Parent = lamp
		end

		local items = Instance.new("Folder")
		items.Name = "Items"
		items.Parent = room

		room.Parent = folder
		rooms[index] = { model = room, label = label }
	end

	folder.Parent = Workspace
	return rooms
end

return WorldBuilder
