-- Everything on screen. During a round it's laid out like the original game
-- (see Layout): a top bar with the timer, an orange bottom bar with the noob's
-- health and the weapons, and a panel on the right with current tasks and the
-- achievements list. In the lobby there's a status line and an achievements button.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ShopItems = require(Shared.ShopItems)
local Sounds = require(Shared.Sounds)
local Weapons = require(Shared.Weapons)

local Layout = require(script.Parent.Layout)
local WeaponIcon = require(script.Parent.WeaponIcon)

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local TITLE_FONT = Enum.Font.LuckiestGuy
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(25, 25, 35)
local DARK = Color3.fromRGB(38, 40, 48)
local ORANGE = Color3.fromRGB(240, 140, 30)
local ORANGE_DARK = Color3.fromRGB(150, 85, 25)
local LOCKED = Color3.fromRGB(95, 80, 70)
local YELLOW = Color3.fromRGB(255, 220, 60)
-- How far outside the trash can's edge a drop still counts, so you don't have to be exact
local TRASH_PADDING = 18
local RED = Color3.fromRGB(230, 50, 40)
local TASK_COUNT = 3

-- Makes a UI object, sets its properties and adds children
local function create(className, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = props.Parent
	return instance
end

local function text(props, children)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	props.TextWrapped = true
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.3
	return create("TextLabel", props, children)
end

local function button(props, children)
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	return create("TextButton", props, children)
end

local function rounded(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function padding(pixels)
	local size = UDim.new(0, pixels)
	return create("UIPadding", { PaddingLeft = size, PaddingRight = size, PaddingTop = size, PaddingBottom = size })
end

local function outline(thickness, color)
	return create("UIStroke", {
		Thickness = thickness or 2,
		Color = color or INK,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- A frame that fills `parent` but whose contents are designed at full size and
-- shrunk by `setScale` on small screens
local function scaledContent(parent)
	local content = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })
	create("UIScale", { Name = "Scale", Parent = content })
	return content
end

local function setScale(content, scale)
	content.Scale.Scale = scale
	content.Size = UDim2.fromScale(1 / scale, 1 / scale)
end

-- Green when healthy, through yellow, to red when nearly gone
local function healthColor(fraction)
	if fraction > 0.5 then
		return Color3.fromRGB(240, 210, 50):Lerp(Color3.fromRGB(70, 200, 80), (fraction - 0.5) * 2)
	end
	return RED:Lerp(Color3.fromRGB(240, 210, 50), fraction * 2)
end

local function rewardText(achievement)
	local rewards = {}
	for _, weapon in Weapons.list do
		if weapon.unlockedBy == achievement.id then
			table.insert(rewards, weapon.name)
		end
	end
	return if #rewards > 0 then "  🎁 Unlocks: " .. table.concat(rewards, ", ") else ""
end

local Hud = {}
Hud.__index = Hud

function Hud.new()
	local self = setmetatable({}, Hud)
	self.achievements = {} -- set of unlocked achievement ids
	self.owned = {} -- set of weapon ids bought with Robux
	self.running = false -- is your room playing (true) or stopped (false)
	self.inRun = false -- has PLAY been pressed since the last restart (weapons locked)
	self.selected = nil
	self.onWeaponClicked = nil -- set by Main: function(weaponId)
	self.onOpenShop = nil -- set by Main: function(weaponId), opens the Noob Buck shop on that weapon
	self.toastQueue = {}
	self.hintHoldUntil = 0
	self.comboHideAt = 0
	self.bannerHideAt = 0
	self.feedEntries = {}
	self.lastHealthUpdate = 0

	self.gui = create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true, -- we position around Roblox's top buttons ourselves (Layout)
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	self:_buildLobby()
	self:_buildTopBar()
	self:_buildBottomBar()
	self:_buildSidePanel()
	self:_buildRoomOverlay()
	self:_buildAchievementList()
	self:_buildPopups()

	local camera = Workspace.CurrentCamera
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:_applyLayout()
	end)
	local refresh = function()
		self:_refresh()
	end
	Remotes.GameState:GetAttributeChangedSignal("Phase"):Connect(refresh)
	Remotes.GameState:GetAttributeChangedSignal("TimeLeft"):Connect(refresh)
	player:GetAttributeChangedSignal("Room"):Connect(refresh)
	player:GetAttributeChangedSignal("Spectating"):Connect(refresh)
	player:GetAttributeChangedSignal("Damage"):Connect(refresh)
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		self:_refreshCash()
	end)
	RunService.Heartbeat:Connect(function()
		if os.clock() - self.lastHealthUpdate > 0.1 then
			self.lastHealthUpdate = os.clock()
			self:_refreshHealth()
		end
	end)

	self:_applyLayout()
	self:_refresh()
	self:_updateHint()
	return self
end

---------------------------------------------------------------------------
-- Building the screen
---------------------------------------------------------------------------

function Hud:_buildLobby()
	self.lobby = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = self.gui })
	self.lobbyStatus = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(420, 40),
		Text = "",
		Parent = self.lobby,
	})
	self.achievementsButton = button({
		Size = UDim2.fromOffset(210, 40),
		BackgroundColor3 = ORANGE,
		Text = "🏆 Achievements",
		Parent = self.lobby,
	}, { rounded(8), padding(6), outline(2) })

	-- Pop-up window for the achievements list while in the lobby
	self.modal = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		BackgroundColor3 = DARK,
		Visible = false,
		ZIndex = 10,
		Parent = self.lobby,
	}, { rounded(12), outline(3), create("UISizeConstraint", { MaxSize = Vector2.new(480, 520) }) })
	text({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -70, 0, 36),
		Font = TITLE_FONT,
		Text = "ACHIEVEMENTS LIST",
		TextColor3 = ORANGE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.modal,
	})
	local close = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = RED,
		Text = "X",
		Parent = self.modal,
	}, { rounded(8), padding(6) })
	close.Activated:Connect(function()
		self.modal.Visible = false
	end)
	self.achievementsButton.Activated:Connect(function()
		Sounds.playUI("Click")
		self.modal.Visible = not self.modal.Visible
	end)
	self.modalBody = create("Frame", {
		Position = UDim2.fromOffset(10, 52),
		Size = UDim2.new(1, -20, 1, -62),
		BackgroundTransparency = 1,
		Parent = self.modal,
	})

	self:_buildLobbyCash()
