-- The loading screen: the noob floating frozen in its test room (like at the start of
-- a replay) and a loading bar from 0 to 100%.
-- It runs before anything else (it lives in ReplicatedFirst) and the bar shows real
-- progress: the game loading, then every sound downloading, then your screen being
-- ready, then you standing on the spawn plate. Downloading the sounds now means they
-- play straight away in the game, instead of arriving late the first time they're used.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne
local TITLE_FONT = Enum.Font.LuckiestGuy
local WHITE = Color3.new(1, 1, 1)
local ORANGE = Color3.fromRGB(240, 140, 30)
local GOLD = Color3.fromRGB(255, 205, 50)
local SHOW_SECONDS = 5 -- the bar fills evenly over this long (longer only if loading is still going)
local NOOB_SCALE = 1.5 -- same size as the real noob (Config.NOOB_SCALE)
local ROOM = Vector3.new(44, 27.5, 10) -- same size as the real rooms (Config.ROOM_SIZE)
local TIPS = {
	"Combos multiply your points: hit the noob with lots of weapons quickly!",
	"Keep the noob in the air to earn cash.",
	"Drag a weapon into the 🗑️ to sell it back.",
	"Win a round to earn a Noob Buck 💵.",
	"Knock off all four limbs for a secret achievement...",
	"Weapons get used up, so place them wisely.",
}

local function label(props)
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = props.Font or FONT
	textLabel.TextScaled = true
	textLabel.TextColor3 = props.TextColor3 or WHITE
	textLabel.TextStrokeTransparency = 0.3
	textLabel.AnchorPoint = props.AnchorPoint or Vector2.zero
	textLabel.Position = props.Position
	textLabel.Size = props.Size
	textLabel.Text = props.Text or ""
	textLabel.Parent = props.Parent
	return textLabel
end

local function corner(parent, radius)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = radius
	uiCorner.Parent = parent
end

local function block(parent, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

---------------------------------------------------------------------------
-- The screen
---------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100 -- on top of everything
gui.Parent = player:WaitForChild("PlayerGui")

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
background.Active = true -- nothing behind it can be clicked
background.Parent = gui
local shade = Instance.new("UIGradient")
shade.Rotation = 90
shade.Color = ColorSequence.new(Color3.fromRGB(35, 36, 48), Color3.fromRGB(12, 12, 16))
shade.Parent = background

local title = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.05),
	Size = UDim2.fromScale(0.8, 0.12),
	Font = TITLE_FONT,
	TextColor3 = GOLD,
	Text = "RAGDOLL PVP",
	Parent = background,
})
title.TextStrokeTransparency = 0

-- The little test room with the noob floating in it
local viewport = Instance.new("ViewportFrame")
viewport.AnchorPoint = Vector2.new(0.5, 0.5)
viewport.Position = UDim2.fromScale(0.5, 0.47)
viewport.Size = UDim2.fromScale(0.62, 0.5)
viewport.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
viewport.Ambient = Color3.fromRGB(150, 150, 158)
viewport.LightColor = Color3.fromRGB(255, 250, 240)
viewport.LightDirection = Vector3.new(-0.25, -0.8, -0.55)
viewport.Parent = background
corner(viewport, UDim.new(0, 12))
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = ROOM.X / ROOM.Y
aspect.Parent = viewport
local border = Instance.new("UIStroke")
border.Thickness = 3
border.Color = Color3.fromRGB(70, 72, 85)
border.Parent = viewport

local W, H, D = ROOM.X, ROOM.Y, ROOM.Z
local wall = Color3.fromRGB(205, 208, 214)
block(viewport, Vector3.new(W + 2, 1, D), CFrame.new(0, -0.5, 0), Color3.fromRGB(95, 98, 105), Enum.Material.DiamondPlate)
block(viewport, Vector3.new(W + 2, 1, D), CFrame.new(0, H + 0.5, 0), Color3.fromRGB(175, 178, 185))
block(viewport, Vector3.new(1, H, D), CFrame.new(-W / 2 - 0.5, H / 2, 0), wall)
block(viewport, Vector3.new(1, H, D), CFrame.new(W / 2 + 0.5, H / 2, 0), wall)
block(viewport, Vector3.new(W + 2, H + 2, 1), CFrame.new(0, H / 2, -D / 2 - 0.5), Color3.fromRGB(232, 234, 238))
block(viewport, Vector3.new(W, 1.5, 0.2), CFrame.new(0, 0.75, -D / 2 + 0.1), Color3.fromRGB(150, 153, 160))
for _, x in { -W / 4, W / 4 } do
	block(viewport, Vector3.new(4, 0.4, 2), CFrame.new(x, H - 0.2, 0), Color3.fromRGB(235, 232, 220))
end

-- The classic noob: yellow head and arms, blue shirt, green legs
local yellow = BrickColor.new("Bright yellow").Color
local blue = BrickColor.new("Bright blue").Color
local green = BrickColor.new("Br. yellowish green").Color
local noob = Instance.new("Model")
noob.Parent = viewport
local noobParts = {
	{ Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), blue },
	{ Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), yellow },
	{ Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), yellow },
	{ Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), green },
	{ Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), green },
}
for _, spec in noobParts do
	block(noob, spec[1] * NOOB_SCALE, CFrame.new(spec[2] * NOOB_SCALE), spec[3])
