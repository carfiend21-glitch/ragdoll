-- After each round, plays back every room side by side (speeding up from 2x to 4x), so all
-- players can watch each other. Shows everything that happened: the noob, the
-- weapons, arrows and rockets flying, arrows sticking in, explosions, blood,
-- torn-off limbs, damage numbers, and when players pressed PLAY / STOP / RESTART.
-- Each replay has a damage counter, and the player in the lead gets a crown.
-- The server sends each room's recording in pieces during the round (see server/Recorder).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemModels = require(Shared.ItemModels)

local player = Players.LocalPlayer

local FOV = 25
local S = Config.NOOB_SCALE
local FONT = Enum.Font.FredokaOne
local TITLE_FONT = Enum.Font.LuckiestGuy
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(38, 40, 48)
local ORANGE = Color3.fromRGB(240, 140, 30)
local GOLD = Color3.fromRGB(255, 205, 50)
local RED = Color3.fromRGB(230, 60, 50)
local BLOOD = { Color3.fromRGB(150, 0, 0), Color3.fromRGB(120, 0, 5), Color3.fromRGB(175, 10, 10) }
local NOOB_COLORS = {
	Torso = BrickColor.new("Bright blue").Color,
	Head = BrickColor.new("Bright yellow").Color,
	["Left Arm"] = BrickColor.new("Bright yellow").Color,
	["Right Arm"] = BrickColor.new("Bright yellow").Color,
	["Left Leg"] = BrickColor.new("Br. yellowish green").Color,
	["Right Leg"] = BrickColor.new("Br. yellowish green").Color,
}
local NOOB_SIZES = {
	Torso = Vector3.new(2, 2, 1),
	Head = Vector3.new(2, 1, 1),
	["Left Arm"] = Vector3.new(1, 2, 1),
	["Right Arm"] = Vector3.new(1, 2, 1),
	["Left Leg"] = Vector3.new(1, 2, 1),
	["Right Leg"] = Vector3.new(1, 2, 1),
}
local CHARRED = Color3.fromRGB(35, 30, 28)
local SAW_SPIN = 12 -- radians per second, like the real saw
local MAX_SPLATS = 120 -- per replay
local MAX_POPUPS = 6 -- per replay

local Replay = {}

local recordings = {} -- [room number] = { name, frames, events }
local order = {} -- room numbers, in the order players were given rooms
local gui = nil
local connection = nil
local currentSpeed = Config.REPLAY_SPEEDS[1] -- how fast the replays are playing right now

-- Adds `new` to `list`, keeping it in recorded order (`n`) and skipping anything already there
local function merge(list, new)
	for _, entry in new do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.n < b.n
	end)
	for index = #list, 2, -1 do
		if list[index].n == list[index - 1].n then
			table.remove(list, index)
		end
	end
end

-- A new round started: forget the old recordings
function Replay.reset(roster)
	recordings = {}
	order = {}
	for _, entry in roster do
		recordings[entry.room] = { name = entry.name, frames = {}, events = {} }
		table.insert(order, entry.room)
	end
end

function Replay.addPiece(room, frames, events)
	local recording = recordings[room]
	if recording then
		merge(recording.frames, frames)
		merge(recording.events, events)
	end
end

---------------------------------------------------------------------------
-- Building the little 3D rooms
---------------------------------------------------------------------------

