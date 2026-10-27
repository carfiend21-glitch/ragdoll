-- Global leaderboards (all servers, all time): most wins, most points scored in one
-- run, and most "best sequence" votes won. Shown on three boards in the middle of the
-- lobby. A board updates a few seconds after someone in this server changes it, and
-- every 30 seconds anyway (to pick up scores from other servers).
-- These use Roblox's "ordered" DataStores, so they only work in a published game
-- (or in Studio with "Enable Studio Access to API Services" turned on).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Leaderboards = {}

local REFRESH_SECONDS = 30 -- every board re-reads this often, changed or not
local CHANGED_GAP = 4 -- seconds between re-reads of a board that just changed
local NO_DATA_MESSAGE = "Publish the game (or turn on Studio API access) to see the leaderboard"

local winsStore, runStore, sequenceStore = nil, nil, nil
local changed = {} -- [store] = true when a score in it was saved since the board last read it
pcall(function()
	winsStore = DataStoreService:GetOrderedDataStore("GlobalWins_v1")
	-- v2: scores became 50x bigger (Config.SCORE_MULTIPLIER), so old v1 scores would look tiny
	runStore = DataStoreService:GetOrderedDataStore("GlobalBestRun_v2")
	sequenceStore = DataStoreService:GetOrderedDataStore("GlobalBestSequences_v1")
end)

-- Player names, looked up once from their user ID
local names = {}
local function nameFor(userId)
	if not names[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		names[userId] = if ok then name else "Player"
	end
	return names[userId]
end

-- Saves a player's total number of wins
function Leaderboards.recordWins(player, totalWins)
	if not winsStore then
		return
	end
	task.spawn(function()
		local ok, err = pcall(winsStore.SetAsync, winsStore, tostring(player.UserId), totalWins)
		if ok then
			changed[winsStore] = true
		else
			warn("[Leaderboards] Couldn't save wins: " .. tostring(err))
		end
	end)
end

-- Saves how many times a player's attacks were voted the best sequence
function Leaderboards.recordSequences(player, total)
	if not sequenceStore then
		return
	end
	task.spawn(function()
		local ok, err = pcall(sequenceStore.SetAsync, sequenceStore, tostring(player.UserId), total)
		if ok then
			changed[sequenceStore] = true
		else
			warn("[Leaderboards] Couldn't save best sequences: " .. tostring(err))
		end
	end)
end

-- Saves a player's best run, if `damage` beats what's already saved
function Leaderboards.recordRun(player, damage)
	if not runStore then
		return
	end
	task.spawn(function()
		local ok, err = pcall(runStore.UpdateAsync, runStore, tostring(player.UserId), function(old)
			if old and old >= damage then
				return nil -- keep the old, higher score
			end
			return damage
		end)
		if ok then
			changed[runStore] = true
		else
			warn("[Leaderboards] Couldn't save best run: " .. tostring(err))
		end
	end)
end

-- Raises a player's score on a board to `value` (never lowers it)
local function raise(store, player, value, what)
	if not store or value <= 0 then
		return
	end
	local ok, err = pcall(store.UpdateAsync, store, tostring(player.UserId), function(old)
		if old and old >= value then
			return nil -- already up to date
		end
		return value
	end)
	if ok then
		changed[store] = true
	else
		warn(("[Leaderboards] Couldn't sync %s: %s"):format(what, tostring(err)))
	end
end

-- A player joined: puts their saved scores on the boards, in case a board missed them
-- `stats` = { wins, bestRun, sequenceWins } from PlayerData.leaderboardStats
function Leaderboards.syncPlayer(player, stats)
	task.spawn(function()
		raise(winsStore, player, stats.wins, "wins")
		raise(runStore, player, stats.bestRun, "best run")
		raise(sequenceStore, player, stats.sequenceWins, "best sequences")
	end)
end

-- Fills a board's rows (TextLabels) with the top players from its store
local function fill(board)
	local store, rows = board.store, board.rows
	local ok, pages = false, nil
	if store then
		ok, pages = pcall(store.GetSortedAsync, store, false, #rows)
	end
	if not ok then
		-- Keep showing the last scores if it just couldn't read this time
		if not board.loaded then
			for index, row in rows do
				row.Text = if index == 1 then NO_DATA_MESSAGE else ""
			end
		end
		return
	end
	board.loaded = true
	local entries = pages:GetCurrentPage()
	for index, row in rows do
		local entry = entries[index]
		row.Text = if entry
			then ("%d. %s  -  %s %s"):format(index, nameFor(tonumber(entry.key)), Config.formatScore(entry.value), board.unit)
			else ("%d. ---"):format(index)
	end
end

-- Roblox only allows so many leaderboard reads a minute; wait our turn instead of failing
local function canRead()
	local ok, budget = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService, Enum.DataStoreRequestType.GetSortedAsync)
	return not ok or budget > 0
end

-- `boards` = { winsRows, runRows, sequenceRows } (each a list of TextLabels) from WorldBuilder
function Leaderboards.start(boards)
	local list = {
		{ store = winsStore, rows = boards.winsRows, unit = "wins", readAt = -math.huge },
		{ store = runStore, rows = boards.runRows, unit = "pts", readAt = -math.huge },
		{ store = sequenceStore, rows = boards.sequenceRows, unit = "votes won", readAt = -math.huge },
	}
	task.spawn(function()
		while true do
			for _, board in list do
				local since = os.clock() - board.readAt
				local due = since >= REFRESH_SECONDS or (board.store and changed[board.store] and since >= CHANGED_GAP)
				-- (no store at all = no API access: show the message straight away)
				if due and (not board.store or canRead()) then
					if board.store then
						changed[board.store] = nil
					end
					board.readAt = os.clock()
					fill(board)
				end
			end
			task.wait(1)
		end
	end)
end

return Leaderboards
