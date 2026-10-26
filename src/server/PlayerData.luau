-- Loads and saves each player's achievements using Roblox DataStores.
-- (Unlocked weapons come from achievements, so achievements are all we save.)
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)

local PlayerData = {}

local store = nil
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
end)
if not ok then
	warn("[PlayerData] Saving is turned off: " .. tostring(err))
end

local profiles = {} -- [player] = { achievements = { [id] = true }, canSave = bool, dirty = bool }

local function keyFor(player)
	return "Player_" .. player.UserId
end

function PlayerData.load(player)
	local saved, loaded = nil, false
	if store then
		for attempt = 1, 3 do
			local success, result = pcall(store.GetAsync, store, keyFor(player))
			if success then
				saved, loaded = result, true
				break
			end
			warn(("[PlayerData] Couldn't load %s (try %d): %s"):format(player.Name, attempt, tostring(result)))
			if RunService:IsStudio() then
				break -- usually "API access not enabled"; retrying won't help
			end
			task.wait(2)
		end
	end
	if not player.Parent then
		return -- they left while we were loading
	end

	local achievements = {}
	if type(saved) == "table" and type(saved.achievements) == "table" then
		for id, value in saved.achievements do
			if value == true then
				achievements[id] = true
			end
		end
	end
	-- If loading failed we don't save either, so we never overwrite real progress with an empty save
	profiles[player] = { achievements = achievements, canSave = loaded, dirty = false }
end

function PlayerData.waitFor(player)
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

function PlayerData.getAchievementList(player)
	local list = {}
	local profile = profiles[player]
	if profile then
		for id in profile.achievements do
			table.insert(list, id)
		end
	end
	return list
end

-- Returns true if this is a brand-new unlock
function PlayerData.unlockAchievement(player, id)
	local profile = profiles[player]
	if not profile or profile.achievements[id] then
		return false
	end
	profile.achievements[id] = true
	profile.dirty = true
	return true
end

function PlayerData.isWeaponUnlocked(player, weaponId)
	local weapon = Weapons.byId[weaponId]
	local profile = profiles[player]
	return weapon ~= nil and profile ~= nil and Weapons.isUnlocked(weapon, profile.achievements)
end

function PlayerData.save(player)
	local profile = profiles[player]
	if not store or not profile or not profile.canSave or not profile.dirty then
		return
	end
	profile.dirty = false
	local data = { achievements = profile.achievements }
	local success, result = pcall(store.SetAsync, store, keyFor(player), data, { player.UserId })
	if not success then
		profile.dirty = true -- try again next time
		warn(("[PlayerData] Couldn't save %s: %s"):format(player.Name, tostring(result)))
	end
end

function PlayerData.release(player)
	PlayerData.save(player)
	profiles[player] = nil
end

function PlayerData.saveAll()
	for player in profiles do
		PlayerData.save(player)
	end
end

return PlayerData
