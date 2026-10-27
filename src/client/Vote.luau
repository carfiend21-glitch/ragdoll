-- The "best sequence" vote screen, straight after the winner's replay: a card for each
-- of the top 3, and (if it's your turn to vote) you tap the one whose attacks were best.
-- The server runs the vote (see server/SequenceVote); this just shows it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NoobBucks = require(Shared.NoobBucks)
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Sounds)

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local TITLE_FONT = Enum.Font.LuckiestGuy
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(25, 25, 35)
local DARK = Color3.fromRGB(38, 40, 48)
local CARD = Color3.fromRGB(55, 58, 70)
local GOLD = Color3.fromRGB(255, 200, 60)
local GREEN = Color3.fromRGB(40, 175, 80)
local GREY = Color3.fromRGB(85, 88, 100)
local PLACE_COLORS = { Color3.fromRGB(255, 205, 50), Color3.fromRGB(205, 210, 220), Color3.fromRGB(215, 140, 80) }
local MEDALS = { "🥇", "🥈", "🥉" }

local Vote = {}

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

local function text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.3
	return create("TextLabel", props)
end

local function rounded(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local gui = nil
local row = nil -- where the cards go
local title, subtitle, progress, timer = nil, nil, nil, nil
local cards = {} -- [userId] = { frame, button, votes (TextLabel), stroke }
local myVote = nil -- who I voted for (kept through a tie-break unless I have to vote again)
local canVote = false
local names = {} -- [userId] = name

local function build()
	gui = create("ScreenGui", {
		Name = "SequenceVote",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8, -- above the HUD and the shop
		Parent = player:WaitForChild("PlayerGui"),
	})
	local background = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(12, 10, 20),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	title = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.08, 0),
		Size = UDim2.new(0.9, 0, 0, 50),
		Font = TITLE_FONT,
		Text = "🎬 BEST SEQUENCE OF ATTACKS?",
		TextColor3 = GOLD,
		TextStrokeTransparency = 0,
		Parent = background,
	})
	subtitle = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.08, 56),
		Size = UDim2.new(0.85, 0, 0, 30),
		Text = "",
		Parent = background,
	})
	row = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(0.9, 0, 0.45, 0),
		BackgroundTransparency = 1,
		Parent = background,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 14),
		}),
		create("UISizeConstraint", { MaxSize = Vector2.new(760, 300) }),
	})
	progress = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.92, 0),
		Size = UDim2.new(0.6, 0, 0, 26),
		Text = "",
		Parent = background,
	})
	timer = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.92, -30),
		Size = UDim2.new(0.3, 0, 0, 34),
		Font = TITLE_FONT,
		Text = "",
		TextColor3 = Color3.fromRGB(240, 140, 30),
		Parent = background,
	})
end

-- One card per player in the top 3
local function buildCards(candidates)
	for _, card in cards do
		card.frame:Destroy()
	end
	cards = {}
	for _, candidate in candidates do
		names[candidate.userId] = candidate.name
		local color = PLACE_COLORS[candidate.place] or WHITE
		local frame = create("Frame", {
			LayoutOrder = candidate.place,
			Size = UDim2.new(1 / 3, -14, 1, 0),
			BackgroundColor3 = CARD,
			Parent = row,
		}, { rounded(12) })
		local stroke = create("UIStroke", { Thickness = 3, Color = color, Parent = frame })
		text({
			Position = UDim2.fromScale(0, 0.04),
			Size = UDim2.fromScale(1, 0.24),
			Font = TITLE_FONT,
			Text = MEDALS[candidate.place] or "",
			Parent = frame,
		})
		text({
			Position = UDim2.fromScale(0.05, 0.3),
			Size = UDim2.fromScale(0.9, 0.17),
			Font = TITLE_FONT,
			Text = candidate.name,
			TextColor3 = color,
			Parent = frame,
		})
		text({
			Position = UDim2.fromScale(0.05, 0.48),
			Size = UDim2.fromScale(0.9, 0.11),
			Text = "💥 " .. Config.formatScore(candidate.damage) .. " pts",
			Parent = frame,
		})
		local votes = text({
			Position = UDim2.fromScale(0.05, 0.6),
			Size = UDim2.fromScale(0.9, 0.12),
			Font = TITLE_FONT,
			Text = "",
			TextColor3 = GOLD,
			Parent = frame,
		})
		local button = create("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0.18, 0),
			BackgroundColor3 = GREEN,
			Font = TITLE_FONT,
			TextScaled = true,
			TextColor3 = WHITE,
			Text = "VOTE",
			Parent = frame,
		}, { rounded(8), create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })
		button.Activated:Connect(function()
			if canVote and button.Active then
				Sounds.playUI("Click")
				canVote = false
				myVote = candidate.userId
				Remotes.CastVote:FireServer(candidate.userId)
				Vote.refreshButtons()
			end
		end)
		cards[candidate.userId] = { frame = frame, button = button, votes = votes, stroke = stroke }
	end
