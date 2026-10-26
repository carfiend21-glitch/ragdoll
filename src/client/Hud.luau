-- Everything on screen: round timer, damage, weapon menu, achievements list,
-- pop-ups and the results board.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(25, 25, 40)
local PANEL = Color3.fromRGB(35, 40, 60)
local ACCENT = Color3.fromRGB(255, 200, 40)
local LOCKED = Color3.fromRGB(90, 90, 105)
local UNLOCKED = Color3.fromRGB(60, 140, 80)
local TOAST_HIDDEN = UDim2.new(0.5, 0, 0, -200)
local TOAST_SHOWN = UDim2.new(0.5, 0, 0, 120)

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
	props.Font = FONT
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	props.TextWrapped = true
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.3
	return create("TextLabel", props, children)
end

local function button(props, children)
	props.Font = FONT
	props.TextColor3 = WHITE
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

local Hud = {}
Hud.__index = Hud

function Hud.new()
	local self = setmetatable({}, Hud)
	self.achievements = {} -- set of unlocked achievement ids
	self.selected = nil
	self.onWeaponClicked = nil -- set by Main: function(weaponId)
	self.toastQueue = {}
	self.hintHoldUntil = 0
	self.comboHideAt = 0

	local gui = create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	self:_buildTopBar()
	self:_buildWeaponBar()
	self:_buildAchievementPanel()
	self:_buildPopups()

	local refresh = function()
		self:_refreshStatus()
	end
	Remotes.GameState:GetAttributeChangedSignal("Phase"):Connect(refresh)
	Remotes.GameState:GetAttributeChangedSignal("TimeLeft"):Connect(refresh)
	player:GetAttributeChangedSignal("Room"):Connect(refresh)
	player:GetAttributeChangedSignal("Damage"):Connect(refresh)
	self:_refreshStatus()
	self:_updateHint()
	return self
end

function Hud:_buildTopBar()
	self.status = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(360, 40),
		Text = "",
		Parent = self.gui,
	})
	self.damage = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(260, 30),
		TextColor3 = ACCENT,
		Text = "",
		Parent = self.gui,
	})
	self.combo = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(220, 34),
		TextColor3 = Color3.fromRGB(255, 140, 40),
		Text = "",
		Visible = false,
		Parent = self.gui,
	})
	self.comboScale = create("UIScale", { Parent = self.combo })

	self.achievementsButton = button({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(190, 40),
		BackgroundColor3 = PANEL,
		Text = "🏆 Achievements",
		Parent = self.gui,
	}, { rounded(10), padding(6) })

	self.resetButton = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(150, 40),
		BackgroundColor3 = PANEL,
		Text = "🔄 Reset Noob",
		Visible = false,
		Parent = self.gui,
	}, { rounded(10), padding(6) })
	self.resetButton.Activated:Connect(function()
		Remotes.ResetNoob:FireServer()
	end)
end