end

-- Your cash, shown in the lobby too: the amount you'll start the next round with.
-- (Robux weapons are bought by clicking their locked button on the weapon bar.)
function Hud:_buildLobbyCash()
	self.lobbyCash = text({
		Size = UDim2.fromOffset(210, 34),
		Font = TITLE_FONT,
		TextColor3 = Color3.fromRGB(120, 230, 120),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Config.formatCash(player:GetAttribute("Cash") or Config.STARTING_CASH),
		Parent = self.lobby,
	})
end

function Hud:_buildTopBar()
	self.topBar = create("Frame", { BackgroundColor3 = DARK, BorderSizePixel = 0, Active = true, Parent = self.gui })
	self.topContent = scaledContent(self.topBar)
	self.roomLabel = text({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(0.35, 0, 0, 32),
		Font = TITLE_FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = self.topContent,
	})
	-- One line that shrinks to fit (wrapping a long name onto a second line made it tiny)
	self.roomLabel.TextWrapped = false
	self.timer = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(260, 36),
		Font = TITLE_FONT,
		TextColor3 = ORANGE,
		Text = "",
		Parent = self.topContent,
	})
	-- Back to a fresh noob floating in the middle (your damage score is kept)
	self.restartButton = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 5),
		Size = UDim2.fromOffset(150, 34),
		BackgroundColor3 = RED,
		Text = "↺ RESTART",
		Parent = self.topContent,
	}, { rounded(6), padding(5) })
	self.restartButton.Activated:Connect(function()
		Sounds.playUI("Restart")
		Remotes.Restart:FireServer()
	end)
end

-- PLAY / STOP: starts or pauses your room (the space bar does the same)
function Hud:_togglePlay()
	Sounds.playUI(if self.running then "Stop" else "Play")
	Remotes.SetRunning:FireServer(not self.running)
end

function Hud:_setPlayButton(running)
	self.running = running
	self.playButton.Text = if running then "⏸ STOP" else "▶ PLAY"
	self.playButton.BackgroundColor3 = if running then RED else Color3.fromRGB(40, 175, 80)
end

