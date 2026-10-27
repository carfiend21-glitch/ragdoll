-- The Noob Buck shop on the server: checks and saves purchases, remembers what
-- everyone has equipped, and puts titles and trails on players in the lobby.
-- (Noob skins, blood, rooms and weapon finishes are put on by Arena at round start.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local ShopItems = require(Shared.ShopItems)

local PlayerData = require(script.Parent.PlayerData)

local ShopService = {}

-- Shown at the start of a round (not straight away)
local ROUND_LOOKS = { NoobSkin = true, Blood = true, Room = true, Finish = true }

-- A title floating over the player's head
local function applyTitle(character, item)
	local head = character:FindFirstChild("Head")
	local old = head and head:FindFirstChild("ShopTitle")
	if old then
		old:Destroy()
	end
	if not head or not item.color then
		return -- "No Title"
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ShopTitle"
	billboard.Size = UDim2.fromOffset(220, 30)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = item.name
	label.TextColor3 = item.color
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	billboard.Parent = head
end

-- A colored trail that follows the player around
local function applyTrail(character, item)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, name in { "ShopTrail", "ShopTrailTop", "ShopTrailBottom" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	if not item.colors then
		return -- "No Trail"
	end
	local top = Instance.new("Attachment")
	top.Name = "ShopTrailTop"
	top.Position = Vector3.new(0, 0.9, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "ShopTrailBottom"
	bottom.Position = Vector3.new(0, -0.9, 0)
	bottom.Parent = root
	local keypoints = {}
	for index, color in item.colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#item.colors - 1), color))
	end
	local trail = Instance.new("Trail")
	trail.Name = "ShopTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(keypoints)
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Lifetime = 0.6
	trail.LightEmission = 0.4
	trail.Parent = root
end

local function applyLobbyLooks(player)
	local character = player.Character
	if not character then
		return
	end
	local equipped = PlayerData.getEquipped(player)
	applyTitle(character, ShopItems.equippedItem(equipped, "Title"))
	applyTrail(character, ShopItems.equippedItem(equipped, "Trail"))
end

local function equip(player, item)
	PlayerData.equipShopItem(player, item.id)
	Remotes.DataSync:FireClient(player, PlayerData.getSyncData(player))
	if item.category == "Title" or item.category == "Trail" then
		applyLobbyLooks(player)
	elseif ROUND_LOOKS[item.category] and (player:GetAttribute("Room") or 0) > 0 then
		Remotes.Hint:FireClient(player, item.name .. " will show from your next round.")
	end
end

-- Does the player own this shop item already? (A weapon counts if they've unlocked it
-- any way at all, apart from renting it.)
local function owns(player, item)
	if item.kind == "unlock" then
		return PlayerData.ownsWeapon(player, item.weapon)
	end
	return PlayerData.ownsShopItem(player, item.id)
end

local function buy(player, id)
	local item = ShopItems.byId[id]
	if typeof(id) ~= "string" or not item or item.price <= 0 then
		return
	end
	local name = item.name
	local price = ShopItems.priceFor(item, os.time()) -- (the deal of the day is cheaper)
	if item.kind == "unlock" or item.kind == "rent" then
		if PlayerData.ownsWeapon(player, item.weapon) then
			Remotes.Notify:FireClient(player, "ALREADY UNLOCKED", "You already have the " .. name .. ".")
			return
		end
		if item.kind == "rent" and PlayerData.isRenting(player, item.weapon) then
			Remotes.Notify:FireClient(player, "ALREADY RENTED", "It's yours until the end of the next round you place it in.")
			return
		end
	elseif item.kind == "bundle" then
		-- Only pay for the part of the bundle you don't have yet
		price = ShopItems.bundlePrice(item, function(content)
			return owns(player, content)
		end)
		if price <= 0 then
			Remotes.Notify:FireClient(player, "ALREADY OWNED", "You already have everything in the " .. name .. " bundle.")
			return
		end
	elseif PlayerData.ownsShopItem(player, id) then
		return
	end
	if not PlayerData.buyShopItem(player, id, price) then
		Remotes.Notify:FireClient(player, "NOT ENOUGH NOOB BUCKS", ("The %s costs %d."):format(name, price))
		return
	end
	if ShopItems.defaults[item.category] then
		equip(player, item) -- wear it straight away
	elseif item.kind == "bundle" then
		-- Put on the looks that came in it
		for _, contentId in item.contents do
			local content = ShopItems.byId[contentId]
			if ShopItems.defaults[content.category] then
				equip(player, content)
			end
		end
		Remotes.DataSync:FireClient(player, PlayerData.getSyncData(player))
	else
		Remotes.DataSync:FireClient(player, PlayerData.getSyncData(player))
	end
	local subtitle = if item.kind == "rent"
		then "Use it for one round: it lasts until the end of the round you place it in."
		elseif item.kind == "unlock" then "It's on your weapon bar now."
		elseif item.kind == "bundle" then "Everything in it is yours!"
		else "Equipped!"
	Remotes.Notify:FireClient(player, "🛍️ " .. name:upper(), subtitle)
end

function ShopService.start()
	Remotes.BuyShopItem.OnServerEvent:Connect(buy)
	Remotes.EquipShopItem.OnServerEvent:Connect(function(player, id)
		local item = ShopItems.byId[id]
		if typeof(id) == "string" and item and PlayerData.ownsShopItem(player, id) then
			equip(player, item)
		end
	end)
end

-- Puts a player's title and trail on them now and every time they respawn
function ShopService.watch(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		character:WaitForChild("Head", 10)
		applyLobbyLooks(player)
	end)
	applyLobbyLooks(player)
end

return ShopService
