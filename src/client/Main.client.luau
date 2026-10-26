-- Starting point on each player's device: camera, on-screen menus, placing
-- weapons, blood effects, replays, spectating, music and sounds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Sounds)

local Blood = require(script.Parent.Blood)
local CameraController = require(script.Parent.CameraController)
local Hud = require(script.Parent.Hud)
local Placement = require(script.Parent.Placement)
local Replay = require(script.Parent.Replay)
local Spectate = require(script.Parent.Spectate)

local player = Players.LocalPlayer

local hud = Hud.new()
local placement = Placement.new(hud)
hud.onWeaponClicked = function(weaponId)
	placement:toggle(weaponId)
end
CameraController.start()
Spectate.start()

Remotes.DataSync.OnClientEvent:Connect(function(data)
	hud:setData(data)
end)
Remotes.AchievementUnlocked.OnClientEvent:Connect(function(id, weaponIds, reward)
	hud:showAchievement(id, weaponIds, reward)
end)
Remotes.Notify.OnClientEvent:Connect(function(title, subtitle)
	hud:showToast(title, subtitle)
end)
Remotes.Hint.OnClientEvent:Connect(function(message)
	hud:flashHint(message)
end)
Remotes.HitFx.OnClientEvent:Connect(function(reports, combo)
	hud:showHit(reports, combo)
	-- Your own room, or the room you're spectating
	local room = player:GetAttribute("Room") or 0
	if room == 0 then
		room = player:GetAttribute("Spectating") or 0
	end
	if room > 0 then
		for _, report in reports do
			-- Tearing a limb off makes a bigger mess. Goes by the real damage, not the score.
			Blood.spray(room, report.position, if report.outcome then report.damage + 40 else report.damage)
		end
	end
end)
Remotes.Results.OnClientEvent:Connect(function(results)
	hud:showResults(results)
end)

-- Replays: the server sends recordings during the round; we play them all after it
Remotes.ReplayReset.OnClientEvent:Connect(Replay.reset)
Remotes.ReplayChunk.OnClientEvent:Connect(Replay.addPiece)

-- Chill music in the lobby. While you're playing or watching a round it fades over
-- to the round music, which lets you feel the clock ticking.
local music = Sounds.newMusic("LobbyMusic")
music:Play()
local roundMusic = Sounds.newMusic("RoundMusic")
local FINAL_STRETCH = 15 -- seconds left when the round music speeds up a little
local inRound = false
local function updateMusic()
	local phase = Remotes.GameState:GetAttribute("Phase")
	inRound = phase == "Round"
		and ((player:GetAttribute("Room") or 0) > 0 or (player:GetAttribute("Spectating") or 0) > 0)
	if inRound and not roundMusic.IsPlaying then
		-- From the top every round, so the music builds along with the timer
		roundMusic.TimePosition = 0
		roundMusic.PlaybackSpeed = 1
		roundMusic:Play()
	end
	local fade = TweenInfo.new(1.5)
	TweenService:Create(music, fade, { Volume = if inRound then 0 else Sounds.LIST.LobbyMusic.volume }):Play()
	local roundFade = TweenService:Create(roundMusic, fade, { Volume = if inRound then Sounds.LIST.RoundMusic.volume else 0 })
	roundFade:Play()
	if not inRound then
		-- Stop it once it has faded out, so it starts from the top next round. A fade
		-- that got cut short by a newer one also counts as "Completed", so check that
		-- this fade really finished and we're still out of the round.
		roundFade.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed and not inRound then
				roundMusic:Stop()
			end
		end)
	end
end
-- The last few seconds of a round: the music picks up the pace a little
Remotes.GameState:GetAttributeChangedSignal("TimeLeft"):Connect(function()
	local timeLeft = Remotes.GameState:GetAttribute("TimeLeft") or 0
	if Remotes.GameState:GetAttribute("Phase") == "Round" and timeLeft <= FINAL_STRETCH and roundMusic.IsPlaying then
		TweenService:Create(roundMusic, TweenInfo.new(1), { PlaybackSpeed = 1.12 }):Play()
	end
end)
player:GetAttributeChangedSignal("Room"):Connect(updateMusic)
player:GetAttributeChangedSignal("Spectating"):Connect(updateMusic)

local function onPhaseChanged()
	local phase = Remotes.GameState:GetAttribute("Phase")
	if phase == "Replay" then
		Replay.play()
		Sounds.playUI("RoundEnd")
	else
		Replay.stop()
	end
	if phase == "Round" and (player:GetAttribute("Room") or 0) > 0 then
		Sounds.playUI("RoundStart")
	elseif phase == "Results" then
		Sounds.playUI("Winner")
	elseif phase == "Intermission" then
		Blood.clear() -- mop the room between rounds
	end
	updateMusic()
end
Remotes.GameState:GetAttributeChangedSignal("Phase"):Connect(onPhaseChanged)

-- Gentle beeps for the last 3 seconds before a round starts or ends
Remotes.GameState:GetAttributeChangedSignal("TimeLeft"):Connect(function()
	local phase = Remotes.GameState:GetAttribute("Phase")
	local timeLeft = Remotes.GameState:GetAttribute("TimeLeft") or 0
	if timeLeft >= 1 and timeLeft <= 3 and (phase == "Intermission" or phase == "Round") then
		Sounds.playUI("Beep")
	end
end)

-- "Ka-ching" when you get a nice amount of cash (achievements, selling, round rewards)
local lastCash = player:GetAttribute("Cash")
player:GetAttributeChangedSignal("Cash"):Connect(function()
	local cash = player:GetAttribute("Cash") or 0
	if lastCash and cash - lastCash >= 20 then
		Sounds.playUI("Cash")
	end
	lastCash = cash
end)

hud:setData(Remotes.GetData:InvokeServer())
onPhaseChanged()
