-- Decides when achievements are earned and tells the player.
-- To add an achievement: add it to shared/Achievements.luau, then award it here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)

local PlayerData = require(script.Parent.PlayerData)

local WALL_SLAM_SPEED = 40
local PINBALL_SPEED = 8 -- slower than this doesn't count as bouncing off a wall
local TO_THE_MOON_SPEED = 50
local HANG_TIME = 4 -- seconds in the air without touching the floor
local COMBO_KING = 15
local HAT_TRICK = 3 -- noobs destroyed in one round
local EXTRA_CRISPY = 4 -- body parts burning at once
local FALLING_TO_PIECES = 8 -- limbs torn off in one round
local BIG_RUN = 25000 -- points (the shown score) in one run

-- Achievements for hitting the noob with a certain weapon
local WEAPON_ACHIEVEMENTS = {
	Mine = "WatchYourStep",
	Crossbow = "Bullseye",
	Grenade = "Kaboom",
	BearTrap = "Gotcha",
	Harpoon = "GetOverHere",
	Cannon = "HumanCannonball",
	WreckingBall = "Wrecked",
	StormCloud = "Thunderstruck",
	BanHammer = "Banned",
}
-- Achievements for hitting the noob with a weapon this many times in one run: { hits, id }
local RUN_HIT_ACHIEVEMENTS = {
	Spikes = { 5, "Pincushion" },
	Shotgun = { 12, "CloseRange" },
	ClusterBomb = { 4, "ClusterFun" },
	AcidBlaster = { 3, "MeltDown" },
	Minigun = { 30, "BulletStorm" },
	MissileSwarm = { 6, "HeatSeeker" },
}
-- Achievements for hitting this many body parts with one shot: { parts, id }
local MULTI_HIT_ACHIEVEMENTS = {
	TeslaCoil = { 3, "Shocking" },
	Railgun = { 3, "PiercingShot" },
}
-- Achievements for destroying the noob with a certain weapon
local FINISHER_ACHIEVEMENTS = {
	RocketLauncher = "AirDefense",
	BlackHole = "EventHorizon",
	MiniNuke = "GroundZero",
}
-- How recently (seconds) the fan or the gravity flipper must have acted for a ceiling
-- crash to count as theirs
local CEILING_CREDIT = 0.6
local ARMORY_WEAPONS = 15

local AchievementService = {}

function AchievementService.award(player, id)
	if not PlayerData.unlockAchievement(player, id) then
		return -- already had it
	end
	local reward = Achievements.rewardFor(Achievements.byId[id])
	PlayerData.addCash(player, reward)
	local bucks = Achievements.byId[id].bucks
	if bucks then
		PlayerData.addNoobBucks(player, bucks)
	end
	local newWeapons = {}
	for _, weapon in Weapons.list do
		if weapon.unlockedBy == id then
			table.insert(newWeapons, weapon.id)
		end
	end
	Remotes.AchievementUnlocked:FireClient(player, id, newWeapons, reward)
	Remotes.DataSync:FireClient(player, PlayerData.getSyncData(player))

	if PlayerData.achievementCount(player) >= 10 then
		AchievementService.award(player, "Collector")
	end
	-- New weapons might have come with it
	if #newWeapons > 0 then
		AchievementService.checkUnlocks(player)
	end
end

-- The weapon-collecting achievements: call whenever someone might have unlocked a weapon
-- (an achievement, a shop purchase, a Game Pass, or joining the game)
function AchievementService.checkUnlocks(player)
	local count, hasExclusive = PlayerData.unlockedWeaponStats(player)
	if hasExclusive then
		AchievementService.award(player, "ExclusiveClub")
	end
	if count >= ARMORY_WEAPONS then
		AchievementService.award(player, "Armory")
	end
	if count >= #Weapons.list then
		AchievementService.award(player, "FullArsenal")
	end
end