function Hud:_buildBottomBar()
	self.bottomBar = create("Frame", { BackgroundColor3 = ORANGE, BorderSizePixel = 0, Active = true, Parent = self.gui }, {
		create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(255, 165, 50), Color3.fromRGB(215, 110, 20)),
		}),
	})
	local content = scaledContent(self.bottomBar)
	self.bottomContent = content

	-- Noob health: a little body diagram (tap it for the numbers) and the total
	local diagram = create("Frame", {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.fromOffset(64, 88),
		BackgroundTransparency = 1,
		Parent = content,
	})
	-- Laid out as you see the noob: its left arm is on your right
	local shapes = {
		Head = { 19, 0, 26, 18 },
		Torso = { 19, 20, 26, 30 },
		RightArm = { 5, 20, 12, 30 },
		LeftArm = { 47, 20, 12, 30 },
		RightLeg = { 19, 52, 12, 34 },
		LeftLeg = { 33, 52, 12, 34 },
	}
	self.healthShapes = {}
	for key, box in shapes do
		local shape = create("Frame", {
			Position = UDim2.fromOffset(box[1], box[2]),
			Size = UDim2.fromOffset(box[3], box[4]),
			BackgroundColor3 = healthColor(1),
			Parent = diagram,
		}, { rounded(3), outline(1.5) })
		self.healthShapes[key] = shape
	end
	local diagramButton = button({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = diagram })
	self.healthTotal = text({
		Position = UDim2.fromOffset(84, 12),
		Size = UDim2.fromOffset(130, 44),
		Font = TITLE_FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "✚ 0",
		Parent = content,
	})
	local healthButton = button({
		Position = UDim2.fromOffset(84, 58),
		Size = UDim2.fromOffset(130, 26),
		BackgroundColor3 = ORANGE_DARK,
		Text = "BODY PARTS ▲",
		Parent = content,
	}, { rounded(6), padding(4) })
	local toggleDetails = function()
		self.healthDetails.Visible = not self.healthDetails.Visible
	end
	diagramButton.Activated:Connect(toggleDetails)
	healthButton.Activated:Connect(toggleDetails)

	-- In the middle: the PLAY button, then every weapon (scrolls sideways if they don't all fit)
	self.weaponHolder = create("Frame", {
		Position = UDim2.fromOffset(222, 0),
		Size = UDim2.new(1, -222 - 190, 1, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})
	-- The big PLAY / STOP button, like the original's
	self.playButton = button({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(116, 74),
		BackgroundColor3 = Color3.fromRGB(40, 175, 80),
		Font = TITLE_FONT,
		Text = "▶ PLAY",
		Parent = self.weaponHolder,
	}, { rounded(8), padding(10), outline(3) })
	-- The weapons, from cheapest on the left to most expensive on the right, with an arrow
	-- at each end to scroll through them (dragging, swiping and the mouse wheel work too)
	local arrowWidth = 30
	local stripLeft = 124 + arrowWidth + 4
	local strip = create("ScrollingFrame", {
		Position = UDim2.fromOffset(stripLeft, 0),
		Size = UDim2.new(1, -stripLeft - arrowWidth - 4, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = DARK,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		Parent = self.weaponHolder,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	self.weaponStrip = strip
	local function arrow(direction)
		local arrowButton = button({
			AnchorPoint = Vector2.new(if direction < 0 then 0 else 1, 0.5),
			Position = if direction < 0 then UDim2.new(0, 124, 0.5, 0) else UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(arrowWidth, 74),
			BackgroundColor3 = DARK,
			Font = TITLE_FONT,
			Text = if direction < 0 then "◀" else "▶",
			Parent = self.weaponHolder,
		}, { rounded(8), padding(5), outline(2) })
		arrowButton.Activated:Connect(function()
			Sounds.playUI("Click")
			self:_scrollWeapons(direction)
		end)
		return arrowButton
	end
	self.scrollLeft = arrow(-1)
	self.scrollRight = arrow(1)
	-- The mouse wheel scrolls the bar sideways
	strip.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self:_scrollWeapons(if input.Position.Z > 0 then -1 else 1)
		end
	end)
	strip:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:_updateScrollArrows()
	end)
	strip:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
		self:_updateScrollArrows()
	end)
	strip:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
		self:_updateScrollArrows()
	end)
	self.playButton.Activated:Connect(function()
		self:_togglePlay()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Space and self.weaponHolder.Visible then
			self:_togglePlay()
		end
	end)

	self.weaponButtons = {}
	for order, weapon in Weapons.list do
		local weaponButton = create("TextButton", {
			Name = weapon.id,
			LayoutOrder = order,
			Size = UDim2.fromOffset(72, 86),
			BackgroundColor3 = DARK,
			Text = "",
			Parent = strip,
		}, {
			rounded(8),
			create("UIStroke", {
				Name = "Highlight",
				Thickness = 3,
				Color = YELLOW,
				Enabled = false,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
		-- The real weapon model, so the picture matches what you place
		WeaponIcon.create(weapon.id, weaponButton, UDim2.fromScale(1, 0.48), UDim2.fromScale(0, 0.02))
		text({
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.new(1, -6, 0.22, 0),
			Text = weapon.name,
			Parent = weaponButton,
		})
		text({
			Name = "Price",
			Position = UDim2.new(0, 3, 0.73, 0),
			Size = UDim2.new(1, -6, 0.24, 0),
			Font = TITLE_FONT,
			Text = Config.formatCash(weapon.price),
			TextColor3 = Color3.fromRGB(120, 230, 120),
			Parent = weaponButton,
		})
		-- How many are placed out of how many you're allowed, e.g. "1/4"
		text({
			Name = "Count",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -3, 0, 2),
			Size = UDim2.fromOffset(30, 16),
			Text = "0/" .. weapon.maxPlaced,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 2,
			Parent = weaponButton,
		})
		-- Covers the picture (not the price) while the weapon is locked
		text({
			Name = "Lock",
			Size = UDim2.fromScale(1, 0.72),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Text = "🔒",
			TextStrokeTransparency = 1,
			Parent = weaponButton,
		}, { rounded(8), padding(14) })
		-- A gold star on the exclusive (Noob Buck / Robux) weapons, so they stand out
		if weapon.exclusive then
			text({
				Position = UDim2.fromOffset(2, 1),
				Size = UDim2.fromOffset(18, 18),
				Text = "⭐",
				TextStrokeTransparency = 1,
				ZIndex = 3,
				Parent = weaponButton,
			})
		end
		weaponButton.Activated:Connect(function()
			Sounds.playUI("Click")
			self:_onWeaponButton(weapon)
		end)
		self.weaponButtons[weapon.id] = weaponButton
	end

	-- Score, cash and achievement progress, on the right
	self.damageLabel = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.fromOffset(170, 36),
		Font = TITLE_FONT,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = content,
	})
	self.cashLabel = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 44),
		Size = UDim2.fromOffset(170, 30),
		Font = TITLE_FONT,
		TextColor3 = Color3.fromRGB(120, 230, 120),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "$0",
		Parent = content,
	})
	self.progressLabel = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 76),
		Size = UDim2.fromOffset(170, 18),
		Font = TITLE_FONT,
		TextColor3 = ORANGE_DARK,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = content,
	})
end