local function newPart(parent, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A copy of the test room (same look as server/WorldBuilder), with its floor center at 0,0,0
local function buildRoom(parent)
	local size = Config.ROOM_SIZE
	local W, H, D = size.X, size.Y, size.Z
	local wall = Color3.fromRGB(205, 208, 214)
	newPart(parent, Vector3.new(W + 2, 1, D), CFrame.new(0, -0.5, 0), Color3.fromRGB(95, 98, 105), Enum.Material.DiamondPlate)
	newPart(parent, Vector3.new(W + 2, 1, D), CFrame.new(0, H + 0.5, 0), Color3.fromRGB(175, 178, 185))
	newPart(parent, Vector3.new(1, H, D), CFrame.new(-W / 2 - 0.5, H / 2, 0), wall)
	newPart(parent, Vector3.new(1, H, D), CFrame.new(W / 2 + 0.5, H / 2, 0), wall)
	newPart(parent, Vector3.new(W + 2, H + 2, 1), CFrame.new(0, H / 2, -D / 2 - 0.5), Color3.fromRGB(232, 234, 238))
	newPart(parent, Vector3.new(W, 1.5, 0.2), CFrame.new(0, 0.75, -D / 2 + 0.1), Color3.fromRGB(150, 153, 160))
	for _, x in { -W / 4, W / 4 } do
		newPart(parent, Vector3.new(4, 0.4, 2), CFrame.new(x, H - 0.2, 0), Color3.fromRGB(235, 232, 220))
	end
end

-- A classic noob (just for show, no physics). Returns its parts in Config.NOOB_PART_ORDER.
local function buildNoob(parent)
	local parts = {}
	for index, name in Config.NOOB_PART_ORDER do
		local part = newPart(parent, NOOB_SIZES[name] * S, CFrame.new(0, -100, 0), NOOB_COLORS[name])
		part.Name = name
		parts[index] = part
	end
	local head = parts[2]
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	return parts
end

local function label(props)
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = props.Font or FONT
	textLabel.TextScaled = true
	textLabel.TextColor3 = props.TextColor3 or WHITE
	textLabel.TextStrokeTransparency = props.TextStrokeTransparency or 0.2
	textLabel.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	textLabel.AnchorPoint = props.AnchorPoint or Vector2.zero
	textLabel.Position = props.Position
	textLabel.Size = props.Size
	textLabel.Text = props.Text or ""
	textLabel.ZIndex = props.ZIndex or 1
	textLabel.Parent = props.Parent
	return textLabel
end

local function corner(parent, radius)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function buildCell(parent, room, recording)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = DARK
	frame.Parent = parent
	corner(frame, 10)
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.Color = Color3.fromRGB(70, 72, 85)
	border.Parent = frame

	local nameLabel = label({
		Position = UDim2.fromOffset(12, 3),
		Size = UDim2.new(1, -24, 0, 30),
		Font = TITLE_FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	local viewport = Instance.new("ViewportFrame")
	viewport.Position = UDim2.fromOffset(6, 36)
	viewport.Size = UDim2.new(1, -12, 1, -42)
	viewport.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	-- Soft light from the front-top, like the real room
	viewport.Ambient = Color3.fromRGB(150, 150, 158)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-0.25, -0.8, -0.55)
	viewport.Parent = frame
	corner(viewport, 8)
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	buildRoom(viewport)

	local counter = label({
		Position = UDim2.new(0, 12, 1, -52),
		Size = UDim2.fromOffset(240, 46),
		Font = TITLE_FONT,
		TextColor3 = ORANGE,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "💥 0",
		ZIndex = 3,
		Parent = viewport,
	})
	local counterScale = Instance.new("UIScale")
	counterScale.Parent = counter

	-- Shows when the player pressed PLAY, STOP or RESTART
	local status = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(170, 32),
		Font = TITLE_FONT,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0,
		Text = "⏸ PAUSED",
		ZIndex = 3,
		Parent = viewport,
	})
	if #recording.frames == 0 then
		label({ Position = UDim2.fromScale(0, 0.4), Size = UDim2.new(1, 0, 0, 40), Text = "No replay", Parent = viewport })
	end

	return {
		room = room,
		recording = recording,
		viewport = viewport,
		camera = camera,
		border = border,
		nameLabel = nameLabel,
		counter = counter,
		counterScale = counterScale,
		status = status,
		noobParts = buildNoob(viewport),
		items = {}, -- [item id] = model
		projectiles = {}, -- [kind] = reusable models for things in flight
		stuck = {}, -- things glued to body parts (arrows, stumps): { part = index, offset, model }
		splats = {},
		drops = {},
		popups = {},
		running = false, -- every room starts paused
		restartShownUntil = -1,
		frameIndex = 1,
		eventIndex = 1,
		damage = 0,
		shownDamage = 0,
		lastT = 0,
	}
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------

-- Where a point in the room shows up in the cell, in pixels (for the floating damage numbers)
local function toPixels(cell, position)
	local pixels = cell.viewport.AbsoluteSize
	local cameraPosition = cell.camera.CFrame.Position
	local depth = cameraPosition.Z - position.Z
	local scale = (pixels.Y / 2) / (depth * math.tan(math.rad(FOV / 2)))
	return Vector2.new(
		pixels.X / 2 + (position.X - cameraPosition.X) * scale,
		pixels.Y / 2 - (position.Y - cameraPosition.Y) * scale
	)
end