-- The noob took damage. `source` is a weapon id, or "Impact" for a crash. `parts` = how
-- many body parts that one hit reached.
function AchievementService.onHit(player, arena, source, parts)
	AchievementService.award(player, "FirstContact")
	if WEAPON_ACHIEVEMENTS[source] then
		AchievementService.award(player, WEAPON_ACHIEVEMENTS[source])
	end
	-- Hits with each weapon this run
	local runHits = arena.runStats.hits or {}
	arena.runStats.hits = runHits
	runHits[source] = (runHits[source] or 0) + 1
	local runGoal = RUN_HIT_ACHIEVEMENTS[source]
	if runGoal and runHits[source] >= runGoal[1] then
		AchievementService.award(player, runGoal[2])
	end
	local multiGoal = MULTI_HIT_ACHIEVEMENTS[source]
	if multiGoal and (parts or 0) >= multiGoal[1] then
		AchievementService.award(player, multiGoal[2])
	end
	if source == "Crossbow" then
		arena.roundStats.arrowHits += 1
		if arena.roundStats.arrowHits >= 10 then
			AchievementService.award(player, "Sharpshooter")
		end
	elseif source == "Mine" then
		arena.roundStats.mineHits += 1
		if arena.roundStats.mineHits >= 5 then
			AchievementService.award(player, "Bombing")
		end
	end
	if arena.inRun and arena.runDamage >= BIG_RUN then
		AchievementService.award(player, "BigRun")
	end
	if arena.combo >= COMBO_KING then
		AchievementService.award(player, "ComboKing")
	end
	if arena:countRecentTraps() >= 2 then
		AchievementService.award(player, "ChainReaction")
	end
	if arena.realDamage >= 1000 then -- shown as 50,000 (see Config.SCORE_MULTIPLIER)
		AchievementService.award(player, "PointCollector")
	end
end

-- One body part was hit. `outcome` is "Torn" if it got torn off.
function AchievementService.onPartHit(player, arena, source, partKey, outcome)
	if partKey == "Head" then
		if source == "BoxingGlove" then
			AchievementService.award(player, "Knockout")
		elseif source == "FreezeRay" then
			AchievementService.award(player, "BrainFreeze")
		end
	end
	if source == "Crossbow" then
		if partKey == "Head" then
			AchievementService.award(player, "Headshot")
		elseif partKey == "LeftLeg" or partKey == "RightLeg" then
			AchievementService.award(player, "ArrowInTheKnee")
		end
	end
	if outcome == "Torn" then
		arena.roundStats.limbsTorn += 1
		if arena.roundStats.limbsTorn >= FALLING_TO_PIECES then
			AchievementService.award(player, "FallingToPieces")
		end
		if source == "Mine" then
			AchievementService.award(player, "RedWire")
		end
		if arena.noob:limbsLeft() == 0 then
			AchievementService.award(player, "LordOfTheSeas")
		end
	end
end

-- The noob was destroyed. `partKey` is the body part that finished it off.
function AchievementService.onDestroyed(player, arena, source, partKey)
	AchievementService.award(player, "Destroyed")
	arena.roundStats.destroys += 1
	if arena.roundStats.destroys >= HAT_TRICK then
		AchievementService.award(player, "HatTrick")
	end
	if partKey == "Head" then
		AchievementService.award(player, "WithoutTheHead")
	end
	if FINISHER_ACHIEVEMENTS[source] then
		AchievementService.award(player, FINISHER_ACHIEVEMENTS[source])
	end
end

-- The noob touched part of the room. `speed` is how fast it was going.
function AchievementService.onSurface(player, arena, surface, speed)
	if surface == "Ceiling" then
		AchievementService.award(player, "FrequentFlyer")
		if speed >= TO_THE_MOON_SPEED then
			AchievementService.award(player, "ToTheMoon")
		end
		local now = os.clock()
		if now - (arena.fanPushedAt or 0) <= CEILING_CREDIT then
			AchievementService.award(player, "GoneWithTheWind")
		end
		if now <= (arena.flippedUntil or 0) + CEILING_CREDIT then
			AchievementService.award(player, "UpsideDown")
		end
	elseif surface == "Wall" then
		if speed >= WALL_SLAM_SPEED then
			AchievementService.award(player, "WallSlam")
		end
		if speed >= PINBALL_SPEED and arena.inRun then
			arena.runStats.wallHits += 1
			if arena.runStats.wallHits >= 5 then
				AchievementService.award(player, "Pinball")
			end
		end
	end
end

-- The noob has been in the air for `seconds` without touching the floor (during a run)
function AchievementService.onAirborne(player, _arena, seconds)
	if seconds >= HANG_TIME then
		AchievementService.award(player, "HangTime")
	end
end

-- `count` body parts are on fire right now
function AchievementService.onBurning(player, _arena, count)
	if count >= EXTRA_CRISPY then
		AchievementService.award(player, "ExtraCrispy")
	end
end

-- A body part caught fire
function AchievementService.onIgnite(player, _arena)
	AchievementService.award(player, "Toasty")
end

return AchievementService
