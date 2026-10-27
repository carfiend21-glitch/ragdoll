-- Server starting point: builds the world, sets up the rooms, listens to
-- players and starts the round loop.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NoobBucks = require(Shared.NoobBucks)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)

local AchievementService = require(script.Parent.AchievementService)
local Arena = require(script.Parent.Arena)
local Leaderboards = require(script.Parent.Leaderboards)
local PlayerData = require(script.Parent.PlayerData)
local RoundManager = require(script.Parent.RoundManager)
local ShopService = require(script.Parent.ShopService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local lobby = WorldBuilder.buildLobby()
RoundManager.setLobbyScreen(lobby.screen)
Leaderboards.start(lobby)

-- Chat bubbles over players' heads, so the lobby feels like a place to hang out
pcall(function()
	game:GetService("TextChatService").BubbleChatConfiguration.Enabled = true
end)
local arenas = {}
for index, room in WorldBuilder.buildRooms() do
	arenas[index] = Arena.new(index, room, AchievementService)
end

RunService.Heartbeat:Connect(function(dt)
	for _, arena in arenas do
		arena:step(dt)
	end
end)

-- The room this player is playing in right now, if any
local function arenaFor(player)
	local arena = arenas[player:GetAttribute("Room")]
	if arena and arena.owner == player then
		return arena
	end
	return nil
end

Remotes.PlaceItem.OnServerEvent:Connect(function(player, weaponId, position)
	local arena = arenaFor(player)
	if arena then
		arena:placeItem(player, weaponId, position)
	end
end)

Remotes.MoveItem.OnServerEvent:Connect(function(player, itemId, position)
	local arena = arenaFor(player)
	if arena then
		arena:moveItem(player, itemId, position)
	end
end)

Remotes.RemoveItem.OnServerEvent:Connect(function(player, itemId)
	local arena = arenaFor(player)
	if arena then
		arena:takeOutItem(player, itemId)
	end
end)

-- PLAY / STOP button
Remotes.SetRunning.OnServerEvent:Connect(function(player, running)
	local arena = arenaFor(player)
	if arena then
		arena:setRunning(player, running)
	end
end)

-- RESTART button
Remotes.Restart.OnServerEvent:Connect(function(player)
	local arena = arenaFor(player)
	if arena then
		arena:restart(player)
	end
end)

-- Players who aren't in this round can watch someone else's room (0 = stop watching)
Remotes.Spectate.OnServerEvent:Connect(function(player, roomIndex)
	if roomIndex == 0 then
		player:SetAttribute("Spectating", 0)
		return
	end
	if typeof(roomIndex) ~= "number" or (player:GetAttribute("Room") or 0) > 0 then
		return -- bad request, or they're playing themselves
	end
	local arena = arenas[roomIndex]
	if arena and arena.active and arena.owner then
		player:SetAttribute("Spectating", roomIndex)
	end
end)

-- A player's screen is ready and asks for their data
Remotes.GetData.OnServerInvoke = function(player)
	PlayerData.waitFor(player)
	-- If a round is already going, send them the replay recorded so far
	task.defer(RoundManager.catchUp, player)
	return PlayerData.getSyncData(player)
end

-- Robux purchases: Roblox tells us when someone buys a Game Pass
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
	local weapon = Weapons.byGamePass[gamePassId]
	if not purchased or not weapon then
		return
	end
	PlayerData.grantWeapon(player, weapon.id)
	Remotes.DataSync:FireClient(player, PlayerData.getSyncData(player))
	Remotes.Notify:FireClient(player, "🎉 THANK YOU!", weapon.name .. " is now unlocked forever!")
end)

-- Spending Noob Bucks in the shop
ShopService.start()

-- Robux purchases of Noob Buck packs (Developer Products). Roblox keeps asking until
-- we say "granted", so we only say it once the coins are safely saved.
MarketplaceService.ProcessReceipt = function(receipt)
	local pack = NoobBucks.byProductId[receipt.ProductId]
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not pack or not player or not PlayerData.waitFor(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- they left: Roblox asks again next time
	end
	if not PlayerData.grantBuckPurchase(player, receipt.PurchaseId, pack.bucks) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Remotes.Notify:FireClient(player, ("💵 +%d NOOB BUCKS"):format(pack.bucks), "Thank you for your purchase!")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onPlayerAdded(player)
	player:SetAttribute("Room", 0)
	player:SetAttribute("Damage", 0)
	player:SetAttribute("Spectating", 0)
	PlayerData.load(player)
	if player.Parent then
		ShopService.watch(player) -- their title and trail
	end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	for _, arena in arenas do
		if arena.owner == player then
			arena:clear()
			-- Anyone watching them goes back to the lobby
			for _, viewer in Players:GetPlayers() do
				if viewer:GetAttribute("Spectating") == arena.index then
					viewer:SetAttribute("Spectating", 0)
				end
			end
		end
	end
	PlayerData.release(player)
end)

-- Save everyone when the server shuts down, and every minute just in case
game:BindToClose(PlayerData.saveAllAndWait)
task.spawn(function()
	while true do
		task.wait(60)
		PlayerData.saveAll()
	end
end)

RoundManager.run(arenas)