function Hud:_buildWeaponBar()
	self.hint = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -112),
		Size = UDim2.fromOffset(520, 26),
		Text = "",
		Visible = false,
		Parent = self.gui,
	})
	self.bar = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(0, 96),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = self.gui,
	}, {
		rounded(14),
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})

	self.weaponButtons = {}
	for order, weapon in Weapons.list do
		local weaponButton = create("TextButton", {
			Name = weapon.id,
			LayoutOrder = order,
			Size = UDim2.fromOffset(80, 80),
			BackgroundColor3 = Color3.fromRGB(60, 70, 100),
			Text = "",
			Parent = self.bar,
		}, {
			rounded(10),
			create("UIStroke", {
				Name = "Highlight",
				Thickness = 3,
				Color = ACCENT,
				Enabled = false,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
		text({
			Position = UDim2.fromScale(0, 0.05),
			Size = UDim2.fromScale(1, 0.6),
			Text = weapon.icon,
			TextStrokeTransparency = 1,
			Parent = weaponButton,
		})
		text({
			Position = UDim2.new(0, 3, 0.68, 0),
			Size = UDim2.new(1, -6, 0.28, 0),
			Text = weapon.name,
			Parent = weaponButton,
		})
		text({
			Name = "Lock",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Text = "🔒",
			TextStrokeTransparency = 1,
			Parent = weaponButton,
		}, { rounded(10), padding(18) })

		weaponButton.Activated:Connect(function()
			self:_onWeaponButton(weapon)
		end)
		self.weaponButtons[weapon.id] = weaponButton
	end
end

function Hud:_buildAchievementPanel()
	self.panel = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		BackgroundColor3 = PANEL,
		Visible = false,
		ZIndex = 10,
		Parent = self.gui,
	}, { rounded(16), create("UISizeConstraint", { MaxSize = Vector2.new(520, 460) }) })

	text({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -76, 0, 40),
		Text = "🏆 Achievements",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.panel,
	})
	local close = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(220, 70, 70),
		Text = "X",
		Parent = self.panel,
	}, { rounded(10), padding(6) })
	close.Activated:Connect(function()
		self.panel.Visible = false
	end)
	self.achievementsButton.Activated:Connect(function()
		self.panel.Visible = not self.panel.Visible
	end)

	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 1, -72),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = self.panel,
	}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	self.rows = {}
	for order, achievement in Achievements.list do
		local rewards = {}
		for _, weapon in Weapons.list do
			if weapon.unlockedBy == achievement.id then
				table.insert(rewards, weapon.name)
			end
		end
		local detail = achievement.description
		if #rewards > 0 then
			detail ..= "  🎁 Unlocks: " .. table.concat(rewards, ", ")
		end

		local row = create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 72),
			BackgroundColor3 = LOCKED,
			Parent = list,
		}, { rounded(10) })
		local icon = text({
			Position = UDim2.fromOffset(8, 12),
			Size = UDim2.fromOffset(48, 48),
			Text = "🔒",
			TextStrokeTransparency = 1,
			Parent = row,
		})
		text({
			Position = UDim2.fromOffset(64, 6),
			Size = UDim2.new(1, -72, 0, 28),
			Text = achievement.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		text({
			Position = UDim2.fromOffset(64, 36),
			Size = UDim2.new(1, -72, 0, 30),
			Text = detail,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(225, 225, 235),
			TextStrokeTransparency = 1,
			Parent = row,
		}, { create("UITextSizeConstraint", { MaxTextSize = 16 }) })
		self.rows[achievement.id] = { frame = row, icon = icon }
	end
end

function Hud:_buildPopups()
	self.toast = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = TOAST_HIDDEN,
		Size = UDim2.fromOffset(380, 80),
		BackgroundColor3 = ACCENT,
		ZIndex = 20,
		Parent = self.gui,
	}, { rounded(14), create("UIStroke", { Thickness = 3, Color = INK }) })
	self.toastTitle = text({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 38),
		TextColor3 = INK,
		TextStrokeTransparency = 1,
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
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		Visible = false,
		ZIndex = 15,
		Parent = self.gui,
	}, {
		rounded(16),
		padding(14),
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

function Hud:_refreshStatus()
	local phase = Remotes.GameState:GetAttribute("Phase")
	local timeLeft = Remotes.GameState:GetAttribute("TimeLeft") or 0
	local room = player:GetAttribute("Room") or 0
	local playing = phase == "Round" and room > 0

	if phase == "Intermission" then
		self.status.Text = ("Next round in %d..."):format(timeLeft)
	elseif phase == "Round" then
		self.status.Text = if room > 0
			then ("⏱ %d:%02d"):format(timeLeft // 60, timeLeft % 60)
			else "Round in progress - you're up next!"
	elseif phase == "Results" then
		self.status.Text = "Round over!"
	else
		self.status.Text = "Waiting for players..."
	end

	self.damage.Visible = room > 0
	self.damage.Text = ("💥 Damage: %d"):format(player:GetAttribute("Damage") or 0)
	self.bar.Visible = playing
	self.hint.Visible = playing
	self.resetButton.Visible = playing
	if not playing then
		self.combo.Visible = false
	end
	if phase ~= "Results" then
		self.results.Visible = false
	end
end

-- Called with the list of achievement ids this player has
function Hud:setAchievements(list)
	self.achievements = {}
	local count = 0
	for _, id in list do
		if Achievements.byId[id] then
			self.achievements[id] = true
			count += 1
		end
	end
	self.achievementsButton.Text = ("🏆 Achievements %d/%d"):format(count, #Achievements.list)
	for _, weapon in Weapons.list do
		self.weaponButtons[weapon.id].Lock.Visible = not Weapons.isUnlocked(weapon, self.achievements)
	end
	for id, row in self.rows do
		local unlocked = self.achievements[id] == true
		row.icon.Text = if unlocked then "🏆" else "🔒"
		row.frame.BackgroundColor3 = if unlocked then UNLOCKED else LOCKED
	end
end

function Hud:_onWeaponButton(weapon)
	if not Weapons.isUnlocked(weapon, self.achievements) then
		local achievement = Achievements.byId[weapon.unlockedBy]
		self:flashHint(("🔒 Get \"%s\" to unlock: %s"):format(achievement.name, achievement.description))
		return
	end
	if self.onWeaponClicked then
		self.onWeaponClicked(weapon.id)
	end
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
		self.hint.Text = ("Pick a weapon! Drag weapons to move them, %s them to fire."):format(verb:lower())
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

function Hud:showAchievement(id, weaponIds)
	local achievement = Achievements.byId[id]
	if not achievement then
		return
	end
	local subtitle = achievement.description
	if weaponIds and #weaponIds > 0 then
		local names = {}
		for _, weaponId in weaponIds do
			table.insert(names, Weapons.byId[weaponId].name)
		end
		subtitle = "🎁 New weapon unlocked: " .. table.concat(names, ", ")
	end
	table.insert(self.toastQueue, { title = "🏆 " .. achievement.name, subtitle = subtitle })
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
			TweenService:Create(self.toast, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = TOAST_SHOWN }):Play()
			task.wait(3)
			local hide = TweenService:Create(self.toast, TweenInfo.new(0.25), { Position = TOAST_HIDDEN })
			hide:Play()
			hide.Completed:Wait()
		end
		self.toastRunning = false
	end)
end

-- A "+15" that floats up from where the noob got hit
function Hud:showHit(points, position, combo)
	local anchor = Instance.new("Attachment")
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position
	local billboard = create("BillboardGui", {
		Size = UDim2.fromOffset(120, 50),
		AlwaysOnTop = true,
		Parent = anchor,
	})
	local label = text({
		Size = UDim2.fromScale(1, 1),
		Text = "+" .. points,
		TextColor3 = if combo >= 2 then Color3.fromRGB(255, 140, 40) else Color3.fromRGB(255, 230, 80),
		TextStrokeTransparency = 0,
		Parent = billboard,
	})
	TweenService:Create(billboard, TweenInfo.new(0.8), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, 0.9)

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

function Hud:showResults(results)
	for _, child in self.results:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	text({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 44),
		Text = "🏁 Round Over!",
		TextColor3 = ACCENT,
		Parent = self.results,
	})
	local medals = { "🥇", "🥈", "🥉" }
	for rank, entry in results do
		text({
			LayoutOrder = rank,
			Size = UDim2.new(1, 0, 0, 34),
			Text = ("%s %s - %d damage"):format(medals[rank] or ("#" .. rank), entry.name, entry.damage),
			Parent = self.results,
		})
	end
	self.results.Visible = true
end

return Hud
