-- Spectating: players who aren't in the current round (they joined late, or the
-- rooms were full) can watch someone else's room. Switch between players with the
-- ◀ ▶ buttons, the mouse wheel, Q / E, or the arrow keys.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Sounds)

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local TITLE_FONT = Enum.Font.LuckiestGuy
local DARK = Color3.fromRGB(38, 40, 48)
local ORANGE = Color3.fromRGB(240, 140, 30)
local WHITE = Color3.new(1, 1, 1)

local Spectate = {}

local gui, spectateButton, watchBar, watchName, watchDamage, controls

-- Everyone playing this round, in room order: { { player, room } }
local function playersInRound()
	local list = {}
	for _, other in Players:GetPlayers() do
		local room = other:GetAttribute("Room") or 0
		if room > 0 then
			table.insert(list, { player = other, room = room })
		end
	end
	table.sort(list, function(a, b)
		return a.room < b.room
	end)
	return list
end

local function watchingRoom()
	return player:GetAttribute("Spectating") or 0
end

local function canSpectate()
	return Remotes.GameState:GetAttribute("Phase") == "Round" and (player:GetAttribute("Room") or 0) == 0
end

-- Moves to the next (+1) or previous (-1) player
local function cycle(step)
	local list = playersInRound()
	if #list == 0 then
		Remotes.Spectate:FireServer(0)
		return
	end
	local current = 1
	for index, entry in list do
		if entry.room == watchingRoom() then
			current = index
		end
	end
	local nextIndex = (current - 1 + step) % #list + 1
	Remotes.Spectate:FireServer(list[nextIndex].room)
	Sounds.playUI("Click")
end

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

local function button(text, size, color, parent)
	local textButton = Instance.new("TextButton")
	textButton.Size = size
	textButton.BackgroundColor3 = color
	textButton.Font = TITLE_FONT
	textButton.TextScaled = true
	textButton.TextColor3 = WHITE
	textButton.Text = text
	textButton.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = textButton
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = textButton
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = textButton
	return textButton
end

local function refresh()
	local watching = watchingRoom()
	local spectating = watching > 0 and Remotes.GameState:GetAttribute("Phase") == "Round"
	spectateButton.Visible = canSpectate() and not spectating and #playersInRound() > 0
	watchBar.Visible = spectating
	controls.Visible = spectating
	if not spectating then
		return
	end
	for _, entry in playersInRound() do
		if entry.room == watching then
			watchName.Text = ("👁 WATCHING  ROOM %d: %s"):format(entry.room, entry.player.DisplayName)
			watchDamage.Text = "💥 " .. Config.formatScore(entry.player:GetAttribute("Damage") or 0)
			return
		end
	end
	cycle(1) -- the player we were watching has gone: watch someone else
end

function Spectate.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "Spectate"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")

	spectateButton = button("👁 SPECTATE", UDim2.fromOffset(220, 54), Color3.fromRGB(110, 80, 220), gui)
	spectateButton.AnchorPoint = Vector2.new(0.5, 1)
	spectateButton.Position = UDim2.new(0.5, 0, 1, -24)
	spectateButton.Visible = false
	spectateButton.Activated:Connect(function()
		cycle(1)
	end)

	-- Who you're watching, along the top
	watchBar = Instance.new("Frame")
	watchBar.Size = UDim2.new(1, 0, 0, 56)
	watchBar.BackgroundColor3 = DARK
	watchBar.BackgroundTransparency = 0.1
	watchBar.BorderSizePixel = 0
	watchBar.Visible = false
	watchBar.Parent = gui
	watchName = label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(0.65, 0, 0, 40), Font = TITLE_FONT, Parent = watchBar })
	watchName.TextXAlignment = Enum.TextXAlignment.Left
	watchDamage = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 8),
		Size = UDim2.new(0.3, 0, 0, 40),
		Font = TITLE_FONT,
		TextColor3 = ORANGE,
		Parent = watchBar,
	})
	watchDamage.TextXAlignment = Enum.TextXAlignment.Right

	-- Arrows and the way back, along the bottom
	controls = Instance.new("Frame")
	controls.AnchorPoint = Vector2.new(0.5, 1)
	controls.Position = UDim2.new(0.5, 0, 1, -14)
	controls.Size = UDim2.fromOffset(440, 60)
	controls.BackgroundTransparency = 1
	controls.Visible = false
	controls.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = controls
	local previous = button("◀", UDim2.fromOffset(70, 56), DARK, controls)
	previous.LayoutOrder = 1
	local lobby = button("🏠 LOBBY", UDim2.fromOffset(180, 56), Color3.fromRGB(220, 70, 70), controls)
	lobby.LayoutOrder = 2
	local nextButton = button("▶", UDim2.fromOffset(70, 56), DARK, controls)
	nextButton.LayoutOrder = 3
	previous.Activated:Connect(function()
		cycle(-1)
	end)
	nextButton.Activated:Connect(function()
		cycle(1)
	end)
	lobby.Activated:Connect(function()
		Remotes.Spectate:FireServer(0)
		Sounds.playUI("Click")
	end)

	-- Scroll wheel, Q / E and arrow keys switch players too
	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel and watchBar.Visible then
			cycle(if input.Position.Z > 0 then -1 else 1)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not watchBar.Visible then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Left then
			cycle(-1)
		elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Right then
			cycle(1)
		end
	end)

	local sinceRefresh = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceRefresh += dt
		if sinceRefresh >= 0.2 then
			sinceRefresh = 0
			refresh()
		end
	end)
end

return Spectate