function Hud:_buildSidePanel()
	self.sidePanel = create("Frame", { BackgroundColor3 = DARK, BorderSizePixel = 0, Active = true, Parent = self.gui })
	local content = scaledContent(self.sidePanel)
	self.sideContent = content

	local function header(y, label)
		text({
			Position = UDim2.fromOffset(8, y),
			Size = UDim2.new(1, -16, 0, 24),
			Font = TITLE_FONT,
			Text = label,
			TextColor3 = Color3.fromRGB(220, 220, 230),
			Parent = content,
		})
	end
	header(6, "CURRENT TASKS")
	local tasks = create("Frame", {
		Position = UDim2.fromOffset(6, 34),
		Size = UDim2.new(1, -12, 0, TASK_COUNT * 56),
		BackgroundTransparency = 1,
		Parent = content,
	}, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	self.taskCards = {}
	for index = 1, TASK_COUNT do
		self.taskCards[index] = self:_newCard(tasks, index, 52)
	end
	self.allDoneLabel = text({
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 0,
		Text = "All done! 🏆",
		Visible = false,
		Parent = tasks,
	})

	local listTop = 34 + TASK_COUNT * 56 + 6
	header(listTop, "ACHIEVEMENTS LIST")
	self.listHolder = create("Frame", {
		Position = UDim2.fromOffset(6, listTop + 28),
		Size = UDim2.new(1, -12, 1, -(listTop + 34)),
		BackgroundTransparency = 1,
		Parent = content,
	})
end

-- One orange achievement card, like the original's
function Hud:_newCard(parent, order, height)
	local frame = create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = ORANGE,
		Parent = parent,
	}, { rounded(6), outline(2) })
	local title = text({
		Position = UDim2.fromOffset(8, 3),
		Size = UDim2.new(1, -16, 0.42, 0),
		Font = TITLE_FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local description = text({
		Position = UDim2.new(0, 8, 0.46, 0),
		Size = UDim2.new(1, -16, 0.5, -2),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextStrokeTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 245, 230),
		Parent = frame,
	}, { create("UITextSizeConstraint", { MaxTextSize = 14 }) })
	return { frame = frame, title = title, description = description }
end

local function fillCard(card, number, achievement, unlocked)
	card.title.Text = ("%d  %s%s"):format(number, achievement.name:upper(), if unlocked then "  ✔" else "")
	card.description.Text = achievement.description .. rewardText(achievement)
	card.frame.BackgroundColor3 = if unlocked then ORANGE else LOCKED
end

function Hud:_buildAchievementList()
	self.achievementList = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	self.listCards = {}
	for number, achievement in Achievements.list do
		local card = self:_newCard(self.achievementList, number, 58)
		fillCard(card, number, achievement, false)
		self.listCards[achievement.id] = card
	end
end

-- Things drawn over the room: hit list, combo, big messages, hints, health details
function Hud:_buildRoomOverlay()
	self.roomArea = create("Frame", { BackgroundTransparency = 1, Parent = self.gui })

	self.feed = create("Frame", {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(300, 170),
		BackgroundTransparency = 1,
		Parent = self.roomArea,
	}, { create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })

	self.combo = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(240, 40),
		Font = TITLE_FONT,
		TextColor3 = ORANGE,
		Text = "",
		Visible = false,
		Parent = self.roomArea,
	})
	self.comboScale = create("UIScale", { Parent = self.combo })

	self.banner = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0.8, 0, 0, 64),
		Font = TITLE_FONT,
		TextColor3 = RED,
		TextStrokeTransparency = 0,
		Text = "",
		Visible = false,
		Parent = self.roomArea,
	})
	self.bannerScale = create("UIScale", { Parent = self.banner })

	self.hint = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(0.6, 0, 0, 26),
		Text = "",
		Parent = self.roomArea,
	})

	-- Hit points of each body part (opened from the bottom bar)
	self.healthDetails = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -8),
		Size = UDim2.fromOffset(230, #Config.BODY_PARTS * 26 + 16),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = self.roomArea,
	}, {
		rounded(8),
		padding(8),
		create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	self.healthRows = {}
	for order, info in Config.BODY_PARTS do
		self.healthRows[info.key] = text({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = self.healthDetails,
		})
	end

	-- The trash can: drag a weapon here to sell it. It sits in the bottom-right corner
	-- of the room, where your eye ends up after scanning the screen and where your
	-- mouse hand or thumb rests, but well away from the weapon bar and PLAY button
	-- so nothing gets sold by accident.
	self.trash = create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(92, 104),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = self.roomArea,
	}, { rounded(14), create("UIStroke", { Name = "Edge", Thickness = 3, Color = Color3.fromRGB(90, 95, 110) }) })
	self.trashScale = create("UIScale", { Parent = self.trash })
	self.trashIcon = text({
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 58),
		Text = "🗑️",
		TextStrokeTransparency = 1,
		Parent = self.trash,
	})
	self.trashLabel = text({
		Position = UDim2.fromOffset(4, 68),
		Size = UDim2.new(1, -8, 0, 28),
		Font = TITLE_FONT,
		Text = "SELL",
		Parent = self.trash,
	})
	-- An invisible area a little bigger than the trash can: dropping anywhere on it
	-- sells, so you don't have to aim exactly
	create("Frame", {
		Name = "DropArea",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, TRASH_PADDING * 2, 1, TRASH_PADDING * 2),
		BackgroundTransparency = 1,
		Parent = self.trash,
	})
end

-- Is this mouse or finger (an InputObject) over the trash can?
function Hud:isOverTrash(input)
	if not self.trash.Visible then
		return false
	end
	-- Ask Roblox which on-screen boxes are under the pointer, the same check it uses for
	-- clicking buttons. Working out the position ourselves kept going wrong (Roblox's top
	-- bar shifts things), so only part of the trash can worked.
	local position = input.Position
	for _, object in self.gui.Parent:GetGuiObjectsAtPosition(position.X, position.Y) do
		if object == self.trash or object:IsDescendantOf(self.trash) then
			return true
		end
	end
	return false
end

-- Lights the trash can up red (and shows the refund) while a weapon is held over it
function Hud:setTrashHover(over, price)
	if over == self.trashHover then
		return
	end
	self.trashHover = over
	self.trash.BackgroundColor3 = if over then RED else DARK
	self.trash.Edge.Color = if over then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(90, 95, 110)
	self.trashLabel.Text = if over then "+" .. Config.formatCash(price) else "SELL"
	self.trashLabel.TextColor3 = if over then Color3.fromRGB(150, 255, 150) else WHITE
	TweenService:Create(self.trashScale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = if over then 1.2 else 1 }):Play()
	if over then
		Sounds.playUI("Click")
	end
end

