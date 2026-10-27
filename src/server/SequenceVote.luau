-- The "best sequence" vote, right after the winner's replay: everyone who WASN'T in the
-- top 3 votes for whichever of the top 3 had the best sequence of attacks. The pick
-- gets a Noob Buck, and it counts toward the BEST SEQUENCES board in the lobby.
--
-- How a vote is decided:
--   * Most votes wins.
--   * A tie for the most (like 2-2-1): whoever got fewer votes is out, and only the
--     players who voted for them vote again, between the tied players. With 5 voters
--     that always ends 3-2.
--   * Anyone who doesn't vote in time gets a random vote cast for them.
--   * If it's still tied (only possible with an even number of voters), a coin flip decides.
--   * If nobody is left in the lobby to vote (3 or fewer players), the top 3 vote, but
--     never for themselves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NoobBucks = require(Shared.NoobBucks)
local Remotes = require(Shared.Remotes)

local Leaderboards = require(script.Parent.Leaderboards)
local PlayerData = require(script.Parent.PlayerData)

local VOTE_TIME = 15 -- seconds to vote
local RUNOFF_TIME = 10 -- seconds to vote again after a tie
local REVEAL_TIME = 5 -- seconds the winner is shown

local SequenceVote = {}

-- The vote going on right now: { voters = { [player] = true }, options = { [userId] = true },
-- votes = { [player] = userId } }, or nil
local current = nil

-- One vote per player per stage
Remotes.CastVote.OnServerEvent:Connect(function(player, choice)
	if not current or not current.voters[player] or current.votes[player] then
		return
	end
	if typeof(choice) ~= "number" or not current.options[choice] or choice == player.UserId then
		return
	end
	current.votes[player] = choice
	local voted = 0
	for _ in current.votes do
		voted += 1
	end
	Remotes.VoteUpdate:FireAllClients("progress", { voted = voted, total = current.total })
end)

-- Asks `voters` to pick one of `options` (user IDs). Returns { [player] = userId }.
-- `info` describes the vote for players' screens.
local function ask(voters, options, info, seconds, countdown)
	current = { voters = {}, options = {}, votes = {}, total = #voters }
	for _, voter in voters do
		current.voters[voter] = true
	end
	for _, userId in options do
		current.options[userId] = true
	end
	local voterIds = {}
	for _, voter in voters do
		table.insert(voterIds, voter.UserId)
	end
	info.voters = voterIds
	info.options = options
	Remotes.VoteUpdate:FireAllClients("start", info)

	countdown("Vote", seconds, function()
		for _, voter in voters do
			if voter.Parent and not current.votes[voter] then
				return false
			end
		end
		return true -- everyone's voted: no need to wait
	end)

	-- Didn't vote in time: a random vote (never for themselves)
	local votes = current.votes
	current = nil
	for _, voter in voters do
		if voter.Parent and not votes[voter] then
			local choices = {}
			for _, userId in options do
				if userId ~= voter.UserId then
					table.insert(choices, userId)
				end
			end
			votes[voter] = choices[math.random(#choices)]
			Remotes.VoteUpdate:FireClient(voter, "random", votes[voter])
		end
	end
	return votes
end

-- How many votes each option got: a list of { userId, votes }, and the user IDs with the most
local function tally(votes, options)
	local counts = {}
	for _, userId in options do
		counts[userId] = 0
	end
	for voter, userId in votes do
		if voter.Parent and counts[userId] then
			counts[userId] += 1
		end
	end
	local best = 0
	for _, count in counts do
		best = math.max(best, count)
	end
	local list, leaders = {}, {}
	for _, userId in options do
		table.insert(list, { userId, counts[userId] })
		if counts[userId] == best then
			table.insert(leaders, userId)
		end
	end
	return list, leaders
end

-- `entries` = the top 3 (best first): { player, name, damage }. `countdown` is the round
-- manager's countdown(phase, seconds, shouldStop). Returns the winner's user ID, or nil
-- if there was nobody to vote on.
function SequenceVote.run(entries, countdown)
	local candidates, options, info = {}, {}, {}
	for place, entry in entries do
		if entry.player.Parent then
			candidates[entry.player] = true
			table.insert(options, entry.player.UserId)
			table.insert(info, { userId = entry.player.UserId, name = entry.name, place = place, damage = entry.damage })
		end
	end
	if #options < 2 then
		return nil -- nothing to vote on
	end

	-- Everyone else in the server votes. If there's nobody else, the top 3 vote for each other.
	local voters = {}
	for _, player in Players:GetPlayers() do
		if not candidates[player] then
			table.insert(voters, player)
		end
	end
	if #voters == 0 then
		for player in candidates do
			table.insert(voters, player)
		end
	end

	local votes = ask(voters, options, { candidates = info, seconds = VOTE_TIME }, VOTE_TIME, countdown)
	local counts, leaders = tally(votes, options)

	if #leaders > 1 and #leaders < #options then
		-- A tie: whoever got fewer votes is out, and the players who voted for them pick
		-- again between the tied players. Everyone else's vote still counts.
		local isLeader, out = {}, {}
		for _, userId in leaders do
			isLeader[userId] = true
		end
		for _, userId in options do
			if not isLeader[userId] then
				table.insert(out, userId)
			end
		end
		local revoters, kept = {}, {}
		for voter, userId in votes do
			if voter.Parent then
				if isLeader[userId] then
					kept[voter] = userId
				else
					table.insert(revoters, voter)
				end
			end
		end
		if #revoters > 0 then
			local runoff = { candidates = info, seconds = RUNOFF_TIME, runoff = true, counts = counts, out = out }
			votes = ask(revoters, leaders, runoff, RUNOFF_TIME, countdown)
			for voter, userId in kept do
				votes[voter] = userId
			end
			counts, leaders = tally(votes, leaders)
		end
	end

	-- Still tied (only possible with an even number of voters): flip a coin
	local coinFlip = #leaders > 1
	local winnerId = leaders[math.random(#leaders)]
	local winner = Players:GetPlayerByUserId(winnerId)
	if winner then
		PlayerData.addNoobBucks(winner, NoobBucks.VOTE_REWARD)
		Leaderboards.recordSequences(winner, PlayerData.addSequenceWin(winner))
		Remotes.Notify:FireClient(
			winner,
			("🎬 +%d NOOB BUCK%s"):format(NoobBucks.VOTE_REWARD, if NoobBucks.VOTE_REWARD == 1 then "" else "S"),
			"The lobby voted your attacks the BEST SEQUENCE!"
		)
	end
	Remotes.VoteUpdate:FireAllClients("result", { candidates = info, counts = counts, winner = winnerId, coinFlip = coinFlip })
	countdown("Vote", REVEAL_TIME)
	return winnerId
end

return SequenceVote
