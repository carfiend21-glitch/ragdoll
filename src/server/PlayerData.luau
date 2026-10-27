-- Loads and saves each player's achievements, wins, Noob Bucks and Noob Buck shop
-- items using Roblox DataStores, and checks which weapons they've bought with Robux
-- (Roblox remembers those for us).
-- Cash is kept here too, but only for the current round: it's never saved.
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NoobBucks = require(Shared.NoobBucks)
local ShopItems = require(Shared.ShopItems)
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
--              saveQueued = bool, noobBucks = number, unsavedBucks = number,
--              purchases = { [purchaseId] = true }, items = { [shop item id] = true },
--              equipped = { [shop category] = item id }, rentals = { [weaponId] = true } }
-- Noob Bucks are saved as "+X since the last save" (`unsavedBucks`) added onto whatever
-- is saved, so two servers saving at once can never wipe out each other's coins.
local profiles = {}
local savesInProgress = 0
-- Roblox only lets us save the same player about once every 6 seconds
local SAVE_SOON_DELAY = 7
-- How many Robux purchase IDs to remember, so a purchase is never given twice
local PURCHASES_REMEMBERED = 100

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
	-- The 2x Noob Bucks Game Pass
	local doubleBucks = false
	if NoobBucks.DOUBLE_PASS.gamePassId > 0 then
		local success, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, NoobBucks.DOUBLE_PASS.gamePassId)
		doubleBucks = success and result == true
	end
	if not player.Parent then
		return -- they left while we were loading
	end

	local achievements = {}
	local wins = 0
	local sequenceWins = 0 -- times the lobby voted their attacks the best sequence
	local boostUntil = 0 -- when their 1-hour 2x Noob Bucks boost runs out (os.time())
	local bestRun = 0 -- most damage they've ever done in one run
	local cash = Config.STARTING_CASH -- cash isn't saved: everyone starts fresh
	local noobBucks = 0
	local purchases = {} -- set of purchase IDs
	local purchaseOrder = {} -- the same IDs, oldest first
	local items = {} -- Noob Buck shop items they own
	local equipped = {} -- [shop category] = item id
	local rentals = {} -- [weaponId] = true while rented
	if type(saved) == "table" then
		if type(saved.noobBucks) == "number" then
			noobBucks = saved.noobBucks
		elseif type(saved.noobCoins) == "number" then
			noobBucks = saved.noobCoins -- saved before Noob Coins were renamed Noob Bucks
		end
		if type(saved.items) == "table" then
			for _, id in saved.items do
				if ShopItems.byId[id] then
					items[id] = true
				end
			end
		end
		if type(saved.equipped) == "table" then
			for category, id in saved.equipped do
				local item = ShopItems.byId[id]
				if item and item.category == category then
					equipped[category] = id
				end
			end
		end
		if type(saved.rentals) == "table" then
			for weaponId, value in saved.rentals do
				rentals[weaponId] = value == true or nil
			end
		end
		if type(saved.purchases) == "table" then
			for _, purchaseId in saved.purchases do
				purchases[purchaseId] = true
				table.insert(purchaseOrder, purchaseId)
			end
		end
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
		if type(saved.sequenceWins) == "number" then
			sequenceWins = saved.sequenceWins
		end
		if type(saved.boostUntil) == "number" then
			boostUntil = saved.boostUntil
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
	player:SetAttribute("NoobBucks", noobBucks) -- shown in the top-right corner
	-- 2x Noob Bucks (shown in the shop and next to the counter)
	player:SetAttribute("DoubleBucks", doubleBucks)
	player:SetAttribute("BoostUntil", boostUntil)

	-- If loading failed we don't save either, so we never overwrite real progress with an empty save
	profiles[player] = {
		achievements = achievements,
		owned = owned,
		wins = wins,
		winsValue = winsValue,
		sequenceWins = sequenceWins,
		doubleBucks = doubleBucks,
		boostUntil = boostUntil,
		bestRun = bestRun,
		cash = cash,
		canSave = loaded,
		dirty = false,
		noobBucks = noobBucks,
		unsavedBucks = 0,
		purchases = purchases,
		purchaseOrder = purchaseOrder,
		items = items,
		equipped = equipped,
		rentals = rentals,
	}
