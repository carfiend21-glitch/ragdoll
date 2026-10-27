-- A picture of a weapon for buttons and shop cards: the real 3D model from the game
-- (shared/ItemModels), shown in a ViewportFrame, so the icon always matches the
-- weapon you actually place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemModels = require(ReplicatedStorage:WaitForChild("Shared").ItemModels)

local WeaponIcon = {}

-- Which way the camera looks at each model (from the model's middle, in the model's
-- own directions: it points forward along -Z). Most are seen from the side so you can
-- see their shape; the saw is seen from the front so you see its round blade.
local VIEW = {
	Saw = Vector3.new(0.35, 0.25, -1),
	BouncePad = Vector3.new(0.6, 1, -0.8),
	Mine = Vector3.new(0.6, 0.9, -0.8),
	-- Seen the way the room camera sees them (from the front, +Z)
	Spikes = Vector3.new(0.3, 0.45, 1),
	BoxingGlove = Vector3.new(0.4, 0.4, 1),
	TeslaCoil = Vector3.new(0.3, 0.25, 1),
	GravityFlipper = Vector3.new(0.3, 0.2, 1),
	StormCloud = Vector3.new(0.2, -0.1, 1),
	WreckingBall = Vector3.new(0.3, 0.1, 1),
	BanHammer = Vector3.new(0.3, 0.1, 1),
	BlackHole = Vector3.new(0.15, 0.1, 1),
	ClusterBomb = Vector3.new(0.3, 0.3, 1),
	MiniNuke = Vector3.new(0.35, 0.25, 1),
	-- Seen from above, so you can see the blades and the jaws
	Fan = Vector3.new(0.4, 1, 0.8),
	BearTrap = Vector3.new(0.4, 1, 0.8),
}
local DEFAULT_VIEW = Vector3.new(1, 0.45, -0.55)
local FOV = 30

-- Makes the icon. Returns the ViewportFrame.
function WeaponIcon.create(weaponId, parent, size, position)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = size
	viewport.Position = position or UDim2.new()
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(170, 170, 175)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.3)

	local model = ItemModels.build(weaponId)
	model:PivotTo(CFrame.new())
	model.Parent = viewport

	-- Frame the model: back the camera off until the whole thing fits
	local box, boxSize = model:GetBoundingBox()
	local radius = boxSize.Magnitude / 2
	local distance = radius / math.tan(math.rad(FOV / 2)) * 1.05
	local direction = (VIEW[weaponId] or DEFAULT_VIEW).Unit
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.CFrame = CFrame.lookAt(box.Position + direction * distance, box.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	viewport.Parent = parent
	return viewport
end

return WeaponIcon
