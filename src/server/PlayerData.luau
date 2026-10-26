-- Loads and saves each player's achievements and wins using Roblox DataStores,
-- and checks which weapons they've bought with Robux (Roblox remembers those for us).
-- Cash is kept here too, but only for the current round: it's never saved.
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
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

-- [player] = { achievements = { [id] = true }, owned = { [weaponId] = true }, wins = number,
--              winsValue = IntValue, bestRun = number, cash = number, canSave = bool, dirty = bool,
--              saveQueued = bool }
local profiles = {}
local savesInProgress = 0
-- Roblox only lets us save the same player about once every 6 seconds
local SAVE_SOON_DELAY = 7

local function keyFor(player)
	return "Player_" .. player.UserId
end

-- Weapons this player has bought with Robux
local function loadOwnedWeapons(player)
	local owned = {}
	for _, weapon in Weapons.list do
		if weapon.gamePassId and weapon.gamePassId > 0 then
			local success, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, weapon.gamePassId)
			if success and result then
				owned[weapon.id] = true
			end
		end
	end
	return owned
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
				warn(
					"[PlayerData] Achievements WON'T be saved while testing in Studio until you turn on "
						.. "Home > Game Settings > Security > 'Enable Studio Access to API Services' "
						.. "(the game must be published first)."
				)
				break -- usually "API access not enabled"; retrying won't help
			end
			task.wait(2)
		end
	end
	local owned = loadOwnedWeapons(player)
	if not player.Parent then
		return -- they left while we were loading
	end

	local achievements = {}
	local wins = 0
	local bestRun = 0 -- most damage they've ever done in one run
	local cash = Config.STARTING_CASH -- cash isn't saved: everyone starts fresh
	if type(saved) == "table" then
		if type(saved.bestRun) == "number" then
			bestRun = saved.bestRun
		end
		if type(saved.achievements) == "table" then
			for id, value in saved.achievements do
				if value == true then
					achievements[id] = true
				end
			end
		end
		if type(saved.wins) == "number" then
			wins = saved.wins
		end
	end

	-- "leaderstats" shows up in the player list in the top-right corner:
	-- each player's name with their number of wins next to it
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local winsValue = Instance.new("IntValue")
	winsValue.Name = "Wins"
	winsValue.Value = wins
	winsValue.Parent = leaderstats
	leaderstats.Parent = player
	player:SetAttribute("Cash", cash) -- shown in the bottom bar

	-- If loading failed we don't save either, so we never overwrite real progress with an empty save
	profiles[player] = {
		achievements = achievements,
		owned = owned,
		wins = wins,
		winsValue = winsValue,
		bestRun = bestRun,
		cash = cash,
		canSave = loaded,
		dirty = false,
	}
end

function PlayerData.waitFor(player)
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

-- What the player's screen needs to know: { achievements = {ids}, ownedWeapons = {ids} }
function PlayerData.getSyncData(player)
	local data = { achievements = {}, ownedWeapons = {} }
	local profile = profiles[player]
	if profile then
		for id in profile.achievements do
			table.insert(data.achievements, id)
		end
		for id in profile.owned do
			table.insert(data.ownedWeapons, id)
		end
	end
	return data
end

-- Returns true if this is a brand-new unlock
function PlayerData.unlockAchievement(player, id)
	local profile = profiles[player]
	if not profile or profile.achievements[id] then
		return false
	end
	profile.achievements[id] = true
	profile.dirty = true
	-- Save it soon, rather than waiting for the once-a-minute save,
	-- so a new achievement is never lost if the game closes suddenly
	if not profile.saveQueued then
		profile.saveQueued = true
		task.delay(SAVE_SOON_DELAY, function()
			profile.saveQueued = false
			if profiles[player] == profile then
				PlayerData.save(player)
			end
		end)
	end
	return true
end

-- Called right after a Robux purchase (Roblox remembers it, so it isn't saved here)
function PlayerData.grantWeapon(player, weaponId)
	local profile = profiles[player]
	if profile then
		profile.owned[weaponId] = true
	end
end

-- Returns their new total of wins
function PlayerData.addWin(player)
	local profile = profiles[player]
	if not profile then
		return 0
	end
	profile.wins += 1
	profile.winsValue.Value = profile.wins
	profile.dirty = true
	return profile.wins
end

-- Returns true if `damage` beats their best ever run
function PlayerData.recordRun(player, damage)
	local profile = profiles[player]
	if not profile or damage <= profile.bestRun then
		return false
	end
	profile.bestRun = damage
	profile.dirty = true
	return true
end

-- Cash only lasts for one round, so it's never saved
local function setCash(player, profile, cash)
	profile.cash = cash
	player:SetAttribute("Cash", cash)
end

-- Back to the starting amount (at the start of every round)
function PlayerData.resetCash(player)
	local profile = profiles[player]
	if profile then
		setCash(player, profile, Config.STARTING_CASH)
	end
end

function PlayerData.getCash(player)
	local profile = profiles[player]
	return if profile then profile.cash else 0
end

-- Gives (or refunds) cash
function PlayerData.addCash(player, amount)
	local profile = profiles[player]
	if profile and amount > 0 then
		setCash(player, profile, profile.cash + math.floor(amount))
	end
end

-- Takes cash if they have enough. Returns true if it worked.
function PlayerData.spendCash(player, amount)
	local profile = profiles[player]
	if not profile or profile.cash < amount then
		return false
	end
	setCash(player, profile, profile.cash - amount)
	return true
end

function PlayerData.achievementCount(player)
	local count = 0
	local profile = profiles[player]
	if profile then
		for _ in profile.achievements do
			count += 1
		end
	end
	return count
end

function PlayerData.isWeaponUnlocked(player, weaponId)
	local weapon = Weapons.byId[weaponId]
	local profile = profiles[player]
	return weapon ~= nil and profile ~= nil and Weapons.isUnlocked(weapon, profile.achievements, profile.owned)
end

function PlayerData.save(player)
	local profile = profiles[player]
	if not store or not profile or not profile.canSave or not profile.dirty then
		return
	end
	profile.dirty = false
	savesInProgress += 1
	-- Mixed in with what's already saved rather than replacing it, so if this player
	-- hopped to another server and earned more there, nothing gets wiped out
	local success, result = pcall(store.UpdateAsync, store, keyFor(player), function(saved)
		local data = if type(saved) == "table" then saved else {}
		local achievements = if type(data.achievements) == "table" then data.achievements else {}
		for id in profile.achievements do
			achievements[id] = true
		end
		data.achievements = achievements
		data.wins = math.max(if type(data.wins) == "number" then data.wins else 0, profile.wins)
		data.bestRun = math.max(if type(data.bestRun) == "number" then data.bestRun else 0, profile.bestRun)
		return data, { player.UserId }
	end)
	savesInProgress -= 1
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
		task.spawn(PlayerData.save, player)
	end
end

-- When the server shuts down: save everyone, then wait for every save
-- (including ones from players who just left) to finish before letting it close
function PlayerData.saveAllAndWait()
	PlayerData.saveAll()
	local waited = 0
	while savesInProgress > 0 and waited < 25 do
		waited += task.wait(0.1)
	end
end

return PlayerData