end
local head = block(noob, Vector3.new(2, 1, 1) * NOOB_SCALE, CFrame.new(Vector3.new(0, 1.5, 0) * NOOB_SCALE), yellow)
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.Head
mesh.Scale = Vector3.one * 1.25
mesh.Parent = head
local face = Instance.new("Decal")
face.Texture = "rbxasset://textures/face.png"
face.Face = Enum.NormalId.Front
face.Parent = head
noob.PrimaryPart = noob:FindFirstChildWhichIsA("Part")

local camera = Instance.new("Camera")
camera.FieldOfView = 25
-- Straight at the room's open front, far enough back for the whole room to fit
local distance = (H / 2) / math.tan(math.rad(12.5)) * 1.02
camera.CFrame = CFrame.new(0, H / 2, D / 2 + distance)
camera.Parent = viewport
viewport.CurrentCamera = camera

-- The loading bar and its percentage
local track = Instance.new("Frame")
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.fromScale(0.5, 0.8)
track.Size = UDim2.fromScale(0.5, 0.035)
track.BackgroundColor3 = Color3.fromRGB(55, 57, 68)
track.Parent = background
corner(track, UDim.new(0.5, 0))
local trackSize = Instance.new("UISizeConstraint")
trackSize.MinSize = Vector2.new(220, 14)
trackSize.Parent = track
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = ORANGE
fill.Parent = track
corner(fill, UDim.new(0.5, 0))
local percentLabel = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.845),
	Size = UDim2.fromScale(0.5, 0.045),
	Font = TITLE_FONT,
	Text = "LOADING... 0%",
	Parent = background,
})
local tipLabel = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.91),
	Size = UDim2.fromScale(0.8, 0.035),
	TextColor3 = Color3.fromRGB(190, 195, 210),
	Text = "💡 " .. TIPS[math.random(#TIPS)],
	Parent = background,
})

---------------------------------------------------------------------------
-- Animating it
---------------------------------------------------------------------------

-- Our screen is up now, so Roblox's own loading screen can go (removing it any
-- earlier would leave a moment showing the empty void)
ReplicatedFirst:RemoveDefaultLoadingScreen()

local startTime = os.clock()
local target = 0 -- where the bar is heading (0 to 1)
local shown = 0 -- where the bar is right now
local nextTip = os.clock() + 3

local connection = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - startTime
	-- The noob hangs frozen mid-air, bobbing and swaying a little
	local float = CFrame.new(0, H / 2 + math.sin(t * 1.6) * 0.6, 0)
		* CFrame.Angles(0, math.pi + math.sin(t * 0.7) * 0.25, math.sin(t * 1.1) * 0.08)
	noob:PivotTo(float)

	-- The bar fills evenly over SHOW_SECONDS, but never gets ahead of what has really loaded
	local goal = math.min(target, t / SHOW_SECONDS)
	shown += (goal - shown) * math.min(1, dt * 6)
	fill.Size = UDim2.fromScale(shown, 1)
	percentLabel.Text = ("LOADING... %d%%"):format(math.floor(shown * 100 + 0.5))

	if os.clock() > nextTip then
		nextTip = os.clock() + 3
		tipLabel.Text = "💡 " .. TIPS[math.random(#TIPS)]
	end
end)

---------------------------------------------------------------------------
-- Loading (the bar shows real progress)
---------------------------------------------------------------------------

-- 0 - 20%: the game itself
if not game:IsLoaded() then
	target = 0.08
	game.Loaded:Wait()
end
target = 0.2

-- 20 - 90%: every sound in the game, so they play straight away later
local ok, Sounds = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sounds"))
end)
if ok then
	local toLoad = {}
	for _, info in Sounds.LIST do
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. info.id
		table.insert(toLoad, sound)
	end
	local done = 0
	pcall(function()
		ContentProvider:PreloadAsync(toLoad, function()
			done += 1
			target = 0.2 + 0.7 * done / #toLoad
		end)
	end)
end
target = 0.9

-- 90 - 95%: your screen (the HUD) being ready
player.PlayerGui:WaitForChild("Hud", 15)
target = 0.95

-- 95 - 100%: you, standing on the spawn plate in the lobby (so you never see yourself
-- dropping in, or a half-built lobby). Gives up after a while so nobody gets stuck here.
local giveUpAt = os.clock() + 20
Workspace:WaitForChild("Lobby", 20)
while os.clock() < giveUpAt do
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.FloorMaterial ~= Enum.Material.Air then
		break -- landed
	end
	task.wait(0.1)
end
target = 1

-- Let the bar reach 100% (and show for at least a moment), then fade out
while shown < 0.995 do
	task.wait()
end
percentLabel.Text = "READY!"
task.wait(0.3)
local fade = TweenInfo.new(0.6)
TweenService:Create(background, fade, { BackgroundTransparency = 1 }):Play()
for _, thing in background:GetDescendants() do
	if thing:IsA("TextLabel") then
		TweenService:Create(thing, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	elseif thing:IsA("ViewportFrame") then
		TweenService:Create(thing, fade, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
	elseif thing:IsA("Frame") then
		TweenService:Create(thing, fade, { BackgroundTransparency = 1 }):Play()
	elseif thing:IsA("UIStroke") then
		TweenService:Create(thing, fade, { Transparency = 1 }):Play()
	end
end
task.wait(0.65)
connection:Disconnect()
gui:Destroy()
