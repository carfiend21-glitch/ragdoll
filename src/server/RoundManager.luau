-- The game loop: lobby countdown -> 90-second round -> replays of the top 3 rooms ->
-- the lobby votes for the best sequence of attacks -> winner and the round
-- leaderboard -> repeat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NoobBucks = require(Shared.NoobBucks)
local Remotes = require(Shared.Remotes)

local Leaderboards = require(script.Parent.Leaderboards)
local PlayerData = require(script.Parent.PlayerData)
local SequenceVote = require(script.Parent.SequenceVote)

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
	Vote = function()
		return "🎬 VOTE: BEST SEQUENCE!"
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

-- Who's in which room, and their Noob Buck looks (so the replays look the same)
local function rosterInfo()
	local info = {}
	for _, entry in roster do
		table.insert(info, { room = entry.arena.index, name = entry.name, looks = entry.arena:lookIds() })
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

	for _, entry in roster do
		entry.arena:stopRound()
	end
	sendReplayPieces()
	-- Spectators come back to the lobby (everyone watches the replays together)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Spectating", 0)
	end

	-- Everyone watches the replays of the top 3 rooms, one at a time at 5x speed:
	-- 3rd place, then 2nd, then the winner last
	local ranked = table.clone(roster)
	table.sort(ranked, function(a, b)
		return a.arena.damage > b.arena.damage
	end)
	-- (sent best first; players' screens play them from 3rd place up)
	local shown, durations, longest = {}, {}, 0
	for index = 1, math.min(Config.REPLAYS_SHOWN, #ranked) do
		local duration = ranked[index].arena.recorder:duration()
		table.insert(shown, ranked[index].arena.index)
		table.insert(durations, duration)
		longest = math.max(longest, duration)
	end
	Remotes.ReplayPick:FireAllClients(shown)
	if longest > 1 then
		countdown("Replay", math.ceil(Config.replayWatchTime(durations)) + 2)
	end

	-- Straight after the winner's replay, everyone else votes for the best sequence of
	-- attacks out of the top 3 (see SequenceVote). The pick gets a Noob Buck.
	local sequenceWinner, sequenceBucks = nil, 0
	if longest > 1 then
		local top = {}
		for index = 1, #shown do
			local entry = ranked[index]
			table.insert(top, { player = entry.player, name = entry.name, damage = entry.arena.damage })
		end
		sequenceWinner, sequenceBucks = SequenceVote.run(top, countdown)
	end

	-- Most damage wins (a tie means everyone tied for first wins). There's only a winner
	-- when at least 2 players are in the round and someone beat someone, so nobody can
	-- farm wins and Noob Bucks alone in an empty server.
	local best, worst, playing = 0, math.huge, 0
	for _, entry in roster do
		if entry.player.Parent then
			best = math.max(best, entry.arena.damage)
			worst = math.min(worst, entry.arena.damage)
			playing += 1
		end
	end
	local hasWinner = playing >= 2 and best > worst
	local results = {}
	for _, entry in roster do
		-- A rented weapon lasts for one round of actually using it (see PlayerData.endRentals)
		if entry.player.Parent and PlayerData.endRentals(entry.player) then
			Remotes.DataSync:FireClient(entry.player, PlayerData.getSyncData(entry.player))
		end
		if entry.player.Parent then
			local damage = entry.arena.damage
			local winner = hasWinner and damage == best
			if playing < 2 then
				Remotes.Notify:FireClient(entry.player, "🏆 NO WIN THIS ROUND", "Wins count when 2+ players are in the round.")
			end
			local votedBest = entry.player.UserId == sequenceWinner
			-- (double with the 2x Noob Bucks pass or boost)
			local winBucks = if winner then NoobBucks.WIN_REWARD * PlayerData.bucksMultiplier(entry.player) else 0
			if winner then
				-- First place: +1 win (shown in the player list and the lobby leaderboard)
				Leaderboards.recordWins(entry.player, PlayerData.addWin(entry.player))
				-- ...and Noob Bucks
				PlayerData.addNoobBucks(entry.player, winBucks)
				Remotes.Notify:FireClient(
					entry.player,
					("💵 +%d NOOB BUCK%s"):format(winBucks, if winBucks == 1 then "" else "S"),
					"For winning the round!"
				)
			end
			table.insert(results, {
				name = entry.name,
				damage = damage,
				winner = winner,
				bucks = winBucks + (if votedBest then sequenceBucks else 0),
				bestSequence = votedBest,
				userId = entry.player.UserId,
			})
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
			-- Back to the starting cash, so the lobby shows what you'll start the next round with
			PlayerData.resetCash(entry.player)
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
