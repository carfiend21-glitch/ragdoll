-- Global leaderboards (all servers, all time): most wins, most points scored in one
-- run, and most "best sequence" votes won. Shown on three boards in the middle of the
-- lobby, refreshed every minute.
-- These use Roblox's "ordered" DataStores, so they only work in a published game
-- (or in Studio with "Enable Studio Access to API Services" turned on).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Leaderboards = {}

local REFRESH_SECONDS = 60
local NO_DATA_MESSAGE = "Publish the game (or turn on Studio API access) to see the leaderboard"

local winsStore, runStore, sequenceStore = nil, nil, nil
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
		if not ok then
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
		if not ok then
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
		if not ok then
			warn("[Leaderboards] Couldn't save best run: " .. tostring(err))
		end
	end)
end

-- Fills one board's rows (TextLabels) with the top players from `store`
local function fill(store, rows, unit)
	local ok, pages = false, nil
	if store then
		ok, pages = pcall(store.GetSortedAsync, store, false, #rows)
	end
	if not ok then
		for index, row in rows do
			row.Text = if index == 1 then NO_DATA_MESSAGE else ""
		end
		return
	end
	local entries = pages:GetCurrentPage()
	for index, row in rows do
		local entry = entries[index]
		row.Text = if entry
			then ("%d. %s  -  %s %s"):format(index, nameFor(tonumber(entry.key)), Config.formatScore(entry.value), unit)
			else ("%d. ---"):format(index)
	end
end

-- `boards` = { winsRows, runRows, sequenceRows } (each a list of TextLabels) from WorldBuilder
function Leaderboards.start(boards)
	task.spawn(function()
		while true do
			fill(winsStore, boards.winsRows, "wins")
			fill(runStore, boards.runRows, "pts")
			fill(sequenceStore, boards.sequenceRows, "votes won")
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return Leaderboards
