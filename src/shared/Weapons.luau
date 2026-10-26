-- Every weapon/trap in the game.
-- `uses` = how many times it works before it breaks.
-- `unlockedBy` = the achievement that unlocks it (starter weapons are always unlocked).
local Weapons = {}

Weapons.list = {
	{
		id = "Crossbow",
		name = "Crossbow",
		icon = "🏹",
		description = "Click it to shoot the noob. 6 shots.",
		starter = true,
		uses = 6,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	{
		id = "Mine",
		name = "Land Mine",
		icon = "💣",
		description = "Goes BOOM when the noob touches it.",
		starter = true,
		explosive = true,
		uses = 1,
		onFloor = true,
		size = Vector3.new(3, 1, 3),
	},
	{
		id = "BouncePad",
		name = "Bounce Pad",
		icon = "⏫",
		description = "Launches the noob sky-high. 5 bounces.",
		starter = true,
		uses = 5,
		onFloor = true,
		size = Vector3.new(5, 1, 6),
	},
	{
		id = "Grenade",
		name = "Grenade",
		icon = "🧨",
		description = "Click it to blow it up!",
		unlockedBy = "FrequentFlyer",
		explosive = true,
		uses = 1,
		onFloor = false,
		size = Vector3.new(2, 2, 2),
	},
}

Weapons.byId = {}
for _, weapon in Weapons.list do
	Weapons.byId[weapon.id] = weapon
end

-- `achievements` is a set like { FrequentFlyer = true }
function Weapons.isUnlocked(weapon, achievements)
	return weapon.starter == true or (weapon.unlockedBy ~= nil and achievements[weapon.unlockedBy] == true)
end

return Weapons
