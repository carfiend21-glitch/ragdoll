-- Your Noob Bucks, shown in the top-right corner as the Noob Buck logo (the classic noob
-- on a green dollar bill) and "x100", and the Noob Buck shop it opens: the deal of the
-- day and bundles, exclusive weapons, weapons to unlock early, 1-round trials, noob
-- skins, blood, rooms, weapon finishes, titles and trails, plus Noob Buck packs to buy
-- with Robux.
-- The server checks every purchase (see server/ShopService); this is just the window.
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NoobBucks = require(Shared.NoobBucks)
local Remotes = require(Shared.Remotes)
local ShopItems = require(Shared.ShopItems)
local Sounds = require(Shared.Sounds)
local Weapons = require(Shared.Weapons)

local WeaponIcon = require(script.Parent.WeaponIcon)

local BuckShop = {}

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne
local TITLE_FONT = Enum.Font.LuckiestGuy
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(25, 25, 35)
local DARK = Color3.fromRGB(38, 40, 48)
local CARD = Color3.fromRGB(55, 58, 70)
local GOLD = Color3.fromRGB(255, 200, 60)
local GREEN = Color3.fromRGB(0, 170, 90)
local BLUE = Color3.fromRGB(40, 120, 220)
local GREY = Color3.fromRGB(85, 88, 100)
local RED = Color3.fromRGB(220, 50, 50)
local COUNTER_HEIGHT = 40
local CONFIRM_SECONDS = 3 -- how long "BUY?" waits for the second click
local BUCKS_TAB = "Bucks"
local FEATURED_TAB = "Featured"
local CARD_SIZE = Vector2.new(142, 176)

-- The classic room's colors, for the room previews (same as server/WorldBuilder)
local CLASSIC_ROOM = {
	Wall = Color3.fromRGB(205, 208, 214),
	BackWall = Color3.fromRGB(232, 234, 238),
	Floor = Color3.fromRGB(95, 98, 105),
}

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

local function button(props, children)
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	props.AutoButtonColor = true
	return create("TextButton", props, children)
end

local function rounded(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function outline(thickness, color)
	return create("UIStroke", { Thickness = thickness, Color = color or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function padding(pixels)
	local size = UDim.new(0, pixels)
	return create("UIPadding", { PaddingLeft = size, PaddingRight = size, PaddingTop = size, PaddingBottom = size })
end

-- "x1,234"
local function countText(coins)
	local digits = tostring(math.floor(coins)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "x" .. digits:gsub("^,", "")
end

-- A tiny noob inside a ViewportFrame, so it can sit on the screen like an icon.
-- `skin` is a noob skin from ShopItems (classic if nil).
local function miniNoob(parent, size, position, skin)
	local viewport = create("ViewportFrame", {
		Size = size,
		Position = position or UDim2.new(),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = WHITE,
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	})
	local parts = {}
	local specs = {
		{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) },
		{ "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0) },
		{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0) },
		{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0) },
		{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0) },
		{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0) },
	}
	for _, spec in specs do
		local part = create("Part", { Name = spec[1], Size = spec[2], CFrame = CFrame.new(spec[3]), Anchored = true, Parent = viewport })
		table.insert(parts, part)
		if spec[1] == "Head" then
			create("SpecialMesh", { MeshType = Enum.MeshType.Head, Scale = Vector3.one * 1.25, Parent = part })
			create("Decal", { Texture = "rbxasset://textures/face.png", Face = Enum.NormalId.Front, Parent = part })
		end
	end
	ShopItems.applyNoobSkin(parts, skin or ShopItems.byId.ClassicNoob)
	-- Looking at the front of the noob (its face points -Z), from slightly to one side
	local camera = create("Camera", { FieldOfView = 30, CFrame = CFrame.lookAt(Vector3.new(4, 1.5, -12), Vector3.new(0, -0.3, 0)), Parent = viewport })
	viewport.CurrentCamera = camera
	return viewport
end

local BILL_GREEN = Color3.fromRGB(70, 160, 80)
local BILL_DARK = Color3.fromRGB(25, 85, 40)
local BILL_LIGHT = Color3.fromRGB(190, 235, 190)