end

-- Saves soon, rather than waiting for the once-a-minute save, so something new
-- (an achievement, coins) is never lost if the game closes suddenly
local function saveSoon(player, profile)
	if profile.saveQueued then
		return
	end
	profile.saveQueued = true
	task.delay(SAVE_SOON_DELAY, function()
		profile.saveQueued = false
		if profiles[player] == profile then
			PlayerData.save(player)
		end
	end)
end

function PlayerData.waitFor(player)
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Weapons they can use without the achievement: bought with Robux, unlocked with
-- Noob Bucks, or (unless `skipRentals`) rented for a round
local function extraWeapons(profile, skipRentals)
	local weapons = table.clone(profile.owned)
	for id in profile.items do
		local item = ShopItems.byId[id]
		if item.kind == "unlock" then
			weapons[item.weapon] = true
		end
	end
	if not skipRentals then
		for weaponId in profile.rentals do
			weapons[weaponId] = true
		end
	end
	return weapons
end

-- What the player's screen needs to know: { achievements = {ids}, ownedWeapons = {ids},
-- shopItems = {ids}, equipped = { [category] = id }, rentals = {weapon ids} }
function PlayerData.getSyncData(player)
	local data = { achievements = {}, ownedWeapons = {}, shopItems = {}, equipped = {}, rentals = {} }
	local profile = profiles[player]
	if profile then
		for id in profile.achievements do
			table.insert(data.achievements, id)
		end
		for id in extraWeapons(profile) do
			table.insert(data.ownedWeapons, id)
		end
		for id in profile.items do
			table.insert(data.shopItems, id)
		end
		data.equipped = table.clone(profile.equipped)
		for weaponId in profile.rentals do
			table.insert(data.rentals, weaponId)
		end
	end
	return data
end

function PlayerData.ownsShopItem(player, id)
	local profile = profiles[player]
	local item = ShopItems.byId[id]
	return profile ~= nil and item ~= nil and (item.price == 0 or profile.items[id] == true)
end

-- Has a weapon been unlocked any way at all (achievement, Robux, Noob Bucks, rental)?
function PlayerData.isWeaponUnlocked(player, weaponId)
	local weapon = Weapons.byId[weaponId]
	local profile = profiles[player]
	return weapon ~= nil and profile ~= nil and Weapons.isUnlocked(weapon, profile.achievements, extraWeapons(profile))
end

-- Has the weapon been bought for good (with Robux or Noob Bucks, or by its achievement)?
-- Rentals don't count.
function PlayerData.ownsWeapon(player, weaponId)
	local weapon = Weapons.byId[weaponId]
	local profile = profiles[player]
	return weapon ~= nil and profile ~= nil and Weapons.isUnlocked(weapon, profile.achievements, extraWeapons(profile, true))
end