-- An orange fireball with a puff of smoke behind it
local function boom(cell, position, radius)
	local speed = 1 / currentSpeed
	local fire = newPart(cell.viewport, Vector3.one, CFrame.new(position), Color3.fromRGB(255, 170, 50), Enum.Material.Neon, Enum.PartType.Ball)
	fire.Transparency = 0.05
	TweenService:Create(fire, TweenInfo.new(0.6 * speed), { Size = Vector3.one * radius, Transparency = 1 }):Play()
	local smoke = newPart(cell.viewport, Vector3.one * 2, CFrame.new(position + Vector3.new(0, 0, -1)), Color3.fromRGB(90, 90, 95), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	smoke.Transparency = 0.3
	TweenService:Create(smoke, TweenInfo.new(2 * speed), {
		Size = Vector3.one * radius * 1.3,
		Transparency = 1,
		CFrame = CFrame.new(position + Vector3.new(0, radius * 0.4, -1)),
	}):Play()
	task.delay(2 * speed + 0.1, function()
		fire:Destroy()
		smoke:Destroy()
	end)
end

-- A flat round splat of blood on a surface (`normal` points into the room)
local function splat(cell, position, normal, diameter)
	local side = normal:Cross(if math.abs(normal.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis).Unit
	local lift = if normal.Z > 0.9 then 0.25 else 0.04 -- clear of the stripe on the back wall
	local cframe = CFrame.fromMatrix(position + normal * lift, normal, side)
	local part = newPart(cell.viewport, Vector3.new(0.05, diameter, diameter), cframe, BLOOD[math.random(#BLOOD)], nil, Enum.PartType.Cylinder)
	table.insert(cell.splats, part)
	if #cell.splats > MAX_SPLATS then
		table.remove(cell.splats, 1):Destroy()
	end
end

local function bleed(cell, position, points)
	if not Config.BLOOD_ENABLED then
		return
	end
	local size = Config.ROOM_SIZE
	for _ = 1, math.clamp(math.floor(points / 10), 1, 4) do
		local x = math.clamp(position.X + (math.random() - 0.5) * 3, -size.X / 2, size.X / 2)
		local y = math.clamp(position.Y + (math.random() - 0.5) * 3, 0, size.Y)
		splat(cell, Vector3.new(x, y, -size.Z / 2), Vector3.zAxis, 0.4 + math.random() * math.min(points / 15, 2))
	end
	for _ = 1, math.clamp(math.floor(points / 6), 2, 8) do
		local drop = newPart(cell.viewport, Vector3.one * (0.2 + math.random() * 0.2), CFrame.new(position), BLOOD[1], nil, Enum.PartType.Ball)
		local velocity = Vector3.new((math.random() - 0.5) * 24, math.random() * 15 + 3, (math.random() - 0.5) * 5)
		table.insert(cell.drops, { part = drop, velocity = velocity, age = 0 })
	end
end

-- Moves flying blood drops; they splat when they land
local function updateDrops(cell, dt)
	local size = Config.ROOM_SIZE
	for index = #cell.drops, 1, -1 do
		local drop = cell.drops[index]
		drop.age += dt
		drop.velocity += Vector3.new(0, -Config.NOOB_GRAVITY, 0) * dt
		local position = drop.part.Position + drop.velocity * dt
		local normal = nil
		if position.Y <= 0 then
			normal, position = Vector3.yAxis, Vector3.new(position.X, 0, position.Z)
		elseif math.abs(position.X) >= size.X / 2 then
			local sideX = math.sign(position.X) * size.X / 2
			normal, position = Vector3.new(-math.sign(position.X), 0, 0), Vector3.new(sideX, position.Y, position.Z)
		end
		if normal then
			splat(cell, position, normal, drop.part.Size.X * 2.5)
		end
		if normal or drop.age > 3 then
			drop.part:Destroy()
			table.remove(cell.drops, index)
		else
			drop.part.Position = position
		end
	end
end

-- "-15 HEAD" floating up from where the noob got hit
local function popup(cell, position, points, partName)
	local spot = toPixels(cell, position)
	local text = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(spot.X, spot.Y),
		Size = UDim2.fromOffset(180, 26),
		Font = TITLE_FONT,
		TextColor3 = Color3.fromRGB(255, 230, 80),
		TextStrokeTransparency = 0,
		Text = ("-%s %s"):format(Config.formatScore(points), partName:upper()),
		ZIndex = 4,
		Parent = cell.viewport,
	})
	local rise = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(text, rise, {
		Position = UDim2.fromOffset(spot.X, spot.Y - 40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	table.insert(cell.popups, text)
	if #cell.popups > MAX_POPUPS then
		table.remove(cell.popups, 1):Destroy()
	end
	task.delay(1, function()
		local index = table.find(cell.popups, text)
		if index then
			table.remove(cell.popups, index)
		end
		text:Destroy()
	end)
end

-- Glues a model or part onto body part number `partIndex` for the rest of this noob's life
local function attach(cell, partIndex, offset, object)
	object.Parent = cell.viewport
	table.insert(cell.stuck, { part = partIndex, offset = offset, object = object })
end

-- Red patches where a limb was torn off (on the torso, and on the limb)
local function addStumps(cell, partIndex)
	local info = Config.BODY_PARTS_BY_NAME[Config.NOOB_PART_ORDER[partIndex]]
	if not info.stump or not Config.BLOOD_ENABLED then
		return
	end
	for _, spot in { { 1, info.stump.torso }, { partIndex, info.stump.part } } do
		local patch = newPart(nil, spot[2][2] * S, CFrame.new(), BLOOD[1])
		attach(cell, spot[1], CFrame.new(spot[2][1] * S), patch)
	end
end

local function clearStuck(cell)
	for _, stuck in cell.stuck do
		stuck.object:Destroy()
	end
	cell.stuck = {}
end

---------------------------------------------------------------------------
-- Playing it back
---------------------------------------------------------------------------

-- Points the cell's camera straight into the room so the room fills it
local function fitCamera(cell)
	local size = Config.ROOM_SIZE
	local pixels = cell.viewport.AbsoluteSize
	local aspect = pixels.X / math.max(pixels.Y, 1)
	local tanHalf = math.tan(math.rad(FOV / 2))
	local distance = math.max(size.Y / (2 * tanHalf), size.X / (2 * tanHalf * aspect)) * 1.03
	cell.camera.CFrame = CFrame.new(0, size.Y / 2, size.Z / 2 + distance)
end

local function blend(from, to, alpha)
	-- A big jump means something was replaced (a fresh noob), so don't slide across the room
	return if (from.Position - to.Position).Magnitude > 15 then from else from:Lerp(to, alpha)
end

-- Arrows, rockets and bullets in flight: reuse models, matching them up in order between snapshots
local function updateProjectiles(cell, a, b, alpha)
	local counts = {}
	local nextByKind = {}
	for _, entry in b.projectiles or {} do
		nextByKind[entry[1]] = nextByKind[entry[1]] or {}
		table.insert(nextByKind[entry[1]], entry[2])
	end
	for _, entry in a.projectiles or {} do
		local kind, cframe = entry[1], entry[2]
		counts[kind] = (counts[kind] or 0) + 1
		cell.projectiles[kind] = cell.projectiles[kind] or {}
		local pool = cell.projectiles[kind]
		local model = pool[counts[kind]]
		if not model then
			model = ItemModels.buildProjectile(kind)
			pool[counts[kind]] = model
		end
		local target = nextByKind[kind] and nextByKind[kind][counts[kind]]
		model:PivotTo(if target then blend(cframe, target, alpha) else cframe)
		model.Parent = cell.viewport
	end
	for kind, pool in cell.projectiles do
		for index = (counts[kind] or 0) + 1, #pool do
			pool[index].Parent = nil
		end
	end
end

-- A blast of flame from the flamethrower: glowing puffs rushing forward
local function flame(cell, position, direction)
	local seconds = 0.6 / currentSpeed
	for step = 1, 6 do
		local puff = newPart(cell.viewport, Vector3.one * 0.6, CFrame.new(position), Color3.fromRGB(255, 140 + step * 15, 40), Enum.Material.Neon, Enum.PartType.Ball)
		puff.Transparency = 0.15
		TweenService:Create(puff, TweenInfo.new(seconds), {
			Position = position + direction * (step * 2),
			Size = Vector3.one * (0.8 + step * 0.45),
			Transparency = 1,
		}):Play()
		task.delay(seconds + 0.05, function()
			puff:Destroy()
		end)
	end
end

-- A laser beam (a white-hot core in a red glow) that flashes, thins out and fades,
-- with a burst of light where it hits
local function laser(cell, from, to)
	local seconds = 0.35 / currentSpeed
	local length = (to - from).Magnitude
	local cframe = CFrame.lookAt(from:Lerp(to, 0.5), to)
	local glow = newPart(cell.viewport, Vector3.new(0.7, 0.7, length), cframe, Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
	glow.Transparency = 0.45
	local core = newPart(cell.viewport, Vector3.new(0.22, 0.22, length), cframe, Color3.fromRGB(255, 225, 225), Enum.Material.Neon)
	local flash = newPart(cell.viewport, Vector3.one * 0.6, CFrame.new(to), Color3.fromRGB(255, 120, 90), Enum.Material.Neon, Enum.PartType.Ball)
	for _, part in { glow, core } do
		TweenService:Create(part, TweenInfo.new(seconds), { Size = Vector3.new(0, 0, length), Transparency = 1 }):Play()
	end
	TweenService:Create(flash, TweenInfo.new(seconds), { Size = Vector3.one * 3, Transparency = 1 }):Play()
	task.delay(seconds + 0.05, function()
		glow:Destroy()
		core:Destroy()
		flash:Destroy()
	end)
end

-- Resets the noob's colors (a fresh noob isn't burnt)
local function resetColors(cell)
	for index, part in cell.noobParts do
		part.Color = NOOB_COLORS[Config.NOOB_PART_ORDER[index]]
	end
end

local function handleEvent(cell, event)
	local kind = event.kind
	if kind == "damage" then
		cell.damage = event.damage
	elseif kind == "boom" then
		boom(cell, event.position, event.radius)
	elseif kind == "hit" then
		bleed(cell, event.position, event.damage or event.points) -- blood goes by the real damage
		popup(cell, event.position, event.points, event.part)
	elseif kind == "arrow" and event.part then
		local arrow = ItemModels.buildArrow()
		attach(cell, event.part, event.offset, arrow)
	elseif kind == "torn" then
		addStumps(cell, event.part)
	elseif kind == "burn" and event.part then
		local name = Config.NOOB_PART_ORDER[event.part]
		cell.noobParts[event.part].Color = NOOB_COLORS[name]:Lerp(CHARRED, event.scorched)
	elseif kind == "flame" then
		flame(cell, event.position, event.direction)
	elseif kind == "laser" then
		laser(cell, event.position, event.target)
	elseif kind == "play" then
		cell.running = true
	elseif kind == "pause" then
		cell.running = false
	elseif kind == "restart" then
		cell.running = false
		cell.restartShownUntil = event.t + 1.5
		clearStuck(cell) -- fresh noob: no arrows, stumps or burns
		resetColors(cell)
	end
end

-- Moves everything in one cell to how it was at time `t` of the round
local function updateCell(cell, t)
	fitCamera(cell)
	local dt = math.max(t - cell.lastT, 0)
	cell.lastT = t
	local frames = cell.recording.frames
	if #frames == 0 then
		return
	end
	while cell.frameIndex < #frames and frames[cell.frameIndex + 1].t <= t do
		cell.frameIndex += 1
	end
	local a = frames[cell.frameIndex]
	local b = frames[math.min(cell.frameIndex + 1, #frames)]
	local alpha = if b.t > a.t then math.clamp((t - a.t) / (b.t - a.t), 0, 1) else 0

	-- Smoothly move between the two nearest snapshots
	for index, part in cell.noobParts do
		local from, to = a.noob[index], b.noob[index]
		if from and to then
			part.CFrame = blend(from, to, alpha)
		end
	end
	for _, stuck in cell.stuck do
		local part = cell.noobParts[stuck.part]
		stuck.object:PivotTo(part.CFrame * stuck.offset)
	end

	-- Weapons
	local nextItems = {}
	for _, entry in b.items do
		nextItems[entry[1]] = entry[3]
	end
	local seen = {}
	for _, entry in a.items do
		local id, weaponId, cframe = entry[1], entry[2], entry[3]
		seen[id] = true
		local model = cell.items[id]
		if not model then
			model = ItemModels.build(weaponId)
			model.Parent = cell.viewport
			cell.items[id] = model
		end
		local pivot = if nextItems[id] then blend(cframe, nextItems[id], alpha) else cframe
		model:PivotTo(pivot)
		if weaponId == "Saw" then
			-- Spin the blade (the recording only has where the saw is, not its spin)
			local spin = pivot * CFrame.Angles(0, 0, -SAW_SPIN * dt) * pivot:Inverse()
			for _, part in model:GetChildren() do
				if part.Name == "Blade" or part.Name == "Tooth" or part.Name == "Hub" then
					part.CFrame = spin * part.CFrame
				end
			end
		end
	end
	for id, model in cell.items do
		if not seen[id] then
			model:Destroy()
			cell.items[id] = nil
		end
	end

	updateProjectiles(cell, a, b, alpha)

	local events = cell.recording.events
	while cell.eventIndex <= #events and events[cell.eventIndex].t <= t do
		handleEvent(cell, events[cell.eventIndex])
		cell.eventIndex += 1
	end
	updateDrops(cell, dt)

	-- Damage counter (pops when it goes up)
	if cell.damage ~= cell.shownDamage then
		cell.shownDamage = cell.damage
		cell.counter.Text = "💥 " .. Config.formatScore(cell.damage)
		cell.counterScale.Scale = 1.3
		TweenService:Create(cell.counterScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	if t < cell.restartShownUntil then
		cell.status.Text = "↺ RESTART"
		cell.status.TextColor3 = ORANGE
	else
		cell.status.Text = if cell.running then "▶ PLAY" else "⏸ PAUSED"
		cell.status.TextColor3 = if cell.running then Color3.fromRGB(90, 220, 110) else RED
	end
end

function Replay.play()
	Replay.stop()
	if #order == 0 then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "Replay"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10 -- above everything else
	gui.Parent = player:WaitForChild("PlayerGui")

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	background.Active = true
	background.Parent = gui
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.fromRGB(35, 36, 48), Color3.fromRGB(12, 12, 16))
	shade.Parent = background

	local speedLabel = label({
		Position = UDim2.new(0, 16, 0, 62),
		Size = UDim2.new(0.6, 0, 0, 44),
		Font = TITLE_FONT,
		TextColor3 = ORANGE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = background,
	})
	local speedScale = Instance.new("UIScale")
	speedScale.Parent = speedLabel
	local shownSpeed = nil
	local clock = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 62),
		Size = UDim2.fromOffset(200, 44),
		Font = TITLE_FONT,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = background,
	})

	-- How far through the replays we are
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.new(0, 16, 1, -10)
	track.Size = UDim2.new(1, -32, 0, 8)
	track.BackgroundColor3 = Color3.fromRGB(55, 57, 68)
	track.Parent = background
	corner(track, 4)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = ORANGE
	fill.Parent = track
	corner(fill, 4)

	local columns = if #order == 1 then 1 else 2
	local rows = math.ceil(#order / columns)
	local grid = Instance.new("Frame")
	grid.Position = UDim2.fromOffset(12, 114)
	grid.Size = UDim2.new(1, -24, 1, -138)
	grid.BackgroundTransparency = 1
	grid.Parent = background
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / columns, -12, 1 / rows, -12)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local cells = {}
	local duration = 0
	for _, room in order do
		local recording = recordings[room]
		table.insert(cells, buildCell(grid, room, recording))
		local last = recording.frames[#recording.frames]
		duration = math.max(duration, if last then last.t else 0)
	end

	local startTime = os.clock()
	connection = RunService.RenderStepped:Connect(function()
		local t
		t, currentSpeed = Config.replayProgress(os.clock() - startTime, duration)
		if currentSpeed ~= shownSpeed then
			-- "REPLAYS 2x >>", then 3x >>>, then 4x >>>>, with a little pop each time it speeds up
			shownSpeed = currentSpeed
			speedLabel.Text = ("REPLAYS  %dx %s"):format(currentSpeed, string.rep(">", currentSpeed))
			speedScale.Scale = 1.25
			TweenService:Create(speedScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		local best = 0
		for _, cell in cells do
			updateCell(cell, t)
			best = math.max(best, cell.damage)
		end
		for _, cell in cells do
			local leading = best > 0 and cell.damage == best
			cell.nameLabel.Text = ("%sROOM %d: %s"):format(if leading then "👑 " else "", cell.room, cell.recording.name)
			cell.nameLabel.TextColor3 = if leading then GOLD else WHITE
			cell.border.Color = if leading then GOLD else Color3.fromRGB(70, 72, 85)
		end
		local seconds = math.floor(t)
		clock.Text = ("⏱ %d:%02d"):format(seconds // 60, seconds % 60)
		fill.Size = UDim2.fromScale(if duration > 0 then t / duration else 0, 1)
	end)
end

function Replay.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
end

return Replay
