-- Server starting point: builds the world, sets up the rooms, listens to
-- players and starts the round loop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local AchievementService = require(script.Parent.AchievementService)
local Arena = require(script.Parent.Arena)
local PlayerData = require(script.Parent.PlayerData)
local RoundManager = require(script.Parent.RoundManager)
local WorldBuilder = require(script.Parent.WorldBuilder)

WorldBuilder.buildLobby()
local arenas = {}
for index, room in WorldBuilder.buildRooms() do
	arenas[index] = Arena.new(index, room, AchievementService)
end

RunService.Heartbeat:Connect(function()
	for _, arena in arenas do
		arena:step()
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

Remotes.ActivateItem.OnServerEvent:Connect(function(player, itemId)
	local arena = arenaFor(player)
	if arena then
		arena:activateItem(player, itemId)
	end
end)

Remotes.ResetNoob.OnServerEvent:Connect(function(player)
	local arena = arenaFor(player)
	if arena then
		arena:resetNoob(player)
	end
end)

Remotes.GetData.OnServerInvoke = function(player)
	PlayerData.waitFor(player)
	return PlayerData.getAchievementList(player)
end

local function onPlayerAdded(player)
	player:SetAttribute("Room", 0)
	player:SetAttribute("Damage", 0)
	PlayerData.load(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	for _, arena in arenas do
		if arena.owner == player then
			arena:clear()
		end
	end
	PlayerData.release(player)
end)

-- Save everyone when the server shuts down, and every minute just in case
game:BindToClose(PlayerData.saveAll)
task.spawn(function()
	while true do
		task.wait(60)
		PlayerData.saveAll()
	end
end)

RoundManager.run(arenas)
