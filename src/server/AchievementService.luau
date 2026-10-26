-- Decides when achievements are earned and tells the player.
-- To add an achievement: add it to shared/Achievements.luau, then award it here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)

local PlayerData = require(script.Parent.PlayerData)

local WALL_SLAM_SPEED = 70

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
	local newWeapons = {}
	for _, weapon in Weapons.list do
		if weapon.unlockedBy == id then
			table.insert(newWeapons, weapon.id)
		end
	end
	Remotes.AchievementUnlocked:FireClient(player, id, newWeapons)
	Remotes.DataSync:FireClient(player, PlayerData.getAchievementList(player))
end

-- The noob took damage. `source` is a weapon id, or "Impact" for a crash.
function AchievementService.onHit(player, arena, source)
	AchievementService.award(player, "FirstContact")
	if WEAPON_ACHIEVEMENTS[source] then
		AchievementService.award(player, WEAPON_ACHIEVEMENTS[source])
	end
	if arena:countRecentTraps() >= 2 then
		AchievementService.award(player, "ChainReaction")
	end
	if arena.damage >= 1000 then
		AchievementService.award(player, "PointCollector")
	end
end

-- The noob touched part of the room. `speed` is how fast it was going.
function AchievementService.onSurface(player, _arena, surface, speed)
	if surface == "Ceiling" then
		AchievementService.award(player, "FrequentFlyer")
	elseif surface == "Wall" and speed >= WALL_SLAM_SPEED then
		AchievementService.award(player, "WallSlam")
	end
end

return AchievementService