-- How many weapons the player has unlocked for good (rentals don't count), and
-- whether one of them is an exclusive weapon
function PlayerData.unlockedWeaponStats(player)
	local profile = profiles[player]
	if not profile then
		return 0, false
	end
	local extra = extraWeapons(profile, true)
	local count, hasExclusive = 0, false
	for _, weapon in Weapons.list do
		if Weapons.isUnlocked(weapon, profile.achievements, extra) then
			count += 1
			hasExclusive = hasExclusive or weapon.exclusive == true
		end
	end
	return count, hasExclusive
end

function PlayerData.isRenting(player, weaponId)
	local profile = profiles[player]
	return profile ~= nil and profile.rentals[weaponId] == true
end

-- Spends `price` Noob Bucks on a shop item (its price, or less if it's the deal of the
-- day). A bundle gives you everything in it. Returns true if they had enough.
function PlayerData.buyShopItem(player, id, price)
	local profile = profiles[player]
	local item = ShopItems.byId[id]
	if not profile or not item or profile.noobBucks < price then
		return false
	end
	PlayerData.addNoobBucks(player, -price)
	if item.kind == "rent" then
		profile.rentals[item.weapon] = true
	else
		profile.items[id] = true
		for _, contentId in item.contents or {} do
			profile.items[contentId] = true
		end
	end
	profile.dirty = true
	return true
end

function PlayerData.equipShopItem(player, id)
	local profile = profiles[player]
	local item = ShopItems.byId[id]
	if not profile or not item then
		return
	end
	profile.equipped[item.category] = id
	profile.dirty = true
	saveSoon(player, profile)
end

-- { [category] = item id } of everything they're wearing
function PlayerData.getEquipped(player)
	local profile = profiles[player]
	return if profile then profile.equipped else {}
end

-- A rented weapon got used for a round: it's gone now
-- A rented weapon was placed in a round: it'll be used up when that round ends
function PlayerData.useRental(player, weaponId)
	local profile = profiles[player]
	if profile and profile.rentals[weaponId] then
		profile.rentalsUsed = profile.rentalsUsed or {}
		profile.rentalsUsed[weaponId] = true
	end
end

-- The round ended: rented weapons that got placed are used up. Ones they rented but
-- never got to place (say they couldn't afford it that round) stay for next round.
-- Returns true if anything was used up.
function PlayerData.endRentals(player)
	local profile = profiles[player]
	if not profile or not profile.rentalsUsed then
		return false
	end
	local changed = false
	for weaponId in profile.rentalsUsed do
		if profile.rentals[weaponId] then
			profile.rentals[weaponId] = nil
			changed = true
		end
	end
	profile.rentalsUsed = nil
	if changed then
		profile.dirty = true
		saveSoon(player, profile)
	end
	return changed
end

-- Returns true if this is a brand-new unlock
function PlayerData.unlockAchievement(player, id)
	local profile = profiles[player]
	if not profile or profile.achievements[id] then
		return false
	end
	profile.achievements[id] = true
	profile.dirty = true
	saveSoon(player, profile)
	return true
end

-- Gives (or, with a negative amount, takes) Noob Bucks. Returns their new total.
function PlayerData.addNoobBucks(player, amount)
	local profile = profiles[player]
	if not profile then
		return 0
	end
	profile.noobBucks += amount
	profile.unsavedBucks += amount
	profile.dirty = true
	player:SetAttribute("NoobBucks", profile.noobBucks)
	saveSoon(player, profile)
	return profile.noobBucks
end

-- A Robux pack of Noob Bucks was bought. Gives the coins (only once per purchase,
-- even if Roblox asks again) and saves straight away. Returns true once it's safely
-- saved; if it returns false, Roblox will ask again later.
function PlayerData.grantBuckPurchase(player, purchaseId, coins)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if not profile.purchases[purchaseId] then
		profile.purchases[purchaseId] = true
		table.insert(profile.purchaseOrder, purchaseId)
		PlayerData.addNoobBucks(player, coins)
	end
	if not store or not profile.canSave then
		-- Can't save (testing in Studio without API access): give them anyway so
		-- test purchases work, but in a live game wait until it can be saved
		return RunService:IsStudio()
	end
	return PlayerData.save(player)
end

-- Called right after a Robux purchase (Roblox remembers it, so it isn't saved here)
-- 2 if this player's Noob Bucks rewards are doubled right now (Game Pass or 1-hour boost), else 1
function PlayerData.bucksMultiplier(player)
	local profile = profiles[player]
	if not profile then
		return 1
	end
	return NoobBucks.multiplier(profile.doubleBucks, profile.boostUntil, os.time())
end

-- They just bought the 2x Noob Bucks Game Pass (Roblox remembers it for next time)
function PlayerData.grantDoubleBucks(player)
	local profile = profiles[player]
	if profile then
		profile.doubleBucks = true
		player:SetAttribute("DoubleBucks", true)
	end
end

-- They bought a 2x Noob Bucks boost: `seconds` more of it, on top of any time left.
-- Like Noob Buck packs, each purchase is only given once, and only counts as done once saved.
function PlayerData.grantBoost(player, purchaseId, seconds)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if not profile.purchases[purchaseId] then
		profile.purchases[purchaseId] = true
		table.insert(profile.purchaseOrder, purchaseId)
		profile.boostUntil = math.max(profile.boostUntil, os.time()) + seconds
		profile.dirty = true
		player:SetAttribute("BoostUntil", profile.boostUntil)
	end
	if not store or not profile.canSave then
		return RunService:IsStudio() -- (see grantBuckPurchase)
	end
	return PlayerData.save(player)
end

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

-- The lobby voted their attacks the best sequence of the round. Returns their new total.
function PlayerData.addSequenceWin(player)
	local profile = profiles[player]
	if not profile then
		return 0
	end
	profile.sequenceWins += 1
	profile.dirty = true
	return profile.sequenceWins
end

-- Their saved wins, best run and best-sequence votes (nil if their data didn't load),
-- so the lobby leaderboards can be brought up to date when they join
function PlayerData.leaderboardStats(player)
	local profile = profiles[player]
	if not profile or not profile.canSave then
		return nil
	end
	return { wins = profile.wins, bestRun = profile.bestRun, sequenceWins = profile.sequenceWins }
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

-- Returns true if everything is saved (or there was nothing new to save)
function PlayerData.save(player)
	local profile = profiles[player]
	if not store or not profile or not profile.canSave then
		return false
	end
	-- One save at a time per player, so a purchase never counts as saved while
	-- an older save (that doesn't include it) is still going
	while profile.saving do
		task.wait(0.1)
	end
	if not profile.dirty then
		return true
	end
	profile.dirty = false
	profile.saving = true
	savesInProgress += 1
	local bucksToAdd = profile.unsavedBucks
	local purchaseOrder = table.clone(profile.purchaseOrder or {})
	local savedBucks = nil
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
		data.sequenceWins = math.max(if type(data.sequenceWins) == "number" then data.sequenceWins else 0, profile.sequenceWins)
		data.boostUntil = math.max(if type(data.boostUntil) == "number" then data.boostUntil else 0, profile.boostUntil)
		data.bestRun = math.max(if type(data.bestRun) == "number" then data.bestRun else 0, profile.bestRun)
		-- (Saves from before the rename used "noobCoins": move those over)
		local before = if type(data.noobBucks) == "number"
			then data.noobBucks
			elseif type(data.noobCoins) == "number" then data.noobCoins
			else 0
		data.noobCoins = nil
		data.noobBucks = before + bucksToAdd
		savedBucks = data.noobBucks
		-- Shop items they own (never lost), what they're wearing, and rentals
		local items = if type(data.items) == "table" then data.items else {}
		for id in profile.items do
			if not table.find(items, id) then
				table.insert(items, id)
			end
		end
		data.items = items
		data.equipped = profile.equipped
		data.rentals = profile.rentals
		-- Remember recent Robux purchases (oldest dropped first)
		local purchases = if type(data.purchases) == "table" then data.purchases else {}
		for _, purchaseId in purchaseOrder do
			if not table.find(purchases, purchaseId) then
				table.insert(purchases, purchaseId)
			end
		end
		while #purchases > PURCHASES_REMEMBERED do
			table.remove(purchases, 1)
		end
		data.purchases = purchases
		return data, { player.UserId }
	end)
	savesInProgress -= 1
	profile.saving = false
	if not success then
		profile.dirty = true -- try again next time
		warn(("[PlayerData] Couldn't save %s: %s"):format(player.Name, tostring(result)))
		return false
	end
	profile.unsavedBucks -= bucksToAdd
	-- Show the saved total (it includes any coins earned on another server)
	if savedBucks and profiles[player] == profile then
		profile.noobBucks = savedBucks + profile.unsavedBucks
		player:SetAttribute("NoobBucks", profile.noobBucks)
	end
	return true
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