function Hud:_buildPopups()
	self.toast = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -200),
		Size = UDim2.fromOffset(380, 80),
		BackgroundColor3 = ORANGE,
		ZIndex = 20,
		Parent = self.gui,
	}, { rounded(10), outline(3) })
	self.toastTitle = text({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 38),
		Font = TITLE_FONT,
		Parent = self.toast,
	})
	self.toastSub = text({
		Position = UDim2.fromOffset(10, 46),
		Size = UDim2.new(1, -20, 0, 26),
		TextColor3 = INK,
		TextStrokeTransparency = 1,
		Parent = self.toast,
	})

	self.results = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = DARK,
		Visible = false,
		ZIndex = 15,
		Parent = self.gui,
	}, {
		rounded(12),
		outline(3),
		padding(14),
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

---------------------------------------------------------------------------
-- Keeping it up to date
---------------------------------------------------------------------------

-- Sizes the bars and panel to the screen (called when the window changes size)
function Hud:_applyLayout()
	local viewport = Workspace.CurrentCamera.ViewportSize
	local layout = Layout.get(viewport)
	local room = layout.room
	self.layout = layout

	self.topBar.Position = UDim2.fromOffset(0, layout.inset)
	self.topBar.Size = UDim2.fromOffset(room.width, layout.topBar)
	self.bottomBar.Position = UDim2.fromOffset(0, viewport.Y - layout.bottomBar)
	self.bottomBar.Size = UDim2.fromOffset(room.width, layout.bottomBar)
	self.sidePanel.Position = UDim2.fromOffset(room.width, layout.inset)
	self.sidePanel.Size = UDim2.fromOffset(layout.sidePanel, viewport.Y - layout.inset)
	self.roomArea.Position = UDim2.fromOffset(room.x, room.y)
	self.roomArea.Size = UDim2.fromOffset(room.width, room.height)
	for _, content in { self.topContent, self.bottomContent, self.sideContent } do
		setScale(content, layout.scale)
	end

	self.lobbyStatus.Position = UDim2.new(0.5, 0, 0, layout.inset + 6)
	self.achievementsButton.Position = UDim2.fromOffset(12, layout.inset + 8)
	self.lobbyCash.Position = UDim2.fromOffset(16, layout.inset + 56)
end

-- Where achievement pop-ups slide down to
function Hud:_toastPosition(shown)
	local layout = self.layout
	local inRoom = self.roundVisible
	local x = if inRoom then UDim.new(0, layout.room.width / 2) else UDim.new(0.5, 0)
	local y = if not shown then -200 elseif inRoom then layout.room.y + 50 else layout.inset + 56
	return UDim2.new(x, UDim.new(0, y))
end

function Hud:_refresh()
	local phase = Remotes.GameState:GetAttribute("Phase")
	local timeLeft = Remotes.GameState:GetAttribute("TimeLeft") or 0
	local room = player:GetAttribute("Room") or 0
	local inRoom = room > 0 and (phase == "Round" or phase == "Results")
	local playing = phase == "Round" and room > 0
	self.roundVisible = inRoom

	-- Lobby
	local spectating = (player:GetAttribute("Spectating") or 0) > 0 and phase == "Round"
	self.lobby.Visible = not inRoom and not spectating
	if phase == "Intermission" then
		self.lobbyStatus.Text = ("Next round in %d..."):format(timeLeft)
	elseif phase == "Round" then
		self.lobbyStatus.Text = "Round in progress - you're up next!"
	elseif phase == "Results" then
		self.lobbyStatus.Text = "Round over!"
	elseif phase == "Replay" then
		self.lobbyStatus.Text = "Watching replays..."
	elseif phase == "Vote" then
		self.lobbyStatus.Text = "Voting for the best sequence..."
	else
		self.lobbyStatus.Text = "Waiting for players..."
	end

	-- Round screen
	for _, frame in { self.topBar, self.bottomBar, self.sidePanel, self.roomArea } do
		frame.Visible = inRoom
	end
	self:_updateRoomLabel()
	self.timer.Text = if phase == "Round"
		then ("⏱ %d:%02d"):format(timeLeft // 60, timeLeft % 60)
		else "ROUND IS OVER"
	self.damageLabel.Text = "💥 " .. Config.formatScore(player:GetAttribute("Damage") or 0)
	self.weaponHolder.Visible = playing
	self.restartButton.Visible = playing
	self.hint.Visible = playing
	if not playing then
		self.combo.Visible = false
	end
	if phase ~= "Results" then
		self.results.Visible = false
	end

	-- The achievements list lives in the side panel during a round, and in the pop-up in the lobby
	self.achievementList.Parent = if inRoom then self.listHolder else self.modalBody
	if inRoom then
		self.modal.Visible = false
	end
end

-- "ROOM 3: name   2/8 WEAPONS" in the top bar. Only this writes it: two places used to
-- write different versions of it, so it flickered back and forth every second.
function Hud:_updateRoomLabel()
	local room = player:GetAttribute("Room") or 0
	local label = if room > 0
		then ("ROOM %d: %s   %d/%d WEAPONS"):format(room, player.DisplayName, self.placedTotal or 0, Config.MAX_ITEMS_PER_ROOM)
		else ""
	-- Only set it when it changes, so the text never jumps around
	if self.roomLabel.Text ~= label then
		self.roomLabel.Text = label
	end
end

-- Reads the noob's hit points from your room and colors the body diagram
function Hud:_refreshHealth()
	local roomNumber = player:GetAttribute("Room") or 0
	local rooms = Workspace:FindFirstChild("Rooms")
	local room = rooms and rooms:FindFirstChild("Room" .. roomNumber)
	if not room or not self.roundVisible then
		return
	end

	-- How many of each weapon are placed (each weapon has a limit, plus 8 in total)
	local counts, total = {}, 0
	local items = room:FindFirstChild("Items")
	for _, model in if items then items:GetChildren() else {} do
		counts[model.Name] = (counts[model.Name] or 0) + 1
		total += 1
	end
	self.placedCounts, self.placedTotal = counts, total
	for id, weaponButton in self.weaponButtons do
		local limit = Weapons.byId[id].maxPlaced
		local count = counts[id] or 0
		weaponButton.Count.Text = ("%d/%d"):format(count, limit)
		weaponButton.Count.TextColor3 = if count >= limit then RED else WHITE
	end
	self:_updateRoomLabel()

	-- Keep the PLAY / STOP button, the weapon buttons and the trash can in step with the room
	local running = room:GetAttribute("Running") == true
	local inRun = room:GetAttribute("InRun") == true
	self.trash.Visible = self.weaponHolder.Visible and not inRun
	if running ~= self.running or inRun ~= self.inRun then
		self.inRun = inRun
		self:_setPlayButton(running)
		for _, weaponButton in self.weaponButtons do
			-- Faded out during a run: weapons can only be added while setting up
			weaponButton.BackgroundTransparency = if inRun then 0.6 else 0
		end
		self:_updateHint()
	end

	local total, maxTotal = 0, 0
	for _, info in Config.BODY_PARTS do
		local health = room:GetAttribute(info.key) or info.maxHealth
		local fraction = health / info.maxHealth
		total += health
		maxTotal += info.maxHealth

		local shape = self.healthShapes[info.key]
		shape.BackgroundColor3 = if health > 0 then healthColor(fraction) else Color3.fromRGB(60, 60, 65)
		shape.BackgroundTransparency = if health > 0 then 0 else 0.4

		local row = self.healthRows[info.key]
		row.Text = if health > 0
			then ("%s  %d / %d"):format(info.name, health, info.maxHealth)
			else ("%s  ✖ GONE"):format(info.name)
		row.TextColor3 = if health > 0 then healthColor(fraction) else Color3.fromRGB(150, 150, 155)
	end
	self.healthTotal.Text = ("✚ %d"):format(total)
	self.healthTotal.TextColor3 = healthColor(total / maxTotal)
end

-- Called with { achievements = {ids}, ownedWeapons = {weapon ids bought with Robux} }
function Hud:setData(data)
	self.achievements = {}
	self.owned = {}
	local count = 0
	for _, id in data.achievements do
		if Achievements.byId[id] then
			self.achievements[id] = true
			count += 1
		end
	end
	for _, id in data.ownedWeapons do
		self.owned[id] = true
	end

	local percent = math.floor(count / #Achievements.list * 100)
	self.achievementsButton.Text = ("🏆 Achievements %d/%d"):format(count, #Achievements.list)
	self.progressLabel.Text = ("%d%% PROGRESS ACHIEVEMENTS"):format(percent)
	for _, weapon in Weapons.list do
		local lock = self.weaponButtons[weapon.id].Lock
		lock.Visible = not Weapons.isUnlocked(weapon, self.achievements, self.owned)
		-- Robux-only weapons show a price tag instead of a padlock
		-- Exclusive weapons show a Noob Buck, Robux-only ones a price tag, the rest a padlock
		local unlock = ShopItems.unlockFor(weapon.id)
		lock.Text = if unlock and unlock.kind == "unlock" and weapon.exclusive then "💵"
			elseif weapon.gamePassId and not weapon.unlockedBy then "R$"
			else "🔒"
	end
	self:_refreshCash()

	-- Current tasks = the first few achievements you don't have yet
	local nextTask = 1
	for number, achievement in Achievements.list do
		local unlocked = self.achievements[achievement.id] == true
		fillCard(self.listCards[achievement.id], number, achievement, unlocked)
		if not unlocked and nextTask <= TASK_COUNT then
			fillCard(self.taskCards[nextTask], number, achievement, false)
			nextTask += 1
		end
	end
	for index, card in self.taskCards do
		card.frame.Visible = index < nextTask
	end
	self.allDoneLabel.Visible = nextTask == 1
end

---------------------------------------------------------------------------
-- Weapons menu and hints
---------------------------------------------------------------------------

function Hud:_onWeaponButton(weapon)
	if Weapons.isUnlocked(weapon, self.achievements, self.owned) then
		if self.inRun then
			self:flashHint("Weapons are locked during a run. Wait for the noob to stop, or press RESTART.")
			return
		end
		if (self.placedTotal or 0) >= Config.MAX_ITEMS_PER_ROOM then
			self:flashHint(
				("Your room is full! (%d weapons max) Drag one into the 🗑️ to sell it."):format(Config.MAX_ITEMS_PER_ROOM)
			)
			return
		end
		if ((self.placedCounts or {})[weapon.id] or 0) >= weapon.maxPlaced then
			self:flashHint(("You can only place %d %s at a time."):format(weapon.maxPlaced, weapon.name))
			return
		end
		if (player:GetAttribute("Cash") or 0) < weapon.price then
			self:flashHint(
				("Not enough cash! The %s costs %s. Deal damage and keep the noob in the air to earn more."):format(
					weapon.name,
					Config.formatCash(weapon.price)
				)
			)
			return
		end
		if self.onWeaponClicked then
			self.onWeaponClicked(weapon.id)
		end
		return
	end

	-- Locked: offer to buy it with Robux, and/or say which achievement unlocks it, and/or
	-- show it in the Noob Buck shop
	local forSale = self:_promptPurchase(weapon)
	local unlock = ShopItems.unlockFor(weapon.id)
	local achievement = weapon.unlockedBy and Achievements.byId[weapon.unlockedBy]
	if weapon.exclusive then
		if not forSale and self.onOpenShop then
			self.onOpenShop(weapon.id)
		end
		if unlock and unlock.kind == "robux" then
			self:flashHint(("⭐ The %s is ROBUX ONLY (R$ %d). Try it for one round in the 💵 SHOP!"):format(weapon.name, unlock.robux))
		else
			self:flashHint(("⭐ The %s is an EXCLUSIVE weapon: unlock it for 💵 %d Noob Bucks%s"):format(
				weapon.name,
				if unlock then unlock.price else 0,
				if forSale then " or Robux!" else "!"
			))
		end
	elseif achievement then
		self:flashHint(
			("🔒 Get \"%s\" to unlock: %s%s"):format(
				achievement.name,
				achievement.description,
				if forSale then " (or buy it now!)"
					elseif unlock then (" (or 💵 %d Noob Bucks in the SHOP)"):format(unlock.price)
					else ""
			)
		)
	elseif not forSale then
		self:flashHint(("%s isn't for sale yet."):format(weapon.name))
	end
end

-- Slides the weapon bar most of a screenful left (-1) or right (1)
function Hud:_scrollWeapons(direction)
	local strip = self.weaponStrip
	-- (sizes on screen are shrunk on small screens; the scroll position isn't)
	local scale = if self.layout then self.layout.scale else 1
	local maxX = math.max(0, strip.AbsoluteCanvasSize.X - strip.AbsoluteWindowSize.X) / scale
	local step = math.max(strip.AbsoluteWindowSize.X * 0.8 / scale, 78)
	local x = math.clamp((self.scrollTarget or strip.CanvasPosition.X) + direction * step, 0, maxX)
	self.scrollTarget = x
	local slide = TweenService:Create(strip, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { CanvasPosition = Vector2.new(x, 0) })
	slide.Completed:Once(function()
		if self.scrollTarget == x then
			self.scrollTarget = nil
		end
	end)
	slide:Play()
end

-- Fades out an arrow when there's nothing more to see that way
function Hud:_updateScrollArrows()
	local strip = self.weaponStrip
	local x = strip.CanvasPosition.X
	local scale = if self.layout then self.layout.scale else 1
	local maxX = (strip.AbsoluteCanvasSize.X - strip.AbsoluteWindowSize.X) / scale
	for arrowButton, more in { [self.scrollLeft] = x > 1, [self.scrollRight] = x < maxX - 1 } do
		arrowButton.BackgroundTransparency = if more then 0 else 0.6
		arrowButton.TextTransparency = if more then 0 else 0.6
		arrowButton.AutoButtonColor = more
	end
end

-- Shows your cash, and turns prices you can't afford red
function Hud:_refreshCash()
	local cash = player:GetAttribute("Cash") or 0
	self.cashLabel.Text = Config.formatCash(cash)
	self.lobbyCash.Text = Config.formatCash(cash)
	for weaponId, weaponButton in self.weaponButtons do
		local affordable = cash >= Weapons.byId[weaponId].price
		weaponButton.Price.TextColor3 = if affordable then Color3.fromRGB(120, 230, 120) else RED
	end
end

-- Opens Roblox's purchase window for a weapon's Game Pass. Returns false if it isn't for sale.
function Hud:_promptPurchase(weapon)
	if not weapon.gamePassId or weapon.gamePassId <= 0 then
		return false
	end
	MarketplaceService:PromptGamePassPurchase(player, weapon.gamePassId)
	return true
end

-- Highlights the chosen weapon (nil = none)
function Hud:setSelected(weaponId)
	self.selected = weaponId
	for id, weaponButton in self.weaponButtons do
		weaponButton.Highlight.Enabled = id == weaponId
	end
	self.hintHoldUntil = 0
	self:_updateHint()
end

function Hud:_updateHint()
	if os.clock() < self.hintHoldUntil then
		return -- a flashed message is still showing
	end
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local verb = if touchOnly then "Tap" else "Click"
	if self.selected then
		self.hint.Text = ("%s inside the room to place the %s"):format(verb, Weapons.byId[self.selected].name)
	else
		self.hint.Text = if not self.inRun
			then "Set up your weapons, then press PLAY! Used-up weapons don't come back."
			elseif self.running then "Run in progress! It ends when the noob stops moving, or press RESTART."
			else "Paused. Press PLAY to carry on, or RESTART to set up again."
	end
end

-- Shows a message for a few seconds instead of the normal hint
function Hud:flashHint(message)
	self.hint.Text = message
	self.hintHoldUntil = os.clock() + 3
	task.delay(3, function()
		self:_updateHint()
	end)
end

---------------------------------------------------------------------------
-- Hits, messages and pop-ups
---------------------------------------------------------------------------

-- A big message in the middle of the room, e.g. "DESTROYED!"
function Hud:showBanner(message)
	self.banner.Text = message
	self.banner.Visible = true
	self.bannerScale.Scale = 1.6
	TweenService:Create(self.bannerScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	self.bannerHideAt = os.clock() + 1.6
	task.delay(1.6, function()
		if os.clock() >= self.bannerHideAt then
			self.banner.Visible = false
		end
	end)
end

-- Adds a line to the hit list in the corner of the room
function Hud:_addFeedLine(message, color)
	local line = text({
		Size = UDim2.new(1, 0, 0, 22),
		Text = message,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = os.clock() * 1000 // 1,
		Parent = self.feed,
	})
	table.insert(self.feedEntries, line)
	if #self.feedEntries > 7 then
		table.remove(self.feedEntries, 1):Destroy()
	end
	task.delay(2.5, function()
		local fade = TweenService:Create(line, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		local index = table.find(self.feedEntries, line)
		if index then
			table.remove(self.feedEntries, index)
		end
		line:Destroy()
	end)
end

-- A "-15 HEAD" that floats up from where the noob got hit
local function floatingNumber(position, message, color)
	local anchor = Instance.new("Attachment")
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position
	local billboard = create("BillboardGui", { Size = UDim2.fromOffset(200, 40), AlwaysOnTop = true, Parent = anchor })
	local label = text({
		Size = UDim2.fromScale(1, 1),
		Font = TITLE_FONT,
		Text = message,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		Parent = billboard,
	})
	TweenService:Create(billboard, TweenInfo.new(0.9), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, 1)
end

local SOURCE_NAMES = {
	Impact = "crash",
	Crossbow = "crossbow",
	Mine = "land mine",
	Grenade = "grenade",
	BouncePad = "bounce pad",
	RocketLauncher = "rocket",
	MachineGun = "machine gun",
	Saw = "saw",
	Flamethrower = "fire",
	BigTNT = "TNT",
	Laser = "laser",
	Spikes = "spikes",
	Fan = "fan",
	BoxingGlove = "boxing glove",
	BearTrap = "bear trap",
	Shotgun = "shotgun",
	Harpoon = "harpoon",
	Cannon = "cannon",
	TeslaCoil = "tesla coil",
	GravityFlipper = "gravity flip",
	FreezeRay = "freeze ray",
	AcidBlaster = "acid",
	StormCloud = "lightning",
	WreckingBall = "wrecking ball",
	BanHammer = "ban hammer",
	Railgun = "railgun",
	ClusterBomb = "cluster bomb",
	Minigun = "minigun",
	MissileSwarm = "missile",
	BlackHole = "black hole",
	MiniNuke = "NUKE",
}

-- The server tells us what each attack did to which body part
function Hud:showHit(reports, combo)
	for _, report in reports do
		local partName = report.part:upper()
		local color = if report.outcome then RED else YELLOW
		local points = Config.formatScore(report.points)
		floatingNumber(report.position, ("-%s %s"):format(points, partName), color)
		self:_addFeedLine(
			("-%s  %s  (%s)"):format(points, partName, SOURCE_NAMES[report.source] or report.source),
			color
		)

		if report.outcome == "Torn" then
			self:showBanner(("%s SNAPPED!"):format(report.joint:upper()))
			self:_addFeedLine(("✖ %s TORN OFF!"):format(partName), RED)
		elseif report.outcome == "Killed" then
			self:showBanner(if report.part == "Head" then "DECAPITATED!" else "DESTROYED!")
			self:_addFeedLine("☠ NOOB DESTROYED!", RED)
		end
	end

	if combo >= 2 then
		self.combo.Text = ("COMBO x%d!"):format(combo)
		self.combo.Visible = true
		self.comboScale.Scale = 1.4
		TweenService:Create(self.comboScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		self.comboHideAt = os.clock() + Config.COMBO_WINDOW
		task.delay(Config.COMBO_WINDOW, function()
			if os.clock() >= self.comboHideAt then
				self.combo.Visible = false
			end
		end)
	end
end

function Hud:showAchievement(id, weaponIds, reward)
	local achievement = Achievements.byId[id]
	if not achievement then
		return
	end
	local subtitle = ("+%s  %s"):format(Config.formatCash(reward or 0), achievement.description)
	if weaponIds and #weaponIds > 0 then
		local names = {}
		for _, weaponId in weaponIds do
			table.insert(names, Weapons.byId[weaponId].name)
		end
		subtitle = ("+%s  🎁 New weapon unlocked: %s"):format(Config.formatCash(reward or 0), table.concat(names, ", "))
	end
	self:showToast("🏆 " .. achievement.name:upper(), subtitle)
end

-- A pop-up that slides down from the top for a few seconds
function Hud:showToast(title, subtitle)
	table.insert(self.toastQueue, { title = title, subtitle = subtitle })
	if self.toastRunning then
		return
	end

	-- Show queued pop-ups one at a time
	self.toastRunning = true
	task.spawn(function()
		while #self.toastQueue > 0 do
			local entry = table.remove(self.toastQueue, 1)
			self.toastTitle.Text = entry.title
			self.toastSub.Text = entry.subtitle
			Sounds.playUI("Achievement")
			self.toast.Position = self:_toastPosition(false)
			local show = TweenInfo.new(0.35, Enum.EasingStyle.Back)
			TweenService:Create(self.toast, show, { Position = self:_toastPosition(true) }):Play()
			task.wait(3)
			local hide = TweenService:Create(self.toast, TweenInfo.new(0.25), { Position = self:_toastPosition(false) })
			hide:Play()
			hide.Completed:Wait()
		end
		self.toastRunning = false
	end)
end

-- The round leaderboard at the very end: everyone who played, most points first,
-- with the Noob Bucks the winner earned
function Hud:showResults(results)
	for _, child in self.results:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local winners = {}
	for _, entry in results do
		if entry.winner then
			table.insert(winners, entry.name)
		end
	end
	text({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 40),
		Font = TITLE_FONT,
		Text = "🏆 ROUND LEADERBOARD",
		TextColor3 = ORANGE,
		Parent = self.results,
	})
	text({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Font = TITLE_FONT,
		Text = if #winners > 0 then "WINNER: " .. table.concat(winners, " & ") .. "!" else "NO WINNER THIS TIME",
		TextColor3 = YELLOW,
		Parent = self.results,
	})
	local medals = { "🥇", "🥈", "🥉" }
	for rank, entry in results do
		local isMe = entry.userId == player.UserId
		local row = create("Frame", {
			LayoutOrder = 1 + rank,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = if entry.winner then Color3.fromRGB(80, 65, 20) elseif isMe then Color3.fromRGB(40, 70, 120) else Color3.fromRGB(55, 58, 70),
			Parent = self.results,
		}, { rounded(6) })
		local color = if entry.winner then YELLOW else WHITE
		text({
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.new(0, 40, 1, -6),
			Text = medals[rank] or ("#" .. rank),
			TextColor3 = color,
			Parent = row,
		})
		text({
			Position = UDim2.new(0, 50, 0, 3),
			Size = UDim2.new(0.5, -50, 1, -6),
			Text = entry.name .. (if isMe then " (you)" else "") .. (if entry.bestSequence then "  🎬" else ""),
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -70, 0, 3),
			Size = UDim2.new(0.5, -80, 1, -6),
			Text = Config.formatScore(entry.damage) .. " pts",
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
		text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 3),
			Size = UDim2.new(0, 60, 1, -6),
			Text = if (entry.bucks or 0) > 0 then ("+%d 💵"):format(entry.bucks) else "",
			TextColor3 = YELLOW,
			Parent = row,
		})
	end
	self.results.Visible = true
end

return Hud
