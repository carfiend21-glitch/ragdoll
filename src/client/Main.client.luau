-- Starting point on each player's device: camera, on-screen menus, placing
-- weapons, blood effects, replays, spectating, music and sounds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
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
-- to dark music that builds toward the end of the round, and for the last few
-- seconds fast clock ticks join in on top.
local FINAL_STRETCH = 15 -- seconds left when the clock ticks join in
local FADE = TweenInfo.new(1.5)

local function newLayer(name)
	return { sound = Sounds.newMusic(name), volume = Sounds.LIST[name].volume, on = false }
end
local lobbyLayer = newLayer("LobbyMusic")
local roundLayer = newLayer("RoundMusic")
local ticksLayer = newLayer("FinalTicks")

-- Fades a layer in (playing from `startAt` seconds) or out (then stops it)
local function setLayer(layer, on, startAt)
	if layer.on == on then
		return
	end
	layer.on = on
	local sound = layer.sound
	if on then
		sound.TimePosition = startAt or 0
		sound:Play()
	end
	local fade = TweenService:Create(sound, FADE, { Volume = if on then layer.volume else 0 })
	fade:Play()
	if not on then
		-- A fade that got cut short by a newer one also counts as "Completed",
		-- so only stop it if this fade really finished and it's still not wanted
		fade.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed and not layer.on then
				sound:Stop()
			end
		end)
	end
end

local function updateMusic()
	local inRound = Remotes.GameState:GetAttribute("Phase") == "Round"
		and ((player:GetAttribute("Room") or 0) > 0 or (player:GetAttribute("Spectating") or 0) > 0)
	local timeLeft = Remotes.GameState:GetAttribute("TimeLeft") or 0
	setLayer(lobbyLayer, not inRound)
	if inRound and not roundLayer.on then
		-- Right as a round starts, the time left can still be the lobby countdown's
		-- last second for a moment, so treat that as a full round
		local left = if timeLeft > 1 then timeLeft else Config.ROUND_TIME
		-- Start partway in, so the music's big finish lands as the round ends
		local length = roundLayer.sound.TimeLength
		setLayer(roundLayer, true, math.max(0, length - left))
	elseif not inRound then
		setLayer(roundLayer, false)
	end
	setLayer(ticksLayer, inRound and roundLayer.on and timeLeft > 0 and timeLeft <= FINAL_STRETCH)
end
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
