-- Builds the 3D models for weapons/traps. The server uses them for the real
-- thing, and players' devices use them for the see-through "ghost" while placing.
-- Each model faces -Z (forward) and is centered on its invisible Hitbox.
local ItemModels = {}

local DARK_METAL = Color3.fromRGB(60, 65, 70)
local BLACK_METAL = Color3.fromRGB(35, 37, 42)
local STEEL = Color3.fromRGB(185, 190, 200)
local WOOD = Color3.fromRGB(140, 90, 45)
local DARK_WOOD = Color3.fromRGB(70, 45, 25)
local HAZARD_YELLOW = Color3.fromRGB(240, 200, 40)
local BRASS = Color3.fromRGB(215, 175, 70)

local function newPart(model, name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- A thin part stretched between two points (strings, legs, ...)
local function newStrut(model, name, from, to, thickness, color, material)
	local length = (to - from).Magnitude
	return newPart(model, name, Vector3.new(thickness, thickness, length), CFrame.lookAt(from:Lerp(to, 0.5), to), color, material)
end

-- An invisible box around the whole item: it's what you click and drag
local function newHitbox(model, size)
	local hitbox = newPart(model, "Hitbox", size, CFrame.new(), Color3.new(1, 1, 1))
	hitbox.Transparency = 1
	hitbox.CastShadow = false
	model.PrimaryPart = hitbox
	return hitbox
end

-- Cylinders lie on their side by default; this stands them up
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
-- ...and this points them forward (-Z)
local FORWARD = CFrame.Angles(0, math.rad(90), 0)

-- A proper arrow: wooden shaft, pointed metal head, red feathers. It points
-- forward (-Z), centered on the shaft. Two wedges back to back make each flat
-- triangle (the head and the feathers), so they show up nicely from the side.
-- Returns the shaft.
local function addArrow(model, cframe)
	local shaft = newPart(
		model,
		"Shaft",
		Vector3.new(2, 0.12, 0.12),
		cframe * FORWARD,
		Color3.fromRGB(150, 105, 60),
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	local function triangle(name, size, offset, color, material)
		local upper = Instance.new("WedgePart")
		local lower = Instance.new("WedgePart")
		for index, wedge in { upper, lower } do
			wedge.Name = name
			wedge.Size = size
			wedge.Color = color
			wedge.Material = material
			wedge.Anchored = true
			wedge.CanCollide = false
			wedge.CanTouch = false
			wedge.TopSurface = Enum.SurfaceType.Smooth
			wedge.BottomSurface = Enum.SurfaceType.Smooth
			local flip = if index == 2 then CFrame.Angles(0, 0, math.pi) else CFrame.new()
			local side = if index == 1 then 1 else -1
			wedge.CFrame = cframe * CFrame.new(0, side * (offset.Y + size.Y / 2), offset.Z) * flip
			wedge.Parent = model
		end
	end
	-- Head: wide at the back, sharp point at the front
	triangle("Head", Vector3.new(0.05, 0.2, 0.55), Vector3.new(0, 0, -1.27), Color3.fromRGB(175, 178, 185), Enum.Material.Metal)
	-- Feathers at the back, wide edge toward the back like real fletching
	triangle("Feather", Vector3.new(0.04, 0.22, 0.5), Vector3.new(0, 0.05, 0.75), Color3.fromRGB(205, 40, 40), Enum.Material.SmoothPlastic)
	return shaft
end

local builders = {}

function builders.Crossbow(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	newPart(model, "Stock", Vector3.new(0.5, 0.5, 3), CFrame.new(0, 0, 0.2), WOOD, Enum.Material.Wood)
	newPart(
		model,
		"Grip",
		Vector3.new(0.4, 0.9, 0.4),
		CFrame.new(0, -0.6, 0.9) * CFrame.Angles(math.rad(-20), 0, 0),
		WOOD,
		Enum.Material.Wood
	)
	-- The bow: a thick middle with two arms that sweep backwards
	newPart(model, "Bow", Vector3.new(0.8, 0.35, 0.45), CFrame.new(0, 0.1, -1.2), DARK_WOOD, Enum.Material.Wood)
	for _, side in { -1, 1 } do
		newPart(
			model,
			"BowArm",
			Vector3.new(1.5, 0.25, 0.35),
			CFrame.new(side * 1.1, 0.1, -1.05) * CFrame.Angles(0, math.rad(-side * 20), 0),
			DARK_WOOD,
			Enum.Material.Wood
		)
		-- The string runs from each arm's tip back to where the arrow sits
		local tip = Vector3.new(side * 1.82, 0.1, -0.8)
		newStrut(model, "String", tip, Vector3.new(0, 0.1, -0.3), 0.06, Color3.new(1, 1, 1))
	end
	-- A metal foot loop at the front, for pulling the string back
	newPart(model, "Stirrup", Vector3.new(0.6, 0.08, 0.4), CFrame.new(0, 0.05, -1.55), DARK_METAL, Enum.Material.Metal)
	addArrow(model, CFrame.new(0, 0.33, -0.3))
end

function builders.Mine(model)
	local hitbox = newHitbox(model, Vector3.new(3, 1, 3))
	hitbox.CanTouch = true -- the noob touching this sets it off
	newPart(
		model,
		"Body",
		Vector3.new(0.5, 2.6, 2.6),
		CFrame.new(0, -0.25, 0) * UPRIGHT,
		DARK_METAL,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	-- Yellow warning rim around the top edge
	newPart(
		model,
		"Rim",
		Vector3.new(0.12, 2.75, 2.75),
		CFrame.new(0, -0.08, 0) * UPRIGHT,
		HAZARD_YELLOW,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	newPart(
		model,
		"Button",
		Vector3.new(0.25, 0.9, 0.9),
		CFrame.new(0, 0.1, 0) * UPRIGHT,
		Color3.fromRGB(255, 50, 50),
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
end

function builders.BouncePad(model)
	newHitbox(model, Vector3.new(5, 1, 6))
	newPart(model, "Base", Vector3.new(5, 0.3, 6), CFrame.new(0, -0.35, 0), DARK_METAL, Enum.Material.Metal)
	-- Springs between the base and the pad
	for _, x in { -1.6, 1.6 } do
		for _, z in { -2.1, 2.1 } do
			newPart(model, "Spring", Vector3.new(0.36, 0.55, 0.55), CFrame.new(x, -0.02, z) * UPRIGHT, STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
			newPart(model, "Spring", Vector3.new(0.08, 0.65, 0.65), CFrame.new(x, -0.02, z) * UPRIGHT, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	local pad = newPart(
		model,
		"Pad",
		Vector3.new(4.4, 0.3, 5.4),
		CFrame.new(0, 0.3, 0),
		Color3.fromRGB(80, 220, 90),
		Enum.Material.Neon
	)
	pad.CanCollide = true -- the noob lands on it...
	pad.CanTouch = true -- ...and gets launched
end

function builders.Grenade(model)
	newHitbox(model, Vector3.new(2, 2, 2))
	local green = Color3.fromRGB(70, 110, 50)
	newPart(model, "Body", Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, -0.15, 0), green, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	-- Ridge lines, like a classic "pineapple" grenade
	local ridge = Color3.fromRGB(45, 75, 32)
	newPart(model, "Ridge", Vector3.new(0.06, 1.53, 1.53), CFrame.new(0, -0.15, 0) * UPRIGHT, ridge, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	newPart(model, "Ridge", Vector3.new(0.06, 1.53, 1.53), CFrame.new(0, -0.15, 0) * FORWARD, ridge, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	newPart(model, "Ridge", Vector3.new(0.06, 1.53, 1.53), CFrame.new(0, -0.15, 0), ridge, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	newPart(model, "Cap", Vector3.new(0.5, 0.4, 0.5), CFrame.new(0, 0.7, 0), DARK_METAL, Enum.Material.Metal)
	newPart(
		model,
		"Lever",
		Vector3.new(0.2, 0.9, 0.3),
		CFrame.new(0.4, 0.4, 0) * CFrame.Angles(0, 0, math.rad(-15)),
		DARK_METAL,
		Enum.Material.Metal
	)
	newPart(model, "Pin", Vector3.new(0.12, 0.5, 0.5), CFrame.new(-0.4, 0.75, 0), BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
end

function builders.RocketLauncher(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	local olive = Color3.fromRGB(80, 95, 60)
	newPart(model, "Tube", Vector3.new(3.4, 0.9, 0.9), FORWARD, olive, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Band", Vector3.new(0.2, 0.93, 0.93), CFrame.new(0, 0, 0.6) * FORWARD, HAZARD_YELLOW, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	newPart(
		model,
		"Muzzle",
		Vector3.new(0.3, 1.1, 1.1),
		CFrame.new(0, 0, -1.6) * FORWARD,
		Color3.fromRGB(200, 40, 40),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	newPart(model, "Exhaust", Vector3.new(0.3, 1.05, 1.05), CFrame.new(0, 0, 1.6) * FORWARD, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Grip", Vector3.new(0.35, 0.9, 0.4), CFrame.new(0, -0.7, 0.3), DARK_METAL, Enum.Material.Metal)
	newPart(model, "Sight", Vector3.new(0.2, 0.4, 0.5), CFrame.new(0, 0.6, -0.4), DARK_METAL, Enum.Material.Metal)
end

function builders.MachineGun(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	newPart(model, "Body", Vector3.new(0.8, 0.8, 1.8), CFrame.new(0, 0, 0.3), DARK_METAL, Enum.Material.Metal)
	newPart(model, "Barrel", Vector3.new(1.8, 0.3, 0.3), CFrame.new(0, 0.1, -1.3) * FORWARD, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Cooling cover over the back of the barrel, and a muzzle tip
	newPart(model, "Shroud", Vector3.new(1.1, 0.5, 0.5), CFrame.new(0, 0.1, -0.95) * FORWARD, DARK_METAL, Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
	newPart(model, "MuzzleTip", Vector3.new(0.3, 0.42, 0.42), CFrame.new(0, 0.1, -2.15) * FORWARD, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Carry handle on top
	newPart(model, "Handle", Vector3.new(0.15, 0.15, 0.9), CFrame.new(0, 0.68, 0.2), BLACK_METAL, Enum.Material.Metal)
	for _, z in { -0.2, 0.6 } do
		newPart(model, "HandlePost", Vector3.new(0.15, 0.3, 0.15), CFrame.new(0, 0.52, z), BLACK_METAL, Enum.Material.Metal)
	end
	newPart(model, "Ammo", Vector3.new(0.6, 0.7, 0.8), CFrame.new(0, -0.7, 0.2), Color3.fromRGB(90, 100, 60), Enum.Material.Metal)
	-- A short belt of bullets feeding in from the ammo box
	for index = 0, 3 do
		newPart(model, "Cartridge", Vector3.new(0.12, 0.12, 0.28), CFrame.new(0.45, -0.3 - index * 0.06, 0.5 - index * 0.2), BRASS, Enum.Material.Metal)
	end
	newPart(model, "Grip", Vector3.new(0.35, 0.8, 0.4), CFrame.new(0, -0.6, 1.0), DARK_METAL, Enum.Material.Metal)
	-- Two little support legs under the barrel
	for _, side in { -1, 1 } do
		newStrut(model, "Leg", Vector3.new(0, -0.05, -1.6), Vector3.new(side * 0.4, -0.9, -1.6), 0.1, BLACK_METAL, Enum.Material.Metal)
	end
end

-- The blade faces the camera; the server spins the parts named "Blade", "Tooth" and "Hub"
function builders.Saw(model)
	newHitbox(model, Vector3.new(5, 5, 3))
	newPart(model, "Mount", Vector3.new(0.6, 2.6, 0.6), CFrame.new(0, -1.4, -0.6), DARK_METAL, Enum.Material.Metal)
	newPart(model, "Blade", Vector3.new(0.25, 4.4, 4.4), FORWARD, Color3.fromRGB(200, 205, 215), Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Hub", Vector3.new(0.35, 1, 1), FORWARD, Color3.fromRGB(200, 40, 40), Enum.Material.Metal, Enum.PartType.Cylinder)
	for index = 1, 12 do
		local angle = index / 12 * math.pi * 2
		newPart(
			model,
			"Tooth",
			Vector3.new(0.5, 0.5, 0.2),
			CFrame.Angles(0, 0, angle) * CFrame.new(0, 2.25, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Color3.fromRGB(170, 175, 185),
			Enum.Material.Metal
		)
	end
end

function builders.Flamethrower(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	-- Fuel tank: red with dark end caps, a yellow hazard band and a pressure gauge
	newPart(model, "Tank", Vector3.new(1.6, 0.9, 0.9), CFrame.new(0, -0.5, 0.5) * FORWARD, Color3.fromRGB(200, 40, 40), Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, z in { -0.3, 1.3 } do
		newPart(model, "TankCap", Vector3.new(0.12, 0.95, 0.95), CFrame.new(0, -0.5, z) * FORWARD, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	newPart(model, "TankBand", Vector3.new(0.25, 0.94, 0.94), CFrame.new(0, -0.5, 0.5) * FORWARD, HAZARD_YELLOW, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for _, side in { -1, 1 } do
		newPart(model, "Gauge", Vector3.new(0.08, 0.32, 0.32), CFrame.new(side * 0.46, -0.35, 0.95), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		newPart(model, "GaugeNeedle", Vector3.new(0.02, 0.13, 0.03), CFrame.new(side * 0.5, -0.31, 0.95) * CFrame.Angles(math.rad(35), 0, 0), Color3.fromRGB(220, 30, 30))
	end
	-- Hose from the tank up into the pipe, with a valve wheel
	newPart(model, "Hose", Vector3.new(0.45, 0.2, 0.2), CFrame.new(0, -0.02, 1.0) * UPRIGHT, BLACK_METAL, Enum.Material.Rubber, Enum.PartType.Cylinder)
	newPart(model, "Pipe", Vector3.new(2.4, 0.35, 0.35), CFrame.new(0, 0.2, -0.4) * FORWARD, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, side in { -1, 1 } do
		newPart(model, "Valve", Vector3.new(0.08, 0.38, 0.38), CFrame.new(side * 0.24, 0.2, 0.55), Color3.fromRGB(200, 40, 40), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	-- Hand grip under the pipe
	newPart(model, "Grip", Vector3.new(0.22, 0.6, 0.3), CFrame.new(0, -0.12, -0.75) * CFrame.Angles(math.rad(-15), 0, 0), BLACK_METAL, Enum.Material.Rubber)
	-- Heat shield and nozzle at the front
	newPart(model, "HeatShield", Vector3.new(0.12, 0.75, 0.75), CFrame.new(0, 0.2, -1.38) * FORWARD, STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
	local nozzle = newPart(model, "Nozzle", Vector3.new(0.4, 0.55, 0.55), CFrame.new(0, 0.2, -1.6) * FORWARD, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	-- A little pilot light that's always burning, ready to light the fuel
	newPart(model, "PilotLight", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0, -0.05, -1.86), Color3.fromRGB(80, 170, 255), Enum.Material.Neon, Enum.PartType.Ball)
	newPart(model, "PilotFlame", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0, 0.05, -1.88), Color3.fromRGB(255, 160, 40), Enum.Material.Neon, Enum.PartType.Ball)
	-- The flames (switched on by the server while it's firing)
	local flames = Instance.new("ParticleEmitter")
	flames.Name = "Flames"
	flames.Enabled = false
	flames.Texture = "rbxasset://textures/particles/fire_main.dds"
	flames.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20))
	flames.LightEmission = 0.8
	flames.Size = NumberSequence.new(0.6, 2.4)
	flames.Transparency = NumberSequence.new(0.1, 1)
	flames.Lifetime = NumberRange.new(0.3, 0.45)
	flames.Speed = NumberRange.new(25, 30)
	flames.SpreadAngle = Vector2.new(12, 12)
	flames.Rate = 120
	-- The nozzle is a cylinder turned to face forward, so forward is its "Right" side
	flames.EmissionDirection = Enum.NormalId.Right
	flames.Parent = nozzle
end

function builders.BigTNT(model)
	newHitbox(model, Vector3.new(3, 2.4, 2))
	local red = Color3.fromRGB(200, 35, 30)
	for _, x in { -0.9, 0, 0.9 } do
		newPart(model, if x == 0 then "Body" else "Stick", Vector3.new(2.2, 0.85, 0.85), CFrame.new(x, -0.1, 0) * UPRIGHT, red, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	newPart(model, "Band", Vector3.new(2.8, 0.3, 1), CFrame.new(0, 0.2, 0), Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic)
	newPart(model, "Fuse", Vector3.new(0.1, 0.6, 0.1), CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(230, 220, 190), Enum.Material.Fabric)
	-- A glowing spark on the end of the fuse
	newPart(model, "Spark", Vector3.new(0.22, 0.22, 0.22), CFrame.new(-0.1, 1.56, 0), Color3.fromRGB(255, 170, 40), Enum.Material.Neon, Enum.PartType.Ball)
	local label = Instance.new("SurfaceGui")
	label.Face = Enum.NormalId.Back -- the side facing the camera
	label.Parent = model.Band
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.LuckiestGuy
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 230, 80)
	text.Text = "TNT"
	text.Parent = label
end

-- Dark body with glowing accents, so it stands out against the light walls
function builders.Laser(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	local cyan = Color3.fromRGB(0, 190, 255)
	newPart(model, "Body", Vector3.new(1, 1, 2), CFrame.new(0, 0, 0.3), Color3.fromRGB(45, 48, 58), Enum.Material.Metal)
	-- Glowing stripes down both sides
	for _, side in { -1, 1 } do
		newPart(model, "Stripe", Vector3.new(0.05, 0.12, 1.7), CFrame.new(side * 0.51, 0.15, 0.3), cyan, Enum.Material.Neon)
	end
	-- Cooling fins on top
	for _, z in { -0.15, 0.3, 0.75 } do
		newPart(model, "Fin", Vector3.new(0.85, 0.25, 0.08), CFrame.new(0, 0.62, z), BLACK_METAL, Enum.Material.Metal)
	end
	newPart(model, "Barrel", Vector3.new(1.2, 0.5, 0.5), CFrame.new(0, 0, -1.2) * FORWARD, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Collar", Vector3.new(0.25, 0.7, 0.7), CFrame.new(0, 0, -1.68) * FORWARD, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Lens", Vector3.new(0.15, 0.4, 0.4), CFrame.new(0, 0, -1.85) * FORWARD, Color3.fromRGB(255, 40, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
	for _, z in { -0.2, 0.5 } do
		newPart(model, "Ring", Vector3.new(0.15, 1.15, 1.15), CFrame.new(0, 0, z) * FORWARD, cyan, Enum.Material.Neon, Enum.PartType.Cylinder)
	end
end

-- Words or a symbol painted on the side of a part that faces the camera
local function paintLabel(part, label, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the side facing the camera
	gui.Parent = part
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.LuckiestGuy
	text.TextScaled = true
	text.TextColor3 = color
	text.Text = label
	text.Parent = gui
end

-- A sharp tooth: a square turned 45 degrees, half sunk into whatever it sticks out of,
-- so from the side it looks like a triangle pointing out
local function addTooth(model, name, cframe, size, depth, color)
	return newPart(model, name, Vector3.new(size, size, depth), cframe * CFrame.Angles(0, 0, math.rad(45)), color or STEEL, Enum.Material.Metal)
end

-- Its top faces into the room; anything touching the hitbox gets stabbed
function builders.Spikes(model)
	local hitbox = newHitbox(model, Vector3.new(5, 1.4, 3))
	hitbox.CanTouch = true
	newPart(model, "Base", Vector3.new(5, 0.3, 3), CFrame.new(0, -0.55, 0), DARK_METAL, Enum.Material.DiamondPlate)
	for index = 0, 4 do
		local x = -2 + index
		addTooth(model, "Spike", CFrame.new(x, -0.4, 0), 1.1, 2.6)
		-- A dark tip, so each spike reads clearly against the light walls
		addTooth(model, "Tip", CFrame.new(x, 0.18, 0), 0.28, 2.62, BLACK_METAL)
	end
end

-- Blows along its top (+Y). The blades (named "FanBlade") spin while it's on.
function builders.Fan(model)
	newHitbox(model, Vector3.new(5, 2, 5))
	newPart(model, "Housing", Vector3.new(1.4, 4.9, 4.9), CFrame.new(0, -0.25, 0) * UPRIGHT, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Inside", Vector3.new(1.42, 4.3, 4.3), CFrame.new(0, -0.25, 0) * UPRIGHT, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Stripe", Vector3.new(0.2, 4.95, 4.95), CFrame.new(0, -0.7, 0) * UPRIGHT, HAZARD_YELLOW, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for index = 1, 3 do
		local angle = index / 3 * math.pi * 2
		newPart(model, "FanBlade", Vector3.new(1.8, 0.12, 0.8), CFrame.Angles(0, angle, 0) * CFrame.new(1.05, 0.15, 0) * CFrame.Angles(math.rad(20), 0, 0), STEEL, Enum.Material.Metal)
	end
	newPart(model, "FanBlade", Vector3.new(0.5, 0.8, 0.8), CFrame.new(0, 0.2, 0) * UPRIGHT, Color3.fromRGB(200, 40, 40), Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Safety grill over the top
	for _, offset in { -1.5, -0.75, 0, 0.75, 1.5 } do
		newPart(model, "Grill", Vector3.new(0.08, 0.08, 4.2 - math.abs(offset) * 1.2), CFrame.new(offset, 0.6, 0), STEEL, Enum.Material.Metal)
	end
	newPart(model, "Grill", Vector3.new(4.3, 0.08, 0.08), CFrame.new(0, 0.62, 0), STEEL, Enum.Material.Metal)
	-- Streaks of wind (switched on by the server while it's blowing)
	local top = Instance.new("Attachment")
	top.Name = "WindSpot"
	top.Position = Vector3.new(0, 0.7, 0)
	top.Parent = model.PrimaryPart
	local wind = Instance.new("ParticleEmitter")
	wind.Name = "Wind"
	wind.Enabled = false
	wind.Color = ColorSequence.new(Color3.new(1, 1, 1))
	wind.Transparency = NumberSequence.new(0.55, 1)
	wind.Size = NumberSequence.new(0.25, 0.6)
	wind.Lifetime = NumberRange.new(0.4, 0.6)
	wind.Speed = NumberRange.new(30, 40)
	wind.SpreadAngle = Vector2.new(8, 8)
	wind.Rate = 40
	wind.EmissionDirection = Enum.NormalId.Top
	wind.Shape = Enum.ParticleEmitterShape.Disc
	wind.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	wind.Parent = top
end

-- Punches out along its top (+Y). The server slides the parts named "Glove", "Thumb",
-- "Cuff" and "Rod" out and back.
function builders.BoxingGlove(model)
	newHitbox(model, Vector3.new(3, 2, 3))
	newPart(model, "Base", Vector3.new(2.6, 0.4, 2.6), CFrame.new(0, -0.8, 0), DARK_METAL, Enum.Material.Metal)
	newPart(model, "Spring", Vector3.new(0.6, 1, 1), CFrame.new(0, -0.35, 0) * UPRIGHT, STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Rod", Vector3.new(0.9, 0.35, 0.35), CFrame.new(0, -0.1, 0) * UPRIGHT, STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
	local red = Color3.fromRGB(210, 30, 30)
	newPart(model, "Cuff", Vector3.new(0.4, 1.1, 1.1), CFrame.new(0, 0.05, 0) * UPRIGHT, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	newPart(model, "Glove", Vector3.new(1.6, 1.3, 1.5), CFrame.new(0, 0.7, 0), red, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	newPart(model, "Thumb", Vector3.new(0.6, 0.8, 0.6), CFrame.new(0.65, 0.5, 0) * CFrame.Angles(0, 0, math.rad(-25)), red, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

-- Two jaws lying open on the floor. The server closes the parts with a "Jaw" attribute
-- (-1 = left jaw, 1 = right jaw) up around their hinges in the middle.
function builders.BearTrap(model)
	local hitbox = newHitbox(model, Vector3.new(4, 1, 3))
	hitbox.CanTouch = true
	newPart(model, "Base", Vector3.new(1, 0.25, 2.6), CFrame.new(0, -0.38, 0), BLACK_METAL, Enum.Material.Metal)
	newPart(model, "Pan", Vector3.new(0.15, 1.2, 1.2), CFrame.new(0, -0.2, 0) * UPRIGHT, HAZARD_YELLOW, Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, side in { -1, 1 } do
		local jaw = newPart(model, "Jaw", Vector3.new(1.6, 0.15, 2.6), CFrame.new(side * 1.05, -0.35, 0), DARK_METAL, Enum.Material.Metal)
		jaw:SetAttribute("Jaw", side)
		for _, z in { -0.9, 0, 0.9 } do
			local tooth = addTooth(model, "Tooth", CFrame.new(side * 1.75, -0.25, z), 0.3, 0.3)
			tooth:SetAttribute("Jaw", side)
		end
		newPart(model, "Spring", Vector3.new(0.4, 0.5, 0.5), CFrame.new(side * 0.6, -0.35, 1.35) * FORWARD, STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

function builders.Shotgun(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	newPart(model, "Stock", Vector3.new(0.45, 0.6, 1.3), CFrame.new(0, -0.15, 1.05) * CFrame.Angles(math.rad(8), 0, 0), WOOD, Enum.Material.Wood)
	newPart(model, "Receiver", Vector3.new(0.5, 0.55, 0.9), CFrame.new(0, 0.05, 0.1), BLACK_METAL, Enum.Material.Metal)
	-- Double barrel
	for _, y in { 0.28, 0.02 } do
		newPart(model, "Barrel", Vector3.new(2.1, 0.24, 0.24), CFrame.new(0, y, -1.0) * FORWARD, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	newPart(model, "Pump", Vector3.new(0.38, 0.3, 0.8), CFrame.new(0, -0.18, -0.85), WOOD, Enum.Material.Wood)
	newPart(model, "Trigger", Vector3.new(0.1, 0.3, 0.2), CFrame.new(0, -0.32, 0.35), BLACK_METAL, Enum.Material.Metal)
	newPart(model, "Sight", Vector3.new(0.08, 0.08, 0.1), CFrame.new(0, 0.45, -2.0), BRASS, Enum.Material.Metal)
end

-- A loaded harpoon sticks out of the front
function builders.Harpoon(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	local blue = Color3.fromRGB(60, 90, 130)
	newPart(model, "Body", Vector3.new(0.6, 0.6, 1.6), CFrame.new(0, 0, 0.5), blue, Enum.Material.Metal)
	newPart(model, "Tank", Vector3.new(1.4, 0.45, 0.45), CFrame.new(0, -0.45, 0.4) * FORWARD, HAZARD_YELLOW, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Barrel", Vector3.new(1.3, 0.32, 0.32), CFrame.new(0, 0.05, -0.75) * FORWARD, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Grip", Vector3.new(0.3, 0.7, 0.35), CFrame.new(0, -0.55, 1.0) * CFrame.Angles(math.rad(-15), 0, 0), BLACK_METAL, Enum.Material.Rubber)
	-- Rope coiled on the side
	newPart(model, "Rope", Vector3.new(0.3, 0.7, 0.7), CFrame.new(0.42, 0.1, 0.6), Color3.fromRGB(205, 180, 130), Enum.Material.Fabric, Enum.PartType.Cylinder)
	newPart(model, "Shaft", Vector3.new(0.9, 0.12, 0.12), CFrame.new(0, 0.05, -1.75) * FORWARD, STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
	addTooth(model, "Point", CFrame.new(0, 0.05, -2.25) * CFrame.Angles(0, math.rad(90), 0), 0.35, 0.06)
end

-- A black iron cannon on a little wooden carriage
function builders.Cannon(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	local iron = Color3.fromRGB(40, 42, 46)
	newPart(model, "Barrel", Vector3.new(2.6, 1, 1), CFrame.new(0, 0.15, -0.3) * FORWARD, iron, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Muzzle", Vector3.new(0.3, 1.2, 1.2), CFrame.new(0, 0.15, -1.55) * FORWARD, iron, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Band", Vector3.new(0.2, 1.08, 1.08), CFrame.new(0, 0.15, 0.4) * FORWARD, BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Knob", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.15, 1.15), iron, Enum.Material.Metal, Enum.PartType.Ball)
	newPart(model, "Carriage", Vector3.new(1, 0.6, 1.8), CFrame.new(0, -0.55, 0.1), WOOD, Enum.Material.Wood)
	for _, side in { -1, 1 } do
		newPart(model, "Wheel", Vector3.new(0.2, 1.1, 1.1), CFrame.new(side * 0.6, -0.8, 0.2), DARK_WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	end
end

-- A copper coil with a metal ball on top, where the lightning comes from
function builders.TeslaCoil(model)
	newHitbox(model, Vector3.new(3, 5, 3))
	newPart(model, "Base", Vector3.new(2.4, 0.5, 2.4), CFrame.new(0, -2.25, 0), BLACK_METAL, Enum.Material.Metal)
	newPart(model, "Column", Vector3.new(3, 0.9, 0.9), CFrame.new(0, -0.6, 0) * UPRIGHT, Color3.fromRGB(230, 230, 220), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local copper = Color3.fromRGB(200, 110, 60)
	for index = 0, 6 do
		newPart(model, "Coil", Vector3.new(0.14, 1.1, 1.1), CFrame.new(0, -1.8 + index * 0.4, 0) * UPRIGHT, copper, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	newPart(model, "Ring", Vector3.new(0.35, 2.2, 2.2), CFrame.new(0, 1.1, 0) * UPRIGHT, STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Top", Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 1.65, 0), STEEL, Enum.Material.Metal, Enum.PartType.Ball)
	newPart(model, "Glow", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 2.2, 0), Color3.fromRGB(150, 200, 255), Enum.Material.Neon, Enum.PartType.Ball)
end

-- A floating gadget with a glowing purple core and arrows pointing up and down
function builders.GravityFlipper(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	local purple = Color3.fromRGB(170, 70, 255)
	newPart(model, "Body", Vector3.new(1.3, 1.3, 1.3), CFrame.new(), Color3.fromRGB(45, 40, 60), Enum.Material.Metal, Enum.PartType.Ball)
	newPart(model, "Core", Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, 0, 0.35), purple, Enum.Material.Neon, Enum.PartType.Ball)
	-- Two rings round it, facing the camera
	newPart(model, "Ring", Vector3.new(0.12, 2.5, 2.5), FORWARD, purple, Enum.Material.Neon, Enum.PartType.Cylinder)
	newPart(model, "Ring", Vector3.new(0.12, 2.1, 2.1), CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(90, 80, 120), Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Arrows: one pointing up, one pointing down
	for _, side in { 1, -1 } do
		newPart(model, "Arrow", Vector3.new(0.18, 0.5, 0.18), CFrame.new(0, side * 1.0, 0.2), Color3.new(1, 1, 1), Enum.Material.Neon)
		addTooth(model, "ArrowHead", CFrame.new(0, side * 1.3, 0.2) * CFrame.Angles(0, 0, if side > 0 then 0 else math.pi), 0.4, 0.18, Color3.new(1, 1, 1))
	end
end

-- A white sci-fi gun with a tank of glowing blue coolant
function builders.FreezeRay(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	local ice = Color3.fromRGB(120, 220, 255)
	newPart(model, "Body", Vector3.new(0.8, 0.8, 1.8), CFrame.new(0, 0, 0.3), Color3.fromRGB(235, 240, 245), Enum.Material.SmoothPlastic)
	newPart(model, "Tank", Vector3.new(1.1, 0.55, 0.55), CFrame.new(0, 0.6, 0.4) * FORWARD, ice, Enum.Material.Neon, Enum.PartType.Cylinder).Transparency = 0.2
	newPart(model, "TankCase", Vector3.new(1.2, 0.6, 0.6), CFrame.new(0, 0.6, 0.4) * FORWARD, Color3.new(1, 1, 1), Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.6
	newPart(model, "Barrel", Vector3.new(1.2, 0.4, 0.4), CFrame.new(0, 0, -1.1) * FORWARD, Color3.fromRGB(150, 160, 175), Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, z in { -0.8, -1.25 } do
		newPart(model, "Fin", Vector3.new(0.12, 0.8, 0.8), CFrame.new(0, 0, z) * FORWARD, ice, Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	newPart(model, "Tip", Vector3.new(0.2, 0.5, 0.5), CFrame.new(0, 0, -1.75) * FORWARD, ice, Enum.Material.Neon, Enum.PartType.Cylinder)
	newPart(model, "Grip", Vector3.new(0.3, 0.7, 0.35), CFrame.new(0, -0.6, 0.8) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(60, 70, 90), Enum.Material.Rubber)
end

-- A bubbling green tank feeding a stubby nozzle
function builders.AcidBlaster(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	local acid = Color3.fromRGB(120, 255, 60)
	newPart(model, "Body", Vector3.new(0.7, 0.7, 1.7), CFrame.new(0, -0.1, 0.3), Color3.fromRGB(70, 75, 60), Enum.Material.Metal)
	newPart(model, "Tank", Vector3.new(1.2, 0.85, 0.85), CFrame.new(0, 0.55, 0.45) * FORWARD, acid, Enum.Material.Neon, Enum.PartType.Cylinder).Transparency = 0.15
	newPart(model, "TankCase", Vector3.new(1.3, 0.92, 0.92), CFrame.new(0, 0.55, 0.45) * FORWARD, Color3.new(1, 1, 1), Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.6
	newPart(model, "Hazard", Vector3.new(0.2, 0.95, 0.95), CFrame.new(0, 0.55, 0.45) * FORWARD, HAZARD_YELLOW, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	newPart(model, "Pipe", Vector3.new(1.2, 0.35, 0.35), CFrame.new(0, -0.05, -1.0) * FORWARD, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Nozzle", Vector3.new(0.35, 0.55, 0.55), CFrame.new(0, -0.05, -1.7) * FORWARD, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Drip", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, -0.32, -1.78), acid, Enum.Material.Neon, Enum.PartType.Ball)
	newPart(model, "Grip", Vector3.new(0.3, 0.7, 0.35), CFrame.new(0, -0.65, 0.85) * CFrame.Angles(math.rad(-15), 0, 0), BLACK_METAL, Enum.Material.Rubber)
end

-- A dark thundercloud stuck to the ceiling, with lightning flickering underneath
function builders.StormCloud(model)
	newHitbox(model, Vector3.new(7, 3, 4))
	local puffs = {
		{ Vector3.new(-2.3, 0.1, 0), 2.4 },
		{ Vector3.new(-0.8, 0.5, 0), 3 },
		{ Vector3.new(1, 0.4, 0), 2.9 },
		{ Vector3.new(2.5, 0, 0), 2.2 },
		{ Vector3.new(0, -0.4, 0.2), 2.6 },
	}
	for index, puff in puffs do
		local shade = if index % 2 == 0 then Color3.fromRGB(95, 100, 115) else Color3.fromRGB(120, 125, 140)
		newPart(model, "Puff", Vector3.one * puff[2], CFrame.new(puff[1]), shade, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	-- A little zig-zag bolt hanging underneath
	local yellow = Color3.fromRGB(255, 230, 80)
	newPart(model, "Bolt", Vector3.new(0.2, 0.7, 0.2), CFrame.new(0.2, -1.4, 0.9) * CFrame.Angles(0, 0, math.rad(25)), yellow, Enum.Material.Neon)
	newPart(model, "Bolt", Vector3.new(0.2, 0.6, 0.2), CFrame.new(0.05, -1.85, 0.9) * CFrame.Angles(0, 0, math.rad(-30)), yellow, Enum.Material.Neon)
end

-- Hangs from the top of its box. The server swings the whole model like a pendulum.
function builders.WreckingBall(model)
	newHitbox(model, Vector3.new(4, 12, 4))
	newPart(model, "Mount", Vector3.new(2, 0.4, 2), CFrame.new(0, 5.8, 0), BLACK_METAL, Enum.Material.Metal)
	-- The chain: links turned alternately, all the way down to the ball
	for index = 0, 10 do
		local link = newPart(model, "Link", Vector3.new(0.18, 0.75, 0.4), CFrame.new(0, 5.4 - index * 0.68, 0), DARK_METAL, Enum.Material.Metal)
		if index % 2 == 1 then
			link.CFrame *= CFrame.Angles(0, math.rad(90), 0)
		end
	end
	newPart(model, "Ball", Vector3.new(3.4, 3.4, 3.4), CFrame.new(0, -4.1, 0), Color3.fromRGB(50, 52, 58), Enum.Material.Metal, Enum.PartType.Ball)
	-- Spikes all round the ball (the ones facing the camera show best)
	for index = 0, 7 do
		local angle = index / 8 * math.pi * 2
		local out = CFrame.new(0, -4.1, 0) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 1.7, 0)
		addTooth(model, "Spike", out, 0.75, 0.5)
	end
	addTooth(model, "Spike", CFrame.new(0, -4.1, 1.7) * CFrame.Angles(math.rad(90), 0, 0), 0.75, 0.5)
end

-- The hammer rests up against the ceiling. When it slams, the server slides the parts
-- named "Head" and "Grip" down to the floor and stretches the "Handle".
function builders.BanHammer(model)
	newHitbox(model, Vector3.new(4, 5, 3))
	newPart(model, "Mount", Vector3.new(2.4, 0.5, 2), CFrame.new(0, 2.25, 0), BLACK_METAL, Enum.Material.Metal)
	newPart(model, "Piston", Vector3.new(0.9, 1, 1), CFrame.new(0, 1.6, 0) * UPRIGHT, STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Handle", Vector3.new(2, 0.45, 0.45), CFrame.new(0, 0.3, 0) * UPRIGHT, WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	newPart(model, "Grip", Vector3.new(0.5, 0.55, 0.55), CFrame.new(0, -0.55, 0) * UPRIGHT, BLACK_METAL, Enum.Material.Rubber, Enum.PartType.Cylinder)
	local head = newPart(model, "Head", Vector3.new(3.8, 1.6, 1.8), CFrame.new(0, -1.55, 0), Color3.fromRGB(200, 30, 30), Enum.Material.Metal)
	paintLabel(head, "BAN", Color3.new(1, 1, 1))
end

-- A swirling disc of purple light round a pitch-black ball, facing the camera
function builders.BlackHole(model)
	newHitbox(model, Vector3.new(4, 4, 2))
	newPart(model, "Swirl", Vector3.new(0.1, 3.9, 3.9), FORWARD, Color3.fromRGB(150, 60, 255), Enum.Material.Neon, Enum.PartType.Cylinder).Transparency = 0.35
	newPart(model, "Swirl", Vector3.new(0.12, 3, 3), FORWARD, Color3.fromRGB(255, 120, 220), Enum.Material.Neon, Enum.PartType.Cylinder).Transparency = 0.25
	newPart(model, "Hole", Vector3.new(2.2, 2.2, 2.2), CFrame.new(), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	-- Little bits of light being sucked in, at the edge of the disc
	for index = 1, 4 do
		local angle = index / 4 * math.pi * 2 + 0.4
		newPart(model, "Swirl", Vector3.new(0.4, 0.15, 0.15), CFrame.Angles(0, 0, angle) * CFrame.new(1.7, 0, 0.1), Color3.new(1, 1, 1), Enum.Material.Neon)
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 80, 255)
	light.Brightness = 3
	light.Range = 10
	light.Parent = model.PrimaryPart
end

-- A big bomb with smaller bombs strapped round it
function builders.ClusterBomb(model)
	newHitbox(model, Vector3.new(2.4, 2.4, 2.4))
	newPart(model, "Body", Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, -0.2, 0), Color3.fromRGB(45, 45, 50), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	for index = 1, 5 do
		local angle = index / 5 * math.pi * 2
		newPart(model, "Bomblet", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.85, 0.25), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	newPart(model, "Cap", Vector3.new(0.45, 0.3, 0.45), CFrame.new(0, 0.62, 0), DARK_METAL, Enum.Material.Metal)
	newPart(model, "Fuse", Vector3.new(0.1, 0.45, 0.1), CFrame.new(0.05, 0.95, 0) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(230, 220, 190), Enum.Material.Fabric)
	newPart(model, "Spark", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0.13, 1.17, 0), Color3.fromRGB(255, 170, 40), Enum.Material.Neon, Enum.PartType.Ball)
end

-- Six barrels round the middle (named "SpinBarrel"), which the server spins while it fires
function builders.Minigun(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	newPart(model, "Body", Vector3.new(0.9, 0.9, 1.3), CFrame.new(0, 0, 0.7), DARK_METAL, Enum.Material.Metal)
	newPart(model, "Motor", Vector3.new(0.5, 0.7, 0.7), CFrame.new(0, 0, 0) * FORWARD, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	for index = 1, 6 do
		local angle = index / 6 * math.pi * 2
		newPart(model, "SpinBarrel", Vector3.new(2, 0.16, 0.16), CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.22, -1.2) * FORWARD, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	for _, z in { -0.5, -2.05 } do
		newPart(model, "SpinBarrel", Vector3.new(0.15, 0.7, 0.7), CFrame.new(0, 0, z) * FORWARD, DARK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	newPart(model, "Ammo", Vector3.new(0.7, 0.8, 0.9), CFrame.new(0.65, -0.35, 0.7), Color3.fromRGB(90, 100, 60), Enum.Material.Metal)
	for index = 0, 4 do
		newPart(model, "Cartridge", Vector3.new(0.12, 0.12, 0.28), CFrame.new(0.4, -0.05 + index * 0.05, 0.5 - index * 0.18), BRASS, Enum.Material.Metal)
	end
	newPart(model, "Handle", Vector3.new(0.15, 0.6, 0.15), CFrame.new(0, 0.65, 0.7), BLACK_METAL, Enum.Material.Metal)
	newPart(model, "Grip", Vector3.new(0.3, 0.75, 0.35), CFrame.new(0, -0.7, 1.1), BLACK_METAL, Enum.Material.Rubber)
end

-- A box of missile tubes, red tips poking out of the front
function builders.MissileSwarm(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	local olive = Color3.fromRGB(80, 95, 60)
	newPart(model, "Pod", Vector3.new(1.6, 1.6, 2.2), CFrame.new(0, 0, 0.1), olive, Enum.Material.Metal)
	newPart(model, "Stripe", Vector3.new(1.62, 0.25, 2.22), CFrame.new(0, 0.45, 0.1), HAZARD_YELLOW, Enum.Material.SmoothPlastic)
	for _, x in { -0.4, 0.4 } do
		for _, y in { -0.4, 0.4 } do
			newPart(model, "Tube", Vector3.new(0.3, 0.62, 0.62), CFrame.new(x, y, -1.0) * FORWARD, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
			newPart(model, "MissileTip", Vector3.new(0.4, 0.4, 0.4), CFrame.new(x, y, -1.1), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	newPart(model, "Sight", Vector3.new(0.2, 0.35, 0.5), CFrame.new(0, 0.95, 0.3), DARK_METAL, Enum.Material.Metal)
	newPart(model, "Grip", Vector3.new(0.35, 0.8, 0.4), CFrame.new(0, -1.1, 0.5), DARK_METAL, Enum.Material.Metal)
end

-- Two long rails with glowing coils between them. The "Core" glows brighter as it charges.
function builders.Railgun(model)
	newHitbox(model, Vector3.new(3, 3, 3))
	local blue = Color3.fromRGB(60, 160, 255)
	newPart(model, "Body", Vector3.new(0.9, 0.9, 1.4), CFrame.new(0, 0, 0.8), Color3.fromRGB(45, 48, 58), Enum.Material.Metal)
	newPart(model, "Core", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0, 0.1), blue, Enum.Material.Neon, Enum.PartType.Ball)
	for _, y in { 0.32, -0.32 } do
		newPart(model, "Rail", Vector3.new(0.2, 0.18, 2.6), CFrame.new(0, y, -0.9), STEEL, Enum.Material.Metal)
	end
	for _, z in { -0.4, -1.0, -1.6 } do
		newPart(model, "Coil", Vector3.new(0.12, 0.55, 0.55), CFrame.new(0, 0, z) * FORWARD, blue, Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	newPart(model, "Grip", Vector3.new(0.3, 0.7, 0.35), CFrame.new(0, -0.65, 1.1) * CFrame.Angles(math.rad(-15), 0, 0), BLACK_METAL, Enum.Material.Rubber)
end

-- A stubby yellow bomb standing on its fins, with a radiation sign on the front
function builders.MiniNuke(model)
	newHitbox(model, Vector3.new(2.6, 3.2, 2.6))
	newPart(model, "Body", Vector3.new(2.2, 1.7, 1.7), CFrame.new(0, -0.1, 0) * UPRIGHT, Color3.fromRGB(240, 200, 40), Enum.Material.Metal, Enum.PartType.Cylinder)
	newPart(model, "Nose", Vector3.new(1.7, 1.7, 1.7), CFrame.new(0, 0.95, 0), Color3.fromRGB(240, 200, 40), Enum.Material.Metal, Enum.PartType.Ball)
	newPart(model, "Band", Vector3.new(0.3, 1.75, 1.75), CFrame.new(0, -0.7, 0) * UPRIGHT, BLACK_METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, side in { -1, 1 } do
		newPart(model, "Fin", Vector3.new(0.15, 0.7, 1.4), CFrame.new(side * 0.95, -1.25, 0), BLACK_METAL, Enum.Material.Metal)
	end
	-- The radiation sign, on a flat plate facing the camera
	local plate = newPart(model, "Plate", Vector3.new(1.1, 1.1, 0.1), CFrame.new(0, -0.05, 0.86), Color3.fromRGB(240, 200, 40), Enum.Material.SmoothPlastic)
	paintLabel(plate, "☢", Color3.fromRGB(20, 20, 20))
end

-- A loose arrow (fired from a crossbow), pointing forward (-Z)
function ItemModels.buildArrow()
	local model = Instance.new("Model")
	model.Name = "Arrow"
	local shaft = addArrow(model, CFrame.new())
	-- The shaft is a cylinder turned on its side, so without this the model's
	-- "forward" would point out of the side of the arrow instead of out of its tip
	shaft.PivotOffset = FORWARD:Inverse()
	model.PrimaryPart = shaft
	return model
end

-- A rocket with a glowing tail, pointing forward (-Z)
function ItemModels.buildRocket()
	local model = Instance.new("Model")
	model.Name = "Rocket"
	model.PrimaryPart = newPart(
		model,
		"Body",
		Vector3.new(1.4, 0.45, 0.45),
		FORWARD,
		Color3.fromRGB(220, 220, 225),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	model.PrimaryPart.PivotOffset = FORWARD:Inverse() -- forward = out of the tip (see buildArrow)
	newPart(model, "Tip", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0, -0.75), Color3.fromRGB(200, 40, 40), Enum.Material.Metal, Enum.PartType.Ball)
	newPart(model, "Flame", Vector3.new(0.5, 0.35, 0.35), CFrame.new(0, 0, 0.9) * FORWARD, Color3.fromRGB(255, 160, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
	return model
end

-- A machine gun bullet, pointing forward (-Z)
function ItemModels.buildBullet()
	local model = Instance.new("Model")
	model.Name = "Bullet"
	model.PrimaryPart = newPart(model, "Body", Vector3.new(0.18, 0.18, 0.7), CFrame.new(), Color3.fromRGB(255, 215, 90), Enum.Material.Neon)
	return model
end

-- A model named `kind` made of one `part`, which is its PrimaryPart (things in flight)
local function oneParter(kind, size, color, material, shape)
	local model = Instance.new("Model")
	model.Name = kind
	model.PrimaryPart = newPart(model, "Body", size, CFrame.new(), color, material, shape)
	return model
end

-- Little projectiles, all pointing forward (-Z)
local smallProjectiles = {
	-- A shotgun pellet
	Pellet = function()
		return oneParter("Pellet", Vector3.new(0.15, 0.15, 0.4), Color3.fromRGB(255, 200, 90), Enum.Material.Neon)
	end,
	Cannonball = function()
		return oneParter("Cannonball", Vector3.new(1, 1, 1), Color3.fromRGB(30, 30, 34), Enum.Material.Metal, Enum.PartType.Ball)
	end,
	AcidBlob = function()
		local model = oneParter("AcidBlob", Vector3.new(0.7, 0.7, 0.9), Color3.fromRGB(120, 255, 60), Enum.Material.Neon, Enum.PartType.Ball)
		model.PrimaryPart.Transparency = 0.15
		return model
	end,
	-- A harpoon: a steel shaft with a sharp point
	Harpoon = function()
		local model = Instance.new("Model")
		model.Name = "Harpoon"
		local shaft = newPart(model, "Shaft", Vector3.new(2.2, 0.14, 0.14), FORWARD, STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
		shaft.PivotOffset = FORWARD:Inverse() -- forward = out of the tip (see buildArrow)
		model.PrimaryPart = shaft
		addTooth(model, "Point", CFrame.new(0, 0, -1.15) * CFrame.Angles(0, math.rad(90), 0), 0.4, 0.06)
		return model
	end,
	-- A little homing missile with a glowing tail
	Missile = function()
		local model = Instance.new("Model")
		model.Name = "Missile"
		local body = newPart(model, "Body", Vector3.new(0.9, 0.3, 0.3), FORWARD, Color3.fromRGB(230, 230, 235), Enum.Material.Metal, Enum.PartType.Cylinder)
		body.PivotOffset = FORWARD:Inverse()
		model.PrimaryPart = body
		newPart(model, "Tip", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0, -0.45), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		newPart(model, "Flame", Vector3.new(0.35, 0.22, 0.22), CFrame.new(0, 0, 0.6) * FORWARD, Color3.fromRGB(255, 160, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
		return model
	end,
}

-- Anything that flies: "Arrow", "Rocket", "Bullet", "Pellet", "Cannonball", "AcidBlob",
-- "Harpoon" or "Missile"
function ItemModels.buildProjectile(kind)
	if kind == "Arrow" then
		return ItemModels.buildArrow()
	elseif kind == "Rocket" then
		return ItemModels.buildRocket()
	elseif smallProjectiles[kind] then
		return smallProjectiles[kind]()
	end
	return ItemModels.buildBullet()
end

function ItemModels.build(weaponId)
	local model = Instance.new("Model")
	model.Name = weaponId
	builders[weaponId](model)
	return model
end

return ItemModels
