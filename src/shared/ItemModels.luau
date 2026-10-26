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

-- Anything that flies: "Arrow", "Rocket" or "Bullet"
function ItemModels.buildProjectile(kind)
	if kind == "Arrow" then
		return ItemModels.buildArrow()
	elseif kind == "Rocket" then
		return ItemModels.buildRocket()
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