-- The Noob Buck logo: a green dollar bill with the classic noob in the oval in the
-- middle, like the face on a real bill. It's twice as wide as it is tall.
local function noobBuck(parent, size, position)
	local bill = create("Frame", {
		Size = size,
		Position = position or UDim2.new(),
		BackgroundColor3 = BILL_GREEN,
		Parent = parent,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0.12, 0) }),
		create("UIStroke", { Thickness = 2, Color = BILL_DARK }),
		create("UIAspectRatioConstraint", { AspectRatio = 2 }),
	})
	-- A thin light line just inside the edge, like a real bill's border
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		BackgroundTransparency = 1,
		Parent = bill,
	}, { create("UIStroke", { Thickness = 1, Color = BILL_LIGHT, Transparency = 0.2 }), create("UICorner", { CornerRadius = UDim.new(0.1, 0) }) })
	-- "$" on both ends
	for _, x in { 0.13, 0.87 } do
		create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromScale(0.2, 0.62),
			BackgroundTransparency = 1,
			Font = TITLE_FONT,
			Text = "$",
			TextColor3 = BILL_LIGHT,
			TextScaled = true,
			Parent = bill,
		})
	end
	-- The oval portrait with the noob in it
	local portrait = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.86),
		BackgroundColor3 = BILL_LIGHT,
		ClipsDescendants = true,
		Parent = bill,
	}, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), create("UIStroke", { Thickness = 1, Color = BILL_DARK }) })
	miniNoob(portrait, UDim2.fromScale(1.3, 1.3), UDim2.fromScale(-0.15, -0.02))
	return bill
end

-- A little pile of Noob Bucks for a pack card: more bills for bigger packs
local function buckPile(parent, bills)
	local area = create("Frame", { Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0.06), BackgroundTransparency = 1, Parent = parent })
	for index = 1, bills do
		-- Each bill a bit higher and to the side of the one under it
		local spread = (index - (bills + 1) / 2)
		local bill = noobBuck(area, UDim2.fromScale(0.8, 0.4), UDim2.fromScale(0.1 + spread * 0.04, 0.5 - index * 0.06))
		bill.ZIndex = index -- each one on top of the last
	end
end

-- The picture at the top of each shop card (`height` = how much of the card it fills)
local function preview(item, parent, height)
	local area = create("Frame", { Size = UDim2.fromScale(1, height or 0.52), BackgroundTransparency = 1, Parent = parent })
	local category = item.category
	if item.kind == "bundle" then
		-- Everything in the bundle, side by side
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 2),
			Parent = area,
		})
		for order, id in item.contents do
			local content = ShopItems.byId[id]
			local cell = create("Frame", {
				LayoutOrder = order,
				Size = UDim2.fromScale(1 / #item.contents - 0.02, 0.9),
				BackgroundColor3 = Color3.fromRGB(70, 74, 90),
				Parent = area,
			}, { rounded(6) })
			if content.weapon then
				WeaponIcon.create(content.weapon, cell, UDim2.fromScale(1, 1))
			elseif content.category == "NoobSkin" then
				miniNoob(cell, UDim2.fromScale(1, 1), nil, content)
			else
				text({
					Size = UDim2.fromScale(1, 1),
					Font = TITLE_FONT,
					Text = if content.category == "Trail" then "🌈" else "🏷️",
					TextStrokeTransparency = 1,
					Parent = cell,
				})
			end
		end
	elseif category == "NoobSkin" then
		miniNoob(area, UDim2.fromScale(1, 1), nil, item)
	elseif item.weapon then
		WeaponIcon.create(item.weapon, area, UDim2.fromScale(1, 1))
	elseif category == "Blood" then
		for index = 1, 3 do
			create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.25 * index, 0.5 + (index % 2) * 0.12),
				Size = UDim2.fromScale(0.22, 0.36),
				BackgroundColor3 = item.colors[(index - 1) % #item.colors + 1],
				Parent = area,
			}, { rounded(99), create("UIAspectRatioConstraint", {}) })
		end
	elseif category == "Room" then
		-- Back wall, with side walls and the floor around it
		local theme = item.theme
		local box = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.85),
			BackgroundColor3 = if theme.Wall then theme.Wall[1] else CLASSIC_ROOM.Wall,
			Parent = area,
		}, { rounded(6) })
		create("Frame", {
			Position = UDim2.fromScale(0.15, 0.1),
			Size = UDim2.fromScale(0.7, 0.62),
			BackgroundColor3 = if theme.BackWall then theme.BackWall[1] else CLASSIC_ROOM.BackWall,
			Parent = box,
		})
		create("Frame", {
			Position = UDim2.fromScale(0, 0.72),
			Size = UDim2.fromScale(1, 0.28),
			BackgroundColor3 = if theme.Floor then theme.Floor[1] else CLASSIC_ROOM.Floor,
			Parent = box,
		}, { rounded(6) })
	elseif category == "Finish" then
		local color = item.color or Color3.fromRGB(60, 65, 70)
		text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.8),
			BackgroundTransparency = 0,
			BackgroundColor3 = color,
			Text = "🏹",
			TextStrokeTransparency = 1,
			Parent = area,
		})
	elseif category == "Title" then
		text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.95, 0.4),
			Font = TITLE_FONT,
			Text = if item.color then item.name else "—",
			TextColor3 = item.color or GREY,
			Parent = area,
		})
	elseif category == "Trail" then
		local bar = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.3),
			BackgroundColor3 = if item.colors then WHITE else GREY,
			Parent = area,
		}, { rounded(99) })
		if item.colors then
			local keypoints = {}
			for index, color in item.colors do
				table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#item.colors - 1), color))
			end
			create("UIGradient", { Color = ColorSequence.new(keypoints), Parent = bar })
		end
	end
	return area
