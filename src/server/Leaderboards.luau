-- Global leaderboards (all servers, all time): most wins, most points scored in one
-- round, and most "best sequence" votes won. Shown on three boards in the middle of the
-- lobby.
-- They're live: scores from players in this server show (and re-sort) the moment they
-- change, even mid-round, and are saved a few seconds later. Every 30 seconds each board
-- also re-reads the saved scores, to pick up players in other servers.
-- These use Roblox's "ordered" DataStores, so they only work in a published game
-- (or in Studio with "Enable Studio Access to API Services" turned on).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Leaderboards = {}

local REFRESH_SECONDS = 30 -- every board re-reads the saved scores this often
local SAVE_GAP = 8 -- seconds between saves of a score that keeps climbing (round points)
local NO_DATA_MESSAGE = "Publish the game (or turn on Studio API access) to see the leaderboard"

local winsStore, pointsStore, sequenceStore = nil, nil, nil
pcall(function()
	winsStore = DataStoreService:GetOrderedDataStore("GlobalWins_v1")
	-- Best score in one round (it used to be one run: GlobalBestRun_v2)
	pointsStore = DataStoreService:GetOrderedDataStore("GlobalBestRound_v1")
	sequenceStore = DataStoreService:GetOrderedDataStore("GlobalBestSequences_v1")
end)

-- One per board: { store, rows (TextLabels), unit, saved = { [userId] = value } from the
-- last read, live = { [userId] = value } for players in this server, readAt }
local boards = {}
local function newBoard(store, unit)
	local board = { store = store, unit = unit, rows = nil, saved = {}, live = {}, readAt = -math.huge, loaded = false }
	boards[store or unit] = board
	return board
end
local winsBoard = newBoard(winsStore, "wins")
local pointsBoard = newBoard(pointsStore, "pts")
local sequenceBoard = newBoard(sequenceStore, "votes won")

-- Scores waiting to be saved: [board][userId] = value
local unsaved = { [winsBoard] = {}, [pointsBoard] = {}, [sequenceBoard] = {} }

-- Player names, looked up once from their user ID
local names = {}
local function nameFor(userId)
	if not names[userId] then
		local player = Players:GetPlayerByUserId(userId)
		if player then
			names[userId] = player.Name
		else
			local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
			names[userId] = if ok then name else "Player"
		end
	end
	return names[userId]
end

-- Redraws a board: the saved top scores, with this server's newer scores mixed in,
-- highest first
local function draw(board)
	local rows = board.rows
	if not rows then
		return -- (the lobby isn't built yet)
	end
	if not board.loaded and next(board.live) == nil then
		for index, row in rows do
			row.Text = if index == 1 then NO_DATA_MESSAGE else ""
		end
		return
	end
	local best = {}
	for userId, value in board.saved do
		best[userId] = value
	end
	for userId, value in board.live do
		best[userId] = math.max(best[userId] or 0, value)
	end
	local list = {}
	for userId, value in best do
		table.insert(list, { userId = userId, value = value })
	end
	table.sort(list, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.userId < b.userId
	end)
	for index, row in rows do
		local entry = list[index]
		row.Text = if entry
			then ("%d. %s  -  %s %s"):format(index, nameFor(entry.userId), Config.formatScore(entry.value), board.unit)
			else ("%d. ---"):format(index)
	end
end

-- A player in this server has a new score: show it right away, save it soon
local function setLive(board, player, value)
	if value <= (board.live[player.UserId] or 0) then
		return
	end
	board.live[player.UserId] = value
	unsaved[board][player.UserId] = value
	task.spawn(draw, board) -- (looking up a name can take a moment: don't hold up the game)
end

-- Saves a player's total number of wins
function Leaderboards.recordWins(player, totalWins)
	setLive(winsBoard, player, totalWins)
end

-- Saves how many times a player's attacks were voted the best sequence
function Leaderboards.recordSequences(player, total)
	setLive(sequenceBoard, player, total)
end

-- Their score so far this round beat their best round: call as it climbs (it's cheap;
-- the board redraws straight away and saving waits a few seconds)
function Leaderboards.recordRound(player, score)
	setLive(pointsBoard, player, score)
end

-- A player joined: puts their saved scores on the boards, in case a board missed them
-- `stats` = { wins, bestRound, sequenceWins } from PlayerData.leaderboardStats
function Leaderboards.syncPlayer(player, stats)
	setLive(winsBoard, player, stats.wins)
	setLive(pointsBoard, player, stats.bestRound)
	setLive(sequenceBoard, player, stats.sequenceWins)
end

-- Saves every score waiting to be saved (only ever raises a saved score, never lowers it)
local function saveAll()
	for board, waiting in unsaved do
		if board.store then
			for userId, value in waiting do
				waiting[userId] = nil
				local ok, err = pcall(board.store.UpdateAsync, board.store, tostring(userId), function(old)
					if old and old >= value then
						return nil -- already up to date
					end
					return value
				end)
				if ok then
					board.saved[userId] = math.max(board.saved[userId] or 0, value)
				else
					waiting[userId] = math.max(waiting[userId] or 0, value) -- try again next time
					warn(("[Leaderboards] Couldn't save %s: %s"):format(board.unit, tostring(err)))
				end
			end
		end
	end
end

-- Reads a board's saved top scores
local function read(board)
	local ok, pages = pcall(board.store.GetSortedAsync, board.store, false, #board.rows)
	if not ok then
		return -- keep showing what it had
	end
	board.loaded = true
	board.saved = {}
	for _, entry in pages:GetCurrentPage() do
		board.saved[tonumber(entry.key)] = entry.value
	end
end

-- Roblox only allows so many leaderboard reads a minute; wait our turn instead of failing
local function canRead()
	local ok, budget = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService, Enum.DataStoreRequestType.GetSortedAsync)
	return not ok or budget > 0
end

-- Players who leave don't stay on the board as "live" (their saved score still counts)
Players.PlayerRemoving:Connect(function(player)
	for _, board in boards do
		local value = board.live[player.UserId]
		board.live[player.UserId] = nil
		if value then
			board.saved[player.UserId] = math.max(board.saved[player.UserId] or 0, value)
		end
	end
end)

-- `lobby` = { winsRows, runRows, sequenceRows } (each a list of TextLabels) from WorldBuilder
function Leaderboards.start(lobby)
	winsBoard.rows = lobby.winsRows
	pointsBoard.rows = lobby.runRows
	sequenceBoard.rows = lobby.sequenceRows
	for _, board in boards do
		draw(board)
	end
	-- Saving
	task.spawn(function()
		while true do
			task.wait(SAVE_GAP)
			saveAll()
		end
	end)
	-- Reading other servers' scores
	task.spawn(function()
		while true do
			for _, board in boards do
				if board.store and os.clock() - board.readAt >= REFRESH_SECONDS and canRead() then
					board.readAt = os.clock()
					read(board)
					draw(board)
				end
			end
			task.wait(1)
		end
	end)
end

-- Saves anything still waiting when the server shuts down
function Leaderboards.saveNow()
	saveAll()
end

return Leaderboards
