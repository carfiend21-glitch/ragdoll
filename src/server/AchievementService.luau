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

-- Achievements for hitting the noob with a certain weapon
local WEAPON_ACHIEVEMENTS = {
	Mine = "WatchYourStep",
	Crossbow = "Bullseye",
	Grenade = "Kaboom",
}

local AchievementService = {}

function AchievementService.award(player, id)
	if not PlayerData.unlockAchievement(player, id) then
		return -- already had it
	end
	local reward = Achievements.rewardFor(Achievements.byId[id])
	PlayerData.addCash(player, reward)
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
end

-- The noob took damage. `source` is a weapon id, or "Impact" for a crash.
function AchievementService.onHit(player, arena, source)
	AchievementService.award(player, "FirstContact")
	if WEAPON_ACHIEVEMENTS[source] then
		AchievementService.award(player, WEAPON_ACHIEVEMENTS[source])
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
	if arena:countRecentTraps() >= 2 then
		AchievementService.award(player, "ChainReaction")
	end
	if arena.realDamage >= 1000 then -- shown as 50,000 (see Config.SCORE_MULTIPLIER)
		AchievementService.award(player, "PointCollector")
	end
end

-- One body part was hit. `outcome` is "Torn" if it got torn off.
function AchievementService.onPartHit(player, arena, source, partKey, outcome)
	if source == "Crossbow" then
		if partKey == "Head" then
			AchievementService.award(player, "Headshot")
		elseif partKey == "LeftLeg" or partKey == "RightLeg" then
			AchievementService.award(player, "ArrowInTheKnee")
		end
	end
	if outcome == "Torn" then
		if source == "Mine" then
			AchievementService.award(player, "RedWire")
		end
		if arena.noob:limbsLeft() == 0 then
			AchievementService.award(player, "LordOfTheSeas")
		end
	end
end

-- The noob was destroyed. `partKey` is the body part that finished it off.
function AchievementService.onDestroyed(player, _arena, source, partKey)
	AchievementService.award(player, "Destroyed")
	if partKey == "Head" then
		AchievementService.award(player, "WithoutTheHead")
	end
	if source == "RocketLauncher" then
		AchievementService.award(player, "AirDefense")
	end
end

-- The noob touched part of the room. `speed` is how fast it was going.
function AchievementService.onSurface(player, arena, surface, speed)
	if surface == "Ceiling" then
		AchievementService.award(player, "FrequentFlyer")
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

-- A body part caught fire
function AchievementService.onIgnite(player, _arena)
	AchievementService.award(player, "Toasty")
end

return AchievementService
