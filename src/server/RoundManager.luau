-- The game loop: lobby countdown -> 90-second round -> results -> repeat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local RoundManager = {}

local function setPhase(phase, timeLeft)
	Remotes.GameState:SetAttribute("Phase", phase)
	Remotes.GameState:SetAttribute("TimeLeft", timeLeft)
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

local function playRound(arenas)
	-- Give each player a room (extra players sit this round out)
	local roster = {}
	for index, player in Players:GetPlayers() do
		if index > #arenas then
			break
		end
		arenas[index]:startRound(player)
		player:SetAttribute("Damage", 0)
		player:SetAttribute("Room", index)
		table.insert(roster, { player = player, arena = arenas[index] })
	end

	countdown("Round", Config.ROUND_TIME, function()
		for _, entry in roster do
			if entry.player.Parent then
				return false
			end
		end
		return true -- everyone left
	end)

	local results = {}
	for _, entry in roster do
		entry.arena:stopRound()
		if entry.player.Parent then
			table.insert(results, { name = entry.player.DisplayName, damage = entry.arena.damage })
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
