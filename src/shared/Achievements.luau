-- Every achievement. The server decides when they're earned (see server/AchievementService).
-- Weapons say which achievement unlocks them, in Weapons.luau.
local Achievements = {}

Achievements.list = {
	{ id = "FirstContact", name = "First Contact", description = "Hurt the noob for the first time." },
	{ id = "WatchYourStep", name = "Watch Your Step", description = "Make the noob set off a land mine." },
	{ id = "Bullseye", name = "Bullseye", description = "Hit the noob with a crossbow bolt." },
	{ id = "FrequentFlyer", name = "Frequent Flyer", description = "Launch the noob into the ceiling." },
	{ id = "Kaboom", name = "Kaboom", description = "Blow up the noob with a grenade." },
	{ id = "WallSlam", name = "Wall Slam", description = "Smash the noob into a wall really fast." },
	{
		id = "ChainReaction",
		name = "Chain Reaction",
		description = "Hit the noob with 2 different traps within 2 seconds.",
	},
	{ id = "PointCollector", name = "Point Collector", description = "Deal 1,000 damage in one round." },
}

Achievements.byId = {}
for _, achievement in Achievements.list do
	Achievements.byId[achievement.id] = achievement
end

return Achievements
