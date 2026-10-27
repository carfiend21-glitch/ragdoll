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

local function newShape(parent, name, shape, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Shape = shape
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

-- Cylinders lie on their side by default; this stands them up
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- Lobby colors: soft pastels with neon accents
local LOBBY = {
	floor = Color3.fromRGB(235, 230, 242),
	center = Color3.fromRGB(70, 60, 110),
	neonCyan = Color3.fromRGB(90, 230, 255),
	neonPink = Color3.fromRGB(255, 110, 200),
	dark = Color3.fromRGB(45, 40, 70),
	gold = Color3.fromRGB(255, 200, 60),
	blossom = { Color3.fromRGB(255, 183, 213), Color3.fromRGB(255, 160, 200), Color3.fromRGB(255, 205, 225) },
	bark = Color3.fromRGB(110, 75, 55),
	cushions = { Color3.fromRGB(255, 170, 200), Color3.fromRGB(150, 230, 210) },
	lamp = Color3.fromRGB(255, 220, 160),
}
local LOBBY_RADIUS = 46

-- The classic noob's clothes: yellow skin, blue shirt, green pants
local STATUE_COLORS = {
	Torso = BrickColor.new("Bright blue").Color,
	Head = BrickColor.new("Bright yellow").Color,
	["Left Arm"] = BrickColor.new("Bright yellow").Color,
	["Right Arm"] = BrickColor.new("Bright yellow").Color,
	["Left Leg"] = BrickColor.new("Br. yellowish green").Color,
	["Right Leg"] = BrickColor.new("Br. yellowish green").Color,
}

-- A big classic noob in its noob clothes, one arm up in victory, standing at `feet`
local function buildStatue(lobby, feet)
	local base = CFrame.new(feet) * CFrame.Angles(0, math.pi, 0) -- facing the spawn
	local parts = {
		{ "Torso", Vector3.new(4, 4, 2), CFrame.new(0, 6, 0) },
		{ "Head", Vector3.new(4, 2, 2), CFrame.new(0, 9, 0) },
		{ "Left Arm", Vector3.new(2, 4, 2), CFrame.new(-3, 6, 0) },
		-- Raised arm: swung up around the shoulder
		{ "Right Arm", Vector3.new(2, 4, 2), CFrame.new(3, 7, 0) * CFrame.Angles(0, 0, math.rad(160)) * CFrame.new(0, -1, 0) },
		{ "Left Leg", Vector3.new(2, 4, 2), CFrame.new(-1, 2, 0) },
		{ "Right Leg", Vector3.new(2, 4, 2), CFrame.new(1, 2, 0) },
	}
	for _, spec in parts do
		local part = newPart(lobby, "Statue " .. spec[1], spec[2], base * spec[3], STATUE_COLORS[spec[1]])
		if spec[1] == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Parent = part
			local face = Instance.new("Decal")
			face.Texture = "rbxasset://textures/face.png"
			face.Face = Enum.NormalId.Front
			face.Parent = part
		end
	end
end

-- A comfy two-seat couch facing `lookAt`
local function buildCouch(lobby, position, lookAt, cushion)
	local frame = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
	newPart(lobby, "Couch", Vector3.new(8, 1.4, 3), frame * CFrame.new(0, 0.7, 0), LOBBY.dark)
	newPart(lobby, "Couch", Vector3.new(8, 3.2, 0.8), frame * CFrame.new(0, 1.6, 1.3), cushion)
	for _, x in { -3.7, 3.7 } do
		newPart(lobby, "Couch", Vector3.new(0.8, 2.2, 3), frame * CFrame.new(x, 1.1, 0), cushion)
	end
	for _, x in { -1.7, 1.7 } do
		local seat = Instance.new("Seat")
		seat.Name = "Seat"
		seat.Size = Vector3.new(3.2, 0.4, 2.4)
		seat.CFrame = frame * CFrame.new(x, 1.6, -0.2)
		seat.Color = cushion
		seat.Material = Enum.Material.Fabric
		seat.Anchored = true
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.Parent = lobby
	end
end

-- A pink cherry blossom tree in a little planter
local function buildTree(lobby, position)
	newShape(lobby, "Planter", Enum.PartType.Cylinder, Vector3.new(1.2, 5, 5), CFrame.new(position + Vector3.new(0, 0.6, 0)) * UPRIGHT, LOBBY.dark)
	newShape(lobby, "Trunk", Enum.PartType.Cylinder, Vector3.new(9, 1.2, 1.2), CFrame.new(position + Vector3.new(0, 5, 0)) * UPRIGHT, LOBBY.bark, Enum.Material.Wood)
	local blobs = { Vector3.new(0, 10, 0), Vector3.new(2.2, 9, 1), Vector3.new(-2, 9.2, -1.2), Vector3.new(0.5, 8.6, -2.2), Vector3.new(-1, 11, 1.5) }
	for index, offset in blobs do
		local size = 5 + (index % 3)
		newShape(lobby, "Blossom", Enum.PartType.Ball, Vector3.one * size, CFrame.new(position + offset), LOBBY.blossom[index % 3 + 1])
	end
end

-- A lamp post with a warm glowing bulb
local function buildLamp(lobby, position)
	newPart(lobby, "LampPost", Vector3.new(0.5, 9, 0.5), CFrame.new(position + Vector3.new(0, 4.5, 0)), LOBBY.dark, Enum.Material.Metal)
	local bulb = newShape(lobby, "Bulb", Enum.PartType.Ball, Vector3.one * 1.6, CFrame.new(position + Vector3.new(0, 9.3, 0)), LOBBY.lamp, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = LOBBY.lamp
	light.Brightness = 1.5
	light.Range = 18
	light.Parent = bulb
end

-- A standing leaderboard (facing the spawn). Returns its 10 row labels.
local function buildLeaderboard(lobby, position, titleText, accent)
	local board = newPart(lobby, "Leaderboard", Vector3.new(10, 12, 0.6), CFrame.new(position + Vector3.new(0, 8, 0)), Color3.fromRGB(20, 18, 30))
	newPart(lobby, "LeaderboardGlow", Vector3.new(10.6, 12.6, 0.3), CFrame.new(position + Vector3.new(0, 8, -0.35)), accent, Enum.Material.Neon)
	newPart(lobby, "LeaderboardPost", Vector3.new(0.8, 2, 0.8), CFrame.new(position + Vector3.new(0, 1, 0)), LOBBY.dark, Enum.Material.Metal)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the side facing the spawn
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.14)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = accent
	title.Text = titleText
	title.Parent = gui

	local rows = {}
	for index = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.new(0.06, 0, 0.16 + (index - 1) * 0.082, 0)
		row.Size = UDim2.new(0.88, 0, 0.072, 0)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		-- Gold, silver and bronze for the top 3
		row.TextColor3 = ({ Color3.fromRGB(255, 210, 70), Color3.fromRGB(215, 220, 230), Color3.fromRGB(225, 150, 90) })[index]
			or Color3.new(1, 1, 1)
		row.Text = ("%d. ---"):format(index)
		row.Parent = gui
		rows[index] = row
	end
	return rows
end

-- The "HOW TO PLAY" board: short steps for new players. Stands at `position` (its
-- feet), facing `lookAt`.
local HOW_TO_PLAY = {
	"🧍 Each round you get your <b>own room</b> and a noob. You have <b>%d seconds</b>.",
	"🛒 Pick weapons from the <b>bottom bar</b> and drag them into your room.",
	"▶️ Press <b>PLAY</b>: weapons fire by themselves. Smash the noob for <b>points</b>!",
	"💥 Combos, air time and torn-off limbs earn more points and cash.",
	"🏆 Most points wins the round and a <b>Noob Buck</b> 💵.",
	"🔓 Earn <b>achievements</b> to unlock new weapons. Drag weapons to 🗑️ to sell them.",
}

local function buildHowToPlay(lobby, position, lookAt)
	local facing = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
	local board = newPart(lobby, "HowToPlay", Vector3.new(16, 9, 0.6), facing * CFrame.new(0, 5.5, 0), Color3.fromRGB(20, 18, 30))
	newPart(lobby, "HowToPlayGlow", Vector3.new(16.6, 9.6, 0.3), facing * CFrame.new(0, 5.5, 0.35), LOBBY.neonCyan, Enum.Material.Neon)
	for _, x in { -6, 6 } do
		newPart(lobby, "HowToPlayPost", Vector3.new(0.8, 1, 0.8), facing * CFrame.new(x, 0.5, 0), LOBBY.dark, Enum.Material.Metal)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- the side facing `lookAt`
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromScale(0, 0.02)
	title.Size = UDim2.fromScale(1, 0.17)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = LOBBY.neonCyan
	title.Text = "HOW TO PLAY"
	title.Parent = gui
	for index, line in HOW_TO_PLAY do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.new(0.04, 0, 0.2 + (index - 1) * 0.13, 0)
		row.Size = UDim2.new(0.92, 0, 0.115, 0)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.FredokaOne
		row.RichText = true
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.new(1, 1, 1)
		row.Text = line:format(Config.ROUND_TIME)
		row.Parent = gui
	end
end

-- Builds the lobby. Returns { screen, winsRows, runRows, sequenceRows }: the big screen's
-- text, and the rows of the three global leaderboards.
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
	local R = LOBBY_RADIUS

	-- Round plaza with glowing neon edges
	newShape(lobby, "Floor", Enum.PartType.Cylinder, Vector3.new(2, R * 2, R * 2), CFrame.new(top - Vector3.new(0, 1, 0)) * UPRIGHT, LOBBY.floor)
	newShape(lobby, "Rim", Enum.PartType.Cylinder, Vector3.new(1.6, R * 2 + 2, R * 2 + 2), CFrame.new(top - Vector3.new(0, 1.1, 0)) * UPRIGHT, LOBBY.neonCyan, Enum.Material.Neon)
	newShape(lobby, "CenterGlow", Enum.PartType.Cylinder, Vector3.new(0.1, 50, 50), CFrame.new(top + Vector3.new(0, 0.05, 0)) * UPRIGHT, LOBBY.neonPink, Enum.Material.Neon)
	newShape(lobby, "Center", Enum.PartType.Cylinder, Vector3.new(0.2, 48, 48), CFrame.new(top + Vector3.new(0, 0.1, 0)) * UPRIGHT, LOBBY.center)

	-- Glass railing all the way round
	for index = 1, 32 do
		local angle = index / 32 * math.pi * 2
		local spot = top + Vector3.new(math.sin(angle) * (R - 0.5), 1.5, math.cos(angle) * (R - 0.5))
		local rail = newPart(lobby, "Railing", Vector3.new(9.2, 3, 0.4), CFrame.lookAt(spot, Vector3.new(top.X, spot.Y, top.Z)), Color3.fromRGB(200, 240, 255), Enum.Material.Glass)
		rail.Transparency = 0.6
	end

	for index, angle in { 45, 135, 225, 315 } do
		local rad = math.rad(angle)
		buildCouch(lobby, top + Vector3.new(math.sin(rad) * 17, 0, math.cos(rad) * 17), top, LOBBY.cushions[index % 2 + 1])
	end
	for index = 1, 6 do
		local angle = (index / 6 + 1 / 12) * math.pi * 2
		buildTree(lobby, top + Vector3.new(math.sin(angle) * 36, 0, math.cos(angle) * 36))
	end
	for index = 1, 8 do
		local angle = index / 8 * math.pi * 2
		buildLamp(lobby, top + Vector3.new(math.sin(angle) * (R - 3), 0, math.cos(angle) * (R - 3)))
	end

	-- Sparkles drifting down over the plaza
	local sky = newPart(lobby, "Sparkles", Vector3.new(R * 1.6, 1, R * 1.6), CFrame.new(top + Vector3.new(0, 28, 0)), Color3.new(1, 1, 1))
	sky.Transparency = 1
	sky.CanCollide = false
	sky.CanQuery = false
	sky.CanTouch = false
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.EmissionDirection = Enum.NormalId.Bottom
	sparkles.Color = ColorSequence.new(LOBBY.blossom[1], LOBBY.neonCyan)
	sparkles.LightEmission = 0.6
	sparkles.Size = NumberSequence.new(0.35)
	sparkles.Transparency = NumberSequence.new(0.2, 1)
	sparkles.Lifetime = NumberRange.new(8, 12)
	sparkles.Speed = NumberRange.new(1, 2.5)
	sparkles.Rate = 8
	sparkles.RotSpeed = NumberRange.new(-30, 30)
	sparkles.Parent = sky

	-- The big screen, at the far side facing the spawn
	local screen = newPart(lobby, "Screen", Vector3.new(30, 12, 1), CFrame.new(top + Vector3.new(0, 12, -32)), Color3.fromRGB(20, 18, 30))
	newPart(lobby, "ScreenGlow", Vector3.new(31, 13, 0.6), CFrame.new(top + Vector3.new(0, 12, -32.6)), LOBBY.neonCyan, Enum.Material.Neon)
	for _, x in { -12, 12 } do
		newPart(lobby, "ScreenLeg", Vector3.new(1, 6, 1), CFrame.new(top + Vector3.new(x, 3, -32)), LOBBY.dark, Enum.Material.Metal)
	end
	-- The noob statue stands on top of the screen, right in the middle
	buildStatue(lobby, top + Vector3.new(0, 18.5, -32))
	local title = newSign(screen, Enum.NormalId.Back, "RAGDOLL PVP", Color3.fromRGB(255, 200, 60))
	title.Font = Enum.Font.LuckiestGuy
	title.Size = UDim2.fromScale(1, 0.4)
	local status = Instance.new("TextLabel")
	status.Position = UDim2.fromScale(0.05, 0.45)
	status.Size = UDim2.fromScale(0.9, 0.5)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.FredokaOne
	status.TextScaled = true
	status.TextColor3 = Color3.new(1, 1, 1)
	status.Text = "WAITING FOR PLAYERS"
	status.Parent = title.Parent

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(top + Vector3.new(0, 0.5, 30)) -- facing the statue and screen
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = LOBBY.cushions[2]
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby

	-- Global leaderboards side by side in the middle of the lobby, facing the spawn
	local winsRows = buildLeaderboard(lobby, top + Vector3.new(-12, 0, -2), "🏆 MOST WINS", LOBBY.gold)
	local sequenceRows = buildLeaderboard(lobby, top + Vector3.new(0, 0, -2), "🎬 BEST SEQUENCES", LOBBY.neonCyan)
	local runRows = buildLeaderboard(lobby, top + Vector3.new(12, 0, -2), "💥 MOST POINTS", LOBBY.neonPink)

	-- "How to play" right behind the spawn (in front of room 1), facing the spawn
	buildHowToPlay(lobby, top + Vector3.new(0, 0, 38.5), top + Vector3.new(0, 0, 30))

	-- Invisible walls all the way round, tall enough that nobody can jump off the lobby
	for index = 1, 32 do
		local angle = index / 32 * math.pi * 2
		local spot = top + Vector3.new(math.sin(angle) * (R + 0.3), 20, math.cos(angle) * (R + 0.3))
		local wall = newPart(lobby, "InvisibleWall", Vector3.new(9.4, 40, 1), CFrame.lookAt(spot, Vector3.new(top.X, spot.Y, top.Z)), Color3.new(1, 1, 1))
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CanTouch = false
		wall.CastShadow = false
	end

	lobby.Parent = Workspace
	return { screen = status, winsRows = winsRows, runRows = runRows, sequenceRows = sequenceRows }
end

-- Returns a list of { model = Model, label = TextLabel } for each room
function WorldBuilder.buildRooms()
	local folder = Instance.new("Folder")
	folder.Name = "Rooms"

	local size, t = Config.ROOM_SIZE, Config.WALL_THICKNESS
	local W, H, D = size.X, size.Y, size.Z
	local rooms = {}

	for index = 1, Config.ROOM_COUNT do
		-- Everything below is laid out in the room's own directions (see Config.getRoomCFrame)
		local roomCFrame = Config.getRoomCFrame(index)
		local function at(offset)
			return roomCFrame * CFrame.new(offset)
		end
		local room = Instance.new("Model")
		room.Name = "Room" .. index

		-- `kind` is what the noob hit, used for achievements ("Floor", "Wall", "Ceiling")
		local function surface(name, kind, partSize, offset, color, material)
			local part = newPart(room, name, partSize, at(offset), color, material)
			part.CustomPhysicalProperties = WALL_PHYSICS
			if kind then
				part:SetAttribute("Surface", kind)
			end
			return part
		end

		-- A white/grey test lab, like the original game
		surface("Floor", "Floor", Vector3.new(W + 2 * t, t, D + 2 * t), Vector3.new(0, -t / 2, 0), Color3.fromRGB(95, 98, 105), Enum.Material.DiamondPlate)
		surface("Ceiling", "Ceiling", Vector3.new(W + 2 * t, t, D + 2 * t), Vector3.new(0, H + t / 2, 0), Color3.fromRGB(175, 178, 185))
		surface("LeftWall", "Wall", Vector3.new(t, H, D), Vector3.new(-W / 2 - t / 2, H / 2, 0), Color3.fromRGB(205, 208, 214))
		surface("RightWall", "Wall", Vector3.new(t, H, D), Vector3.new(W / 2 + t / 2, H / 2, 0), Color3.fromRGB(205, 208, 214))
		surface("BackWall", nil, Vector3.new(W + 2 * t, H, t), Vector3.new(0, H / 2, -D / 2 - t / 2), Color3.fromRGB(232, 234, 238))

		-- Invisible front wall: you look in through it, the noob can't fall out
		local glass = surface("Glass", nil, Vector3.new(W + 2 * t, H, t), Vector3.new(0, H / 2, D / 2 + t / 2), Color3.new(1, 1, 1))
		glass.Transparency = 1
		glass.CastShadow = false
		glass.CanQuery = false

		-- Stripe along the bottom of the back wall
		newDecor(room, "Stripe", Vector3.new(W, 1.5, 0.2), at(Vector3.new(0, 0.75, -D / 2 + 0.1)), Color3.fromRGB(150, 153, 160))

		-- "ROOM #" sign at the top of the back wall, big enough to read from the lobby,
		-- with whoever's playing in it written underneath during a round
		local signPart = newDecor(room, "Sign", Vector3.new(18, 3.6, 0.2), at(Vector3.new(0, H - 2.4, -D / 2 + 0.1)), Color3.fromRGB(35, 40, 60))
		newSign(signPart, Enum.NormalId.Back, "ROOM " .. index, Color3.new(1, 1, 1)).Size = UDim2.fromScale(1, 0.62)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.fromScale(0.05, 0.6)
		nameLabel.Size = UDim2.fromScale(0.9, 0.36)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.fromRGB(255, 205, 60)
		nameLabel.Text = ""
		nameLabel.Parent = signPart:FindFirstChildOfClass("SurfaceGui")

		-- Ceiling lamps are just for looks: real lights made the room glaringly bright
		for _, x in { -W / 4, W / 4 } do
			newDecor(room, "Lamp", Vector3.new(4, 0.4, 2), at(Vector3.new(x, H - 0.2, 0)), Color3.fromRGB(235, 232, 220))
		end

		local items = Instance.new("Folder")
		items.Name = "Items"
		items.Parent = room

		room.Parent = folder
		rooms[index] = { model = room, nameLabel = nameLabel }
	end

	folder.Parent = Workspace
	return rooms
end

return WorldBuilder
