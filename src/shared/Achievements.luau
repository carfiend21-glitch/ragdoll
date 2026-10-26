-- Every achievement. The server decides when they're earned (see server/AchievementService).
-- Weapons say which achievement unlocks them, in Weapons.luau.
-- `reward` = cash ($) you get for earning it (Achievements.DEFAULT_REWARD if not set).
local Achievements = {}

Achievements.DEFAULT_REWARD = 100

Achievements.list = {
	{ id = "FirstContact", name = "First Contact", description = "Hurt the noob for the first time.", reward = 40 },
	{ id = "WatchYourStep", name = "Watch Your Step", description = "Make the noob set off a land mine." },
	{ id = "Bullseye", name = "Bullseye", description = "Hit the noob with an arrow." },
	{ id = "FrequentFlyer", name = "Frequent Flyer", description = "Launch the noob into the ceiling." },
	{ id = "Kaboom", name = "Kaboom", description = "Blow up the noob with a grenade." },
	{ id = "WallSlam", name = "Wall Slam", description = "Smash the noob into a wall really fast." },
	{
		id = "ChainReaction",
		name = "Chain Reaction",
		description = "Hit the noob with 2 different traps within 2 seconds.",
		reward = 160,
	},
	{ id = "PointCollector", name = "Point Collector", description = "Deal 50,000 damage in one round.", reward = 200 },
	-- From the original game
	{ id = "Destroyed", name = "Destroyed!!!", description = "Destroy the noob.", reward = 160 },
	{ id = "WithoutTheHead", name = "Without the Head!", description = "Knock the noob's head off.", reward = 160 },
	{ id = "Headshot", name = "Headshot!!!", description = "Hit the noob's head with an arrow." },
	{ id = "ArrowInTheKnee", name = "Arrow in the Knee", description = "Hit the noob's leg with an arrow." },
	{ id = "RedWire", name = "The Red Wire", description = "Tear off a limb with a land mine." },
	{
		id = "LordOfTheSeas",
		name = "Lord of the Seas",
		description = "Leave the noob with no arms and no legs.",
		reward = 200,
	},
	{ id = "AirDefense", name = "Air Defense", description = "Destroy the noob with a rocket.", reward = 160 },
	-- These unlock the bigger weapons
	{ id = "Sharpshooter", name = "Sharpshooter", description = "Hit the noob with 10 arrows in one round.", reward = 160 },
	{ id = "Pinball", name = "Pinball", description = "Bounce the noob off the walls 5 times in one run.", reward = 160 },
	{ id = "Bombing", name = "Bombing", description = "Blow up the noob with land mines 5 times in one round.", reward = 160 },
	{ id = "Collector", name = "Collector", description = "Earn 10 achievements.", reward = 300 },
	{ id = "Toasty", name = "Toasty", description = "Set the noob on fire." },
}

Achievements.byId = {}
for _, achievement in Achievements.list do
	Achievements.byId[achievement.id] = achievement
end

function Achievements.rewardFor(achievement)
	return achievement.reward or Achievements.DEFAULT_REWARD
end

return Achievements
