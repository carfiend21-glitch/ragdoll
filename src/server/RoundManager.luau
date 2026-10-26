-- The game loop: lobby countdown -> 90-second round -> 3x speed replays of
-- every room -> winner and results -> repeat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Leaderboards = require(script.Parent.Leaderboards)
local PlayerData = require(script.Parent.PlayerData)

local REPLAY_SEND_INTERVAL = 2 -- seconds between sending recorded replay pieces to players

local RoundManager = {}

-- Who's playing in which room this round: { { player, arena, name } }
local roster = {}
local lobbyScreen = nil -- the big screen in the lobby (a TextLabel)

local SCREEN_TEXT = {
	Waiting = function()
		return "WAITING FOR PLAYERS"
	end,
	Intermission = function(timeLeft)
		return ("NEXT ROUND IN %d"):format(timeLeft)
	end,
	Round = function(timeLeft)
		return ("ROUND IN PROGRESS  %d:%02d\n👁 Press SPECTATE to watch!"):format(timeLeft // 60, timeLeft % 60)
	end,
	Replay = function()
		return "▶▶ WATCHING REPLAYS"
	end,
	Results = function()
		return "🏆 ROUND OVER!"
	end,
}

function RoundManager.setLobbyScreen(label)
	lobbyScreen = label
end

local function setPhase(phase, timeLeft)
	Remotes.GameState:SetAttribute("Phase", phase)
	Remotes.GameState:SetAttribute("TimeLeft", timeLeft)
	if lobbyScreen then
		lobbyScreen.Text = SCREEN_TEXT[phase](timeLeft)
	end
end

-- Counts down once a second. Stops early if `shouldStop()` returns true.
local function countdown(phase, seconds, shouldStop)
	for timeLeft = seconds, 1, -1 do
		setPhase(phase, timeLeft)
		task.wait(1)
		if shouldStop and shouldStop() then
			return
		end
	end
end

local function rosterInfo()
	local info = {}
	for _, entry in roster do
		table.insert(info, { room = entry.arena.index, name = entry.name })
	end
	return info
end

-- Sends everyone the newest bits of each room's recording
local function sendReplayPieces()
	for _, entry in roster do
		local frames, events = entry.arena.recorder:takeNew()
		if #frames > 0 or #events > 0 then
			Remotes.ReplayChunk:FireAllClients(entry.arena.index, frames, events)
		end
	end
end

-- Someone joined in the middle of a round: give them the replay so far
function RoundManager.catchUp(player)
	if #roster == 0 then
		return
	end
	Remotes.ReplayReset:FireClient(player, rosterInfo())
	for _, entry in roster do
		local recorder = entry.arena.recorder
		local frames = table.move(recorder.frames, 1, recorder.framesSent, 1, {})
		local events = table.move(recorder.events, 1, recorder.eventsSent, 1, {})
		Remotes.ReplayChunk:FireClient(player, entry.arena.index, frames, events)
	end
end

local function playRound(arenas)
	-- Give each player a room (extra players sit this round out)
	roster = {}
	for index, player in Players:GetPlayers() do
		if index > #arenas then
			break
		end
		arenas[index]:startRound(player)
		player:SetAttribute("Damage", 0)
		player:SetAttribute("Room", index)
		table.insert(roster, { player = player, arena = arenas[index], name = player.DisplayName })
	end
	Remotes.ReplayReset:FireAllClients(rosterInfo())

	local sinceSent = 0
	countdown("Round", Config.ROUND_TIME, function()
		sinceSent += 1
		if sinceSent >= REPLAY_SEND_INTERVAL then
			sinceSent = 0
			sendReplayPieces()
		end
		for _, entry in roster do
			if entry.player.Parent then
				return false
			end
		end
		return true -- everyone left
	end)

	local longest = 0
	for _, entry in roster do
		entry.arena:stopRound()
		longest = math.max(longest, entry.arena.recorder:duration())
	end
	sendReplayPieces()
	-- Spectators come back to the lobby (everyone watches the replays together)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Spectating", 0)
	end

	-- Everyone watches all the rooms' replays at 3x speed
	if longest > 1 then
		countdown("Replay", math.ceil(longest / Config.REPLAY_SPEED) + 2)
	end

	-- Most damage wins (a tie means everyone tied for first wins)
	local best = 0
	for _, entry in roster do
		if entry.player.Parent then
			best = math.max(best, entry.arena.damage)
		end
	end
	local results = {}
	for _, entry in roster do
		if entry.player.Parent then
			local damage = entry.arena.damage
			local winner = best > 0 and damage == best
			if winner then
				-- First place: +1 win (shown in the player list and the lobby leaderboard)
				Leaderboards.recordWins(entry.player, PlayerData.addWin(entry.player))
			end
			table.insert(results, { name = entry.name, damage = damage, winner = winner })
		end
	end
	table.sort(results, function(a, b)
		return a.damage > b.damage
	end)

	-- Switch phase before sending results, so players' screens don't hide the board straight away
	setPhase("Results", Config.RESULTS_TIME)
	Remotes.Results:FireAllClients(results)
	countdown("Results", Config.RESULTS_TIME)

	for _, entry in roster do
		if entry.player.Parent then
			entry.player:SetAttribute("Room", 0)
		end
		entry.arena:clear()
	end
	roster = {}
end

function RoundManager.run(arenas)
	while true do
		setPhase("Waiting", 0)
		while #Players:GetPlayers() == 0 do
			task.wait(1)
		end
		countdown("Intermission", Config.INTERMISSION_TIME)
		if #Players:GetPlayers() > 0 then
			playRound(arenas)
		end
	end
end

return RoundManager
