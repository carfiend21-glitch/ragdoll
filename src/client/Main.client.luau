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
-- to dark, ticking-clock suspense music, and in the last few seconds to a faster
-- "double time" version of it.
local music = Sounds.newMusic("LobbyMusic")
music:Play()
local roundTracks = {
	{ sound = Sounds.newMusic("RoundMusic"), volume = Sounds.LIST.RoundMusic.volume },
	{ sound = Sounds.newMusic("RoundMusicFinal"), volume = Sounds.LIST.RoundMusicFinal.volume },
}
local FINAL_STRETCH = 15 -- seconds left when the round music switches to double time
local FADE = TweenInfo.new(1.5)
local wantedTrack = nil -- the round track that should be playing (nil = lobby music)

-- Fades over to `track` (or back to the lobby music if nil). Tracks start from the
-- top each time, and stop once they've faded out.
local function playRoundTrack(track)
	if track == wantedTrack then
		return
	end
	wantedTrack = track
	TweenService:Create(music, FADE, { Volume = if track then 0 else Sounds.LIST.LobbyMusic.volume }):Play()
	for _, other in roundTracks do
		local sound = other.sound
		if other == track then
			sound.TimePosition = 0
			sound:Play()
			TweenService:Create(sound, FADE, { Volume = other.volume }):Play()
		else
			local fadeOut = TweenService:Create(sound, FADE, { Volume = 0 })
			fadeOut:Play()
			-- A fade that got cut short by a newer one also counts as "Completed",
			-- so only stop it if this fade really finished and it's still not wanted
			fadeOut.Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed and wantedTrack ~= other then
					sound:Stop()
				end
			end)
		end
	end
end

local function updateMusic()
	local inRound = Remotes.GameState:GetAttribute("Phase") == "Round"
		and ((player:GetAttribute("Room") or 0) > 0 or (player:GetAttribute("Spectating") or 0) > 0)
	if not inRound then
		playRoundTrack(nil)
	elseif wantedTrack == nil then
		-- Always start on the normal track: right as a round starts, the time left can
		-- still be the lobby countdown's last second for a moment
		playRoundTrack(roundTracks[1])
	elseif (Remotes.GameState:GetAttribute("TimeLeft") or 0) <= FINAL_STRETCH then
		playRoundTrack(roundTracks[2])
	end
end
-- The last few seconds of a round switch to the double time music
Remotes.GameState:GetAttributeChangedSignal("TimeLeft"):Connect(updateMusic)
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
