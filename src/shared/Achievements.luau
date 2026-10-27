-- Every achievement. The server decides when they're earned (see server/AchievementService).
-- Weapons say which achievement unlocks them, in Weapons.luau.
-- `reward` = cash ($) you get for earning it (Achievements.DEFAULT_REWARD if not set).
-- `bucks` = Noob Bucks you get for earning it (none if not set).
local Config = require(script.Parent.Config)

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
	{ id = "RedWire", name = "The Red Wire", description = "Knock a limb off with a land mine." },
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
	-- Skill ones
	{ id = "ToTheMoon", name = "To The Moon", description = "Smash the noob into the ceiling really fast." },
	{ id = "HangTime", name = "Hang Time", description = "Keep the noob in the air for 4 seconds straight.", reward = 160 },
	{ id = "ComboKing", name = "Combo King", description = "Build a 15-hit combo.", reward = 200 },
	{ id = "HatTrick", name = "Hat Trick", description = "Destroy the noob 3 times in one round.", reward = 200 },
	{ id = "ExtraCrispy", name = "Extra Crispy", description = "Have 4 body parts on fire at the same time.", reward = 160 },

	-- One for each of the newer weapons
	{ id = "Pincushion", name = "Pincushion", description = "Stab the noob with spikes 5 times in one run." },
	{ id = "GoneWithTheWind", name = "Gone With the Wind", description = "Blow the noob into the ceiling with the Big Fan." },
	{ id = "Knockout", name = "Knockout!", description = "Punch the noob in the head with the Boxing Glove." },
	{ id = "Gotcha", name = "Gotcha!", description = "Catch the noob in a Bear Trap." },
	{ id = "CloseRange", name = "Close Range", description = "Hit the noob with 12 shotgun pellets in one run." },
	{ id = "GetOverHere", name = "Get Over Here!", description = "Spear the noob with the Harpoon Gun." },
	{ id = "HumanCannonball", name = "Human Cannonball", description = "Hit the noob with a cannonball." },
	{ id = "Shocking", name = "Shocking!", description = "Zap 3 body parts at once with the Tesla Coil.", reward = 160 },
	{ id = "Wrecked", name = "Wrecked", description = "Smash the noob with the Wrecking Ball." },
	{ id = "ClusterFun", name = "Cluster Fun", description = "Hit the noob 4 times with one Cluster Bomb in one run.", reward = 160 },
	-- ...and the exclusive ones
	{ id = "UpsideDown", name = "Upside Down", description = "Slam the noob into the ceiling with the Gravity Flipper." },
	{ id = "BrainFreeze", name = "Brain Freeze", description = "Freeze the noob's head with the Freeze Ray." },
	{ id = "MeltDown", name = "Meltdown", description = "Splash the noob with acid 3 times in one run." },
	{ id = "Thunderstruck", name = "Thunderstruck", description = "Strike the noob with the Storm Cloud's lightning." },
	{ id = "Banned", name = "BANNED!", description = "Slam the noob with the Ban Hammer." },
	{ id = "PiercingShot", name = "Piercing Shot", description = "Hit 3 body parts with one Railgun shot.", reward = 160 },
	{ id = "BulletStorm", name = "Bullet Storm", description = "Hit the noob with 30 Minigun bullets in one run.", reward = 160 },
	{ id = "HeatSeeker", name = "Heat Seeker", description = "Hit the noob with 6 Missile Swarm missiles in one run.", reward = 160 },
	{ id = "EventHorizon", name = "Event Horizon", description = "Destroy the noob with the Black Hole.", reward = 200 },
	{ id = "GroundZero", name = "Ground Zero", description = "Destroy the noob with the Mini Nuke.", reward = 200 },

	-- Collecting weapons. These give Noob Bucks (`bucks`) instead of round cash, because
	-- you often earn them in the lobby, where cash doesn't last.
	{ id = "ExclusiveClub", name = "Exclusive Club", description = "Unlock an exclusive weapon.", reward = 0, bucks = 2 },
	{ id = "Armory", name = "Armory", description = "Unlock 15 weapons.", reward = 0, bucks = 3 },
	{ id = "FullArsenal", name = "Full Arsenal", description = "Unlock all 30 weapons.", reward = 0, bucks = 15 },
}

Achievements.byId = {}
for _, achievement in Achievements.list do
	Achievements.byId[achievement.id] = achievement
end

-- Cash ($) for earning it, boosted by Config.ACHIEVEMENT_CASH_MULTIPLIER
function Achievements.rewardFor(achievement)
	return math.floor((achievement.reward or Achievements.DEFAULT_REWARD) * Config.ACHIEVEMENT_CASH_MULTIPLIER)
end

return Achievements