end

-- A little colored tag in a corner of a card ("NEW", "-40%")
local function badge(parent, label, color, rightSide)
	local tag = text({
		AnchorPoint = Vector2.new(if rightSide then 1 else 0, 0),
		Position = if rightSide then UDim2.new(1, -4, 0, 4) else UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(44, 18),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		Font = TITLE_FONT,
		Text = label,
		TextStrokeTransparency = 1,
		ZIndex = 3,
		Parent = parent,
	})
	rounded(5).Parent = tag
	return tag
end

-- "💥 ~170 dmg · $1,900" under a weapon's name: what it does, and what it costs in a round
local function weaponStats(weaponId)
	local weapon = Weapons.byId[weaponId]
	return ("💥 ~%d dmg · %s"):format(weapon.damage, Config.formatCash(weapon.price))
end

-- "5h 12m" / "12m 30s"
local function timeText(seconds)
	seconds = math.floor(seconds)
	if seconds >= 3600 then
		return ("%dh %02dm"):format(seconds // 3600, seconds % 3600 // 60)
	end
	return ("%dm %02ds"):format(seconds // 60, seconds % 60)
end

-- The Noob Buck pack cards (bought with Robux)
local function buildPacks(page, notice)
	text({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 24),
		Text = ("Win a round to earn %d. Or grab a pack:"):format(NoobBucks.WIN_REWARD),
		Parent = page,
	})
	local row = create("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 180), BackgroundTransparency = 1, Parent = page }, {
		create("UIGridLayout", {
			CellSize = UDim2.new(1 / #NoobBucks.PACKS, -8, 1, 0),
			CellPadding = UDim2.fromOffset(8, 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, pack in NoobBucks.PACKS do
		local card = create("TextButton", {
			LayoutOrder = index,
			BackgroundColor3 = if pack.best then Color3.fromRGB(70, 55, 20) else CARD,
			Text = "",
			AutoButtonColor = true,
			Parent = row,
		}, { rounded(10), outline(2, if pack.best then GOLD else INK) })
		buckPile(card, index + 1)
		text({ Position = UDim2.fromScale(0.05, 0.56), Size = UDim2.fromScale(0.9, 0.17), Font = TITLE_FONT, Text = countText(pack.bucks), TextColor3 = GOLD, Parent = card })
		create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(0.86, 0, 0.18, 0),
			BackgroundColor3 = GREEN,
			Font = FONT,
			Text = ("R$ %d"):format(pack.robux),
			TextColor3 = WHITE,
			TextScaled = true,
			Parent = card,
		}, { rounded(6) })
		if pack.best then
			text({ Position = UDim2.fromScale(0.05, 0.005), Size = UDim2.fromScale(0.9, 0.11), Text = "BEST DEAL", TextColor3 = GOLD, Parent = card })
		end
		card.Activated:Connect(function()
			Sounds.playUI("Click")
			if pack.productId > 0 then
				MarketplaceService:PromptProductPurchase(player, pack.productId)
			else
				notice.Text = "This pack isn't on sale yet."
			end
		end)
	end
end

function BuckShop.start()
	local self = {
		data = { achievements = {}, ownedWeapons = {}, shopItems = {}, equipped = {}, rentals = {} },
		cards = {}, -- { item, action (TextButton), dealBadge?, frame }
		cardsById = {}, -- [item id] = the card in its own tab (for jumping to it)
		pages = {}, -- [tab id] = ScrollingFrame
		tabs = {}, -- [tab id] = TextButton
		confirming = nil, -- the item waiting for its second click
	}

	local gui = create("ScreenGui", {
		Name = "NoobBucks",
		ResetOnSpawn = false,
		IgnoreGuiInset = true, -- so the counter can sit up in Roblox's top bar strip
		DisplayOrder = 5, -- above the HUD, below the replays
		Parent = player:WaitForChild("PlayerGui"),
	})

	---------------------------------------------------------------------------
	-- The counter in the top-right corner
	---------------------------------------------------------------------------
	local counter = button({
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(196, COUNTER_HEIGHT),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.15,
		Text = "",
		Parent = gui,
	}, { rounded(10), outline(2, GOLD) })
	local counterScale = create("UIScale", { Parent = counter })
	-- The Noob Buck logo, then "x1"
	local logoWidth = (COUNTER_HEIGHT - 10) * 2
	noobBuck(counter, UDim2.fromOffset(logoWidth, COUNTER_HEIGHT - 10), UDim2.fromOffset(6, 5))
	local count = text({
		Position = UDim2.fromOffset(logoWidth + 12, 4),
		Size = UDim2.new(1, -(logoWidth + 12) - 56, 1, -8),
		Font = TITLE_FONT,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = countText(0),
		Parent = counter,
	})
	local shopBadge = text({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -5, 0.5, 0),
		Size = UDim2.fromOffset(50, 26),
		BackgroundTransparency = 0,
		BackgroundColor3 = GREEN,
		Text = "SHOP",
		TextStrokeTransparency = 1,
		Parent = counter,
	})
	rounded(8).Parent = shopBadge
	-- A little red "SALE" tag on the SHOP button: there's always a deal on
	local saleTag = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 2),
		Size = UDim2.fromOffset(40, 16),
		BackgroundTransparency = 0,
		BackgroundColor3 = RED,
		Font = TITLE_FONT,
		Text = "SALE",
		TextStrokeTransparency = 1,
		Parent = counter,
	})
	rounded(5).Parent = saleTag

	-- Up in the top-right corner, in Roblox's top bar strip if there's room
	-- (so it never covers the game's own menus)
	local function place()
		local inset = GuiService:GetGuiInset().Y
		local y = if inset >= COUNTER_HEIGHT + 4 then (inset - COUNTER_HEIGHT) / 2 else inset + 8
		counter.Position = UDim2.new(1, -12, 0, y)
	end
	place()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)

	---------------------------------------------------------------------------
	-- The shop window
	---------------------------------------------------------------------------
	local window = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.94, 0.8),
		BackgroundColor3 = DARK,
		Visible = false,
		Parent = gui,
	}, { rounded(14), outline(3, GOLD), create("UISizeConstraint", { MaxSize = Vector2.new(820, 520) }) })
	text({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(0.5, 0, 0, 36),
		Font = TITLE_FONT,
		Text = "💵 NOOB BUCK SHOP",
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	local balance = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -56, 0, 12),
		Size = UDim2.fromOffset(170, 32),
		Font = TITLE_FONT,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = window,
	})
	local close = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = RED,
		Text = "X",
		Parent = window,
	}, { rounded(8) })
	close.Activated:Connect(function()
		window.Visible = false
	end)
	local notice = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -32, 0, 22),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 190, 120),
		Parent = window,
	})

	-- Tabs down the left side
	local tabList = create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 56),
		Size = UDim2.new(0, 150, 1, -90),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local pageHolder = create("Frame", {
		Position = UDim2.fromOffset(170, 56),
		Size = UDim2.new(1, -182, 1, -90),
		BackgroundTransparency = 1,
		Parent = window,
	})

	-- The gold tabs (Featured and Get Bucks) stand out from the rest
	local GOLD_TABS = { [FEATURED_TAB] = true, [BUCKS_TAB] = true }
	local function showTab(id)
		for tabId, page in self.pages do
			page.Visible = tabId == id
			self.tabs[tabId].BackgroundColor3 = if tabId == id
				then (if GOLD_TABS[tabId] then Color3.fromRGB(150, 110, 20) else BLUE)
				else (if GOLD_TABS[tabId] then Color3.fromRGB(95, 75, 25) else CARD)
		end
	end

	local function newPage(id, label, order, grid)
		local tab = button({
			LayoutOrder = order,
			Size = UDim2.new(1, -6, 0, 38),
			BackgroundColor3 = CARD,
			Text = label,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = tabList,
		}, { rounded(8), padding(7) })
		tab.Activated:Connect(function()
			Sounds.playUI("Click")
			notice.Text = ""
			showTab(id)
		end)
		local page = create("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = false,
			Parent = pageHolder,
		}, {
			if grid
				then create("UIGridLayout", {
					CellSize = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
					CellPadding = UDim2.fromOffset(10, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				})
				else create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
			padding(4),
		})
		self.tabs[id] = tab
		self.pages[id] = page
		return page
	end

	-- Has the player unlocked this weapon for good (not counting a rental)? And are they renting it?
	local function weaponState(weaponId)
		local data = self.data
		local owned = {}
		for _, id in data.ownedWeapons do
			owned[id] = true
		end
		local rented = table.find(data.rentals, weaponId) ~= nil
		if rented then
			owned[weaponId] = nil -- a rental doesn't mean you own it
		end
		local achievements = {}
		for _, id in data.achievements do
			achievements[id] = true
		end
		return Weapons.isUnlocked(Weapons.byId[weaponId], achievements, owned), rented
	end

	-- Does the player already have this item? (like the server's check, in ShopService)
	local function owns(item)
		if item.kind == "unlock" then
			return (weaponState(item.weapon))
		end
		return item.price == 0 or table.find(self.data.shopItems, item.id) ~= nil
	end

	-- What a card's button says and does, given what the player has.
	-- Returns the label, its color, what clicking does, and the price right now.
	local function cardState(item)
		local coins = player:GetAttribute("NoobBucks") or 0
		local now = os.time()
		local price = ShopItems.priceFor(item, now)
		local worth = item.price -- what it would cost without any discount
		if item.weapon then
			local unlocked, rented = weaponState(item.weapon)
			if unlocked then
				return "UNLOCKED", GREY, nil, price
			elseif rented then
				return "RENTED ✔", GREY, nil, price
			end
		elseif item.kind == "bundle" then
			price, worth = ShopItems.bundlePrice(item, owns)
			if price == 0 then
				return "OWNED ✔", GREY, nil, 0
			end
		else
			if owns(item) then
				local equipped = ShopItems.equippedItem(self.data.equipped, item.category)
				if equipped.id == item.id then
					return "EQUIPPED", GREY, nil, price
				end
				return "EQUIP", BLUE, "equip", price
			end
		end
		-- Cheaper than usual (the deal of the day, or a bundle): show the old price crossed out
		local priceText = if price < worth then ("<s>%d</s> %d"):format(worth, price) else tostring(price)
		if self.confirming == item then
			return "BUY? 💵 " .. priceText, GOLD, "buy", price
		end
		return "💵 " .. priceText, if coins >= price then GREEN else Color3.fromRGB(130, 50, 50), "confirm", price
	end

	local function refresh()
		local coins = player:GetAttribute("NoobBucks") or 0
		balance.Text = "💵 " .. countText(coins)
		count.Text = countText(coins)
		local deal = ShopItems.dealOfTheDay(os.time())
		for _, card in self.cards do
			local label, color = cardState(card.item)
			card.action.Text = label
			card.action.BackgroundColor3 = color
			card.action.TextColor3 = if color == GOLD then INK else WHITE
			if card.dealBadge then
				card.dealBadge.Visible = card.item == deal
			end
		end
	end
	self.refresh = refresh

	local function onCardClicked(item)
		local _, _, action, price = cardState(item)
		if not action then
			return
		end
		Sounds.playUI("Click")
		local coins = player:GetAttribute("NoobBucks") or 0
		if action == "equip" then
			Remotes.EquipShopItem:FireServer(item.id)
		elseif action == "confirm" then
			if coins < price then
				-- Not enough: show them the coin packs
				showTab(BUCKS_TAB)
				notice.Text = ("You need %d more Noob Bucks for the %s."):format(price - coins, item.name)
				return
			end
			-- First click asks "BUY?", the second click buys, so nobody buys by accident
			self.confirming = item
			task.delay(CONFIRM_SECONDS, function()
				if self.confirming == item then
					self.confirming = nil
					refresh()
				end
			end)
		elseif action == "buy" then
			self.confirming = nil
			Remotes.BuyShopItem:FireServer(item.id)
		end
		refresh()
	end

	-- One shop card: a picture, the name, and a buy/equip button
	local function buildCard(item, parent, order)
		local card = create("Frame", { LayoutOrder = order, BackgroundColor3 = CARD, Parent = parent }, { rounded(10), outline(2) })
		preview(item, card)
		local weapon = item.weapon and Weapons.byId[item.weapon]
		text({
			Position = UDim2.new(0, 6, 0.53, 0),
			Size = UDim2.new(1, -12, if weapon or item.kind == "bundle" then 0.14 else 0.2, 0),
			Text = if item.kind == "rent" then item.name .. " (1 round)" else item.name,
			Parent = card,
		})
		-- What a weapon does and costs in a round, or what a bundle saves
		if weapon or item.kind == "bundle" then
			local saving = if weapon then weaponStats(item.weapon) else nil
			if item.kind == "bundle" then
				local total = 0
				for _, id in item.contents do
					total += ShopItems.byId[id].price
				end
				saving = ("SAVE %d%%"):format(math.floor((1 - item.price / total) * 100 + 0.5))
			end
			text({
				Position = UDim2.new(0, 6, 0.67, 0),
				Size = UDim2.new(1, -12, 0.11, 0),
				Text = saving,
				TextColor3 = if item.kind == "bundle" then GOLD else Color3.fromRGB(200, 205, 220),
				TextStrokeTransparency = 1,
				Parent = card,
			})
		end
		local action = button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0.18, 0),
			BackgroundColor3 = GREEN,
			RichText = true,
			Text = "",
			Parent = card,
		}, { rounded(8), padding(3) })
		action.Activated:Connect(function()
			onCardClicked(item)
		end)
		if item.new then
			badge(card, "NEW", Color3.fromRGB(40, 170, 80))
		end
		local dealBadge = nil
		if item.kind ~= "bundle" and item.kind ~= "rent" and item.price >= 10 then
			dealBadge = badge(card, ("-%d%%"):format(ShopItems.DEAL_DISCOUNT * 100), RED, true)
			dealBadge.Visible = false
		end
		-- Exclusive weapons can be bought with Robux too, once their Game Pass is set up
		if weapon and item.kind == "unlock" and weapon.gamePassId and weapon.gamePassId > 0 then
			local robux = button({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 26),
				Size = UDim2.fromOffset(58, 20),
				BackgroundColor3 = Color3.fromRGB(30, 140, 70),
				Text = ("R$ %d"):format(item.robux or 0),
				ZIndex = 3,
				Parent = card,
			}, { rounded(5), padding(2) })
			robux.Activated:Connect(function()
				Sounds.playUI("Click")
				MarketplaceService:PromptGamePassPurchase(player, weapon.gamePassId)
			end)
		end
		table.insert(self.cards, { item = item, action = action, dealBadge = dealBadge, frame = card })
		return card
	end

	---------------------------------------------------------------------------
	-- Featured: the deal of the day, then the bundles
	---------------------------------------------------------------------------
	local featured = newPage(FEATURED_TAB, "🔥 Featured", 0, false)
	local dealHeader = text({
		LayoutOrder = 1,
		Size = UDim2.new(1, -8, 0, 26),
		Font = TITLE_FONT,
		Text = "🔥 DEAL OF THE DAY",
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = featured,
	})
	local dealRow = create("Frame", { LayoutOrder = 2, Size = UDim2.new(1, -8, 0, CARD_SIZE.Y), BackgroundTransparency = 1, Parent = featured })
	local dealCard = nil
	local dealItem = nil
	local dealPitch = text({
		Position = UDim2.fromOffset(CARD_SIZE.X + 14, 0),
		Size = UDim2.new(1, -(CARD_SIZE.X + 14), 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		RichText = true,
		Parent = dealRow,
	})
	create("UITextSizeConstraint", { MaxTextSize = 22, Parent = dealPitch })
	-- Builds the deal card (again, when a new day brings a new deal)
	local function showDeal()
		local now = os.time()
		local deal = ShopItems.dealOfTheDay(now)
		if deal ~= dealItem then
			if dealCard then
				for index, card in self.cards do
					if card.frame == dealCard then
						table.remove(self.cards, index)
						break
					end
				end
				dealCard:Destroy()
			end
			dealItem = deal
			dealCard = buildCard(deal, dealRow, 1)
			dealCard.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
			dealCard.UIStroke.Color = GOLD
			local price = ShopItems.priceFor(deal, now)
			dealPitch.Text = ("<b>%s</b>\nNormally 💵 %d, today only 💵 <font color=\"#FFC83C\"><b>%d</b></font>!\n\n%s"):format(
				deal.name:upper(),
				deal.price,
				price,
				if deal.weapon then Weapons.byId[deal.weapon].description else "Look the part in every round."
			)
			refresh()
		end
		dealHeader.Text = ("🔥 DEAL OF THE DAY  ·  ends in %s"):format(timeText(ShopItems.dealEndsIn(now)))
	end

	text({
		LayoutOrder = 3,
		Size = UDim2.new(1, -8, 0, 26),
		Font = TITLE_FONT,
		Text = "🎁 BUNDLES: MORE FOR LESS",
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = featured,
	})
	local bundles = create("Frame", {
		LayoutOrder = 4,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = featured,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local bundleOrder = 0
	for _, item in ShopItems.list do
		if item.kind == "bundle" then
			bundleOrder += 1
			buildCard(item, bundles, bundleOrder)
		end
	end

	---------------------------------------------------------------------------
	-- A tab for each category, then the Noob Buck packs
	---------------------------------------------------------------------------
	for order, category in ShopItems.CATEGORIES do
		local page = newPage(category.id, category.icon .. " " .. category.name, order, true)
		local cardOrder = 0
		for _, item in ShopItems.list do
			if item.category == category.id then
				cardOrder += 1
				self.cardsById[item.id] = buildCard(item, page, cardOrder)
			end
		end
	end
	local bucksPage = newPage(BUCKS_TAB, "💵 Get Bucks", #ShopItems.CATEGORIES + 1, false)
	buildPacks(bucksPage, notice)
	showTab(FEATURED_TAB)
	showDeal()

	counter.Activated:Connect(function()
		Sounds.playUI("Click")
		window.Visible = not window.Visible
		notice.Text = ""
		showDeal()
		refresh()
	end)
	-- Keep the deal's countdown ticking while the shop is open
	task.spawn(function()
		while true do
			task.wait(1)
			if window.Visible then
				showDeal()
			end
		end
	end)

	-- Keep the number up to date, with a little pop when it goes up
	local shown = player:GetAttribute("NoobBucks") or 0
	player:GetAttributeChangedSignal("NoobBucks"):Connect(function()
		local coins = player:GetAttribute("NoobBucks") or 0
		if coins > shown then
			counterScale.Scale = 1.3
			TweenService:Create(counterScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			Sounds.playUI("Cash")
		end
		shown = coins
		refresh()
	end)
	refresh()

	-- What the player owns (from the server's DataSync / GetData)
	function self.setData(data)
		self.data = data
		refresh()
	end

	-- Opens the shop right on the card that unlocks a weapon (from the weapon bar)
	function self.openOnWeapon(weaponId)
		local item = ShopItems.unlockFor(weaponId)
		local card = item and self.cardsById[item.id]
		if not card then
			return
		end
		window.Visible = true
		showDeal()
		showTab(item.category)
		refresh()
		notice.Text = ("Unlock the %s here, then place it from your weapon bar!"):format(item.name)
		-- Scroll down to it, and make it flash gold for a moment
		local page = self.pages[item.category]
		task.defer(function()
			page.CanvasPosition = Vector2.new(0, math.max(0, card.AbsolutePosition.Y - page.AbsolutePosition.Y + page.CanvasPosition.Y - 8))
		end)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		stroke.Color = GOLD
		stroke.Thickness = 4
		task.delay(2, function()
			stroke.Color = INK
			stroke.Thickness = 2
		end)
	end
	return self
end

return BuckShop