end

-- What each card's button says: VOTE, your pick, or greyed out
function Vote.refreshButtons(allowed)
	for userId, card in cards do
		local mine = myVote == userId
		local open = canVote and (allowed == nil or allowed[userId]) and userId ~= player.UserId
		card.button.Active = open
		card.button.AutoButtonColor = open
		card.button.Visible = open or mine
		card.button.Text = if mine then "✔ YOUR VOTE" else "VOTE"
		card.button.BackgroundColor3 = if mine then GOLD elseif open then GREEN else GREY
		card.button.TextColor3 = if mine then INK else WHITE
	end
end

local function showCounts(counts)
	for _, pair in counts or {} do
		local card = cards[pair[1]]
		if card then
			card.votes.Text = ("%d VOTE%s"):format(pair[2], if pair[2] == 1 then "" else "S")
		end
	end
end

-- A vote (or a tie-break vote) is starting
local function onStart(info)
	if not gui then
		build()
	end
	gui.Enabled = true
	local allowed = {}
	for _, userId in info.options do
		allowed[userId] = true
	end
	canVote = table.find(info.voters, player.UserId) ~= nil
	if not info.runoff then
		myVote = nil
		buildCards(info.candidates)
		title.Text = "🎬 BEST SEQUENCE OF ATTACKS?"
	else
		-- The ones knocked out of the tie-break fade away
		showCounts(info.counts)
		for _, userId in info.out do
			local card = cards[userId]
			if card then
				card.frame.BackgroundTransparency = 0.6
				card.stroke.Transparency = 0.7
				card.votes.Text ..= "  ✖ OUT"
			end
		end
		if canVote then
			myVote = nil
		end
		local tied = {}
		for _, userId in info.options do
			table.insert(tied, names[userId] or "?")
		end
		title.Text = "⚖️ TIE! " .. table.concat(tied, " vs ")
	end
	if canVote then
		subtitle.Text = if info.runoff
			then "Your pick is out! Vote again between the tied players."
			else ("Who had the best attacks? Your pick wins %d Noob Buck 💵"):format(NoobBucks.VOTE_REWARD)
	elseif myVote then
		subtitle.Text = ("Your vote for %s still counts. Waiting for the tie-break..."):format(names[myVote] or "them")
	elseif cards[player.UserId] then
		subtitle.Text = "You made the top 3! The lobby is voting on your attacks..."
	else
		subtitle.Text = "Waiting for the votes..."
	end
	progress.Text = ("0 / %d voted"):format(#info.voters)
	Vote.refreshButtons(allowed)
	Sounds.playUI("Sparkle")
end

local function onResult(info)
	if not gui then
		return
	end
	canVote = false
	Vote.refreshButtons()
	showCounts(info.counts)
	local winner = names[info.winner] or "Someone"
	title.Text = ("👑 %s WINS BEST SEQUENCE!"):format(winner:upper())
	subtitle.Text = if info.coinFlip
		then ("Still tied, so a coin flip decided it! +%d 💵"):format(NoobBucks.VOTE_REWARD)
		else ("+%d Noob Buck 💵"):format(NoobBucks.VOTE_REWARD)
	progress.Text = ""
	local card = cards[info.winner]
	if card then
		card.stroke.Color = GOLD
		card.stroke.Thickness = 6
		local scale = create("UIScale", { Scale = 0.8, Parent = card.frame })
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1.08 }):Play()
	end
	Sounds.playUI("Achievement")
end

function Vote.start()
	Remotes.VoteUpdate.OnClientEvent:Connect(function(kind, info)
		if kind == "start" then
			onStart(info)
		elseif kind == "progress" and progress then
			progress.Text = ("%d / %d voted"):format(info.voted, info.total)
		elseif kind == "random" and subtitle then
			-- We ran out of time: the server picked for us
			myVote = info
			canVote = false
			Vote.refreshButtons()
			subtitle.Text = ("Time's up! A random vote went to %s."):format(names[info] or "someone")
		elseif kind == "result" then
			onResult(info)
		end
	end)
	-- The timer, and hiding the screen once the vote is over
	local function onPhase()
		local phase = Remotes.GameState:GetAttribute("Phase")
		if gui then
			gui.Enabled = phase == "Vote"
			timer.Text = if phase == "Vote" then ("⏱ %d"):format(Remotes.GameState:GetAttribute("TimeLeft") or 0) else ""
		end
	end
	Remotes.GameState:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	Remotes.GameState:GetAttributeChangedSignal("TimeLeft"):Connect(onPhase)
end

return Vote
