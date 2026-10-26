-- Builds the 3D models for weapons/traps. The server uses them for the real
-- thing, and players' devices use them for the see-through "ghost" while placing.
-- Each model faces -Z (forward) and is centered on its invisible Hitbox.
local ItemModels = {}

local DARK_METAL = Color3.fromRGB(60, 65, 70)
local WOOD = Color3.fromRGB(140, 90, 45)
local DARK_WOOD = Color3.fromRGB(70, 45, 25)

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
	newPart(model, "Bow", Vector3.new(3.4, 0.3, 0.4), CFrame.new(0, 0.1, -1.2), DARK_WOOD, Enum.Material.Wood)
	newPart(model, "String", Vector3.new(3.2, 0.08, 0.08), CFrame.new(0, 0.1, -0.5), Color3.new(1, 1, 1))
	newPart(
		model,
		"LoadedBolt",
		Vector3.new(0.15, 0.15, 1.8),
		CFrame.new(0, 0.33, -0.8),
		Color3.fromRGB(160, 160, 170),
		Enum.Material.Metal
	)
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
	newPart(model, "Base", Vector3.new(5, 0.5, 6), CFrame.new(0, -0.25, 0), DARK_METAL, Enum.Material.Metal)
	local pad = newPart(
		model,
		"Pad",
		Vector3.new(4.4, 0.4, 5.4),
		CFrame.new(0, 0.2, 0),
		Color3.fromRGB(80, 220, 90),
		Enum.Material.Neon
	)
	pad.CanCollide = true -- the noob lands on it...
	pad.CanTouch = true -- ...and gets launched
end

function builders.Grenade(model)
	newHitbox(model, Vector3.new(2, 2, 2))
	newPart(
		model,
		"Body",
		Vector3.new(1.5, 1.5, 1.5),
		CFrame.new(0, -0.15, 0),
		Color3.fromRGB(70, 110, 50),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	newPart(model, "Cap", Vector3.new(0.5, 0.4, 0.5), CFrame.new(0, 0.7, 0), DARK_METAL, Enum.Material.Metal)
	newPart(
		model,
		"Lever",
		Vector3.new(0.2, 0.9, 0.3),
		CFrame.new(0.4, 0.4, 0) * CFrame.Angles(0, 0, math.rad(-15)),
		DARK_METAL,
		Enum.Material.Metal
	)
	newPart(
		model,
		"Pin",
		Vector3.new(0.12, 0.5, 0.5),
		CFrame.new(-0.4, 0.75, 0),
		Color3.fromRGB(255, 210, 60),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
end

function ItemModels.build(weaponId)
	local model = Instance.new("Model")
	model.Name = weaponId
	builders[weaponId](model)
	return model
end

return ItemModels
