-- Every weapon/trap in the game, in the order they appear on the bottom bar,
-- cheapest to most expensive.
-- Prices are based on how much damage a weapon does, weighted toward the first few
-- seconds after PLAY, so weapons that hit hard straight away (flamethrower,
-- explosives, rockets) cost more.
-- Like the original, weapons get used up: a life bar shows what's left, and used-up
-- weapons are gone after the run (no free refills when you restart).
-- `price` = cash ($) it costs to place one in your room (you get it back if you sell it).
-- `maxPlaced` = how many of this weapon can be in your room at once.
-- `uses` = how many times it works before it breaks.
-- `unlockedBy` = the achievement that unlocks it (starter weapons are always unlocked).
-- `gamePassId` = the Game Pass that sells it for Robux. 0 means "not set up yet":
--   create the pass on the Creator Dashboard, then paste its ID number here.
-- `aims` = it turns to face the noob.
-- `fireInterval` = seconds between shots while the room is playing (it fires by itself).
-- `fuse` = seconds of playing before it explodes by itself.
-- `onFloor` = it always sits on the floor. `anySurface` = it sticks to the nearest
--   floor, wall or ceiling, facing into the room.
local Weapons = {}

Weapons.list = {
	-- ~25 damage (5 bounces), but launches the noob into crashes
	{
		id = "BouncePad",
		name = "Bounce Pad",
		icon = "⏫",
		price = 20,
		maxPlaced = 6,
		description = "Launches the noob away from it. Stick it on the floor, walls or ceiling! 5 bounces.",
		starter = true,
		uses = 5,
		anySurface = true,
		size = Vector3.new(5, 1, 6),
	},
	-- ~80 damage over 12 seconds (6 arrows, headshots do double)
	{
		id = "Crossbow",
		name = "Crossbow",
		icon = "🏹",
		price = 36,
		maxPlaced = 4,
		description = "Shoots arrows at the noob by itself. 6 arrows.",
		starter = true,
		aims = true,
		fireInterval = 2,
		uses = 6,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~130 damage in one blast, but only if the noob lands on it
	{
		id = "Mine",
		name = "Land Mine",
		icon = "💣",
		price = 52,
		maxPlaced = 4,
		description = "Goes BOOM when the noob touches it.",
		starter = true,
		explosive = true,
		uses = 1,
		onFloor = true,
		size = Vector3.new(3, 1, 3),
	},
	-- ~90 damage, all within 4 seconds (22 bullets)
	{
		id = "MachineGun",
		name = "Machine Gun",
		icon = "🔫",
		price = 56,
		maxPlaced = 4,
		description = "Sprays bullets at the noob. 22 bullets.",
		unlockedBy = "Sharpshooter",
		aims = true,
		fireInterval = 0.18,
		uses = 22,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~170 damage over 10 seconds (4 beams that also set the noob on fire)
	{
		id = "Laser",
		name = "Laser Cannon",
		icon = "⚡",
		price = 76,
		maxPlaced = 2,
		description = "Fires a burning laser beam. 4 shots.",
		unlockedBy = "Collector",
		aims = true,
		fireInterval = 2.5,
		uses = 4,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~145 damage, guaranteed, 1.5 seconds after PLAY
	{
		id = "Grenade",
		name = "Grenade",
		icon = "🧨",
		price = 80,
		maxPlaced = 4,
		description = "Blows up 1.5 seconds after you press PLAY.",
		unlockedBy = "FrequentFlyer",
		gamePassId = 0, -- can also be bought early (suggested price: 25 Robux)
		explosive = true,
		fuse = 1.5,
		uses = 1,
		onFloor = false,
		size = Vector3.new(2, 2, 2),
	},
	-- up to ~270 damage (30 bites), but only while the noob is touching it
	{
		id = "Saw",
		name = "Spinning Saw",
		icon = "🪚",
		price = 112,
		maxPlaced = 2,
		description = "Grabs anything that touches it and grinds it round the blade. Arms and legs saw off fastest. 30 bites.",
		unlockedBy = "Pinball",
		uses = 30,
		onFloor = false,
		size = Vector3.new(5, 5, 3),
	},
	-- ~215 damage, guaranteed, in one huge blast 2.5 seconds after PLAY
	{
		id = "BigTNT",
		name = "Big TNT",
		icon = "🧱",
		price = 140,
		maxPlaced = 2,
		description = "A HUGE blast 2.5 seconds after you press PLAY.",
		unlockedBy = "Bombing",
		explosive = true,
		fuse = 2.5,
		uses = 1,
		onFloor = true,
		size = Vector3.new(3, 2.4, 2),
	},
	-- ~420 damage over 8 seconds (counting the burning), ~250 of it in the first 5 seconds
	{
		id = "Flamethrower",
		name = "Flamethrower",
		icon = "🔥",
		price = 200,
		maxPlaced = 1,
		description = "Sets the noob on fire. 5 blasts of flame.",
		unlockedBy = "ChainReaction",
		aims = true,
		fireInterval = 1.6,
		uses = 5,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~525 damage over 7.5 seconds (3 rockets), ~350 of it in the first 5 seconds
	{
		id = "RocketLauncher",
		name = "Rockets",
		icon = "🚀",
		price = 220,
		maxPlaced = 1,
		description = "Fires rockets at the noob by itself. 3 rockets.",
		gamePassId = 0, -- Robux only (suggested price: 99 Robux)
		aims = true,
		fireInterval = 2.5,
		uses = 3,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
}

Weapons.byId = {}
Weapons.byGamePass = {}
for _, weapon in Weapons.list do
	Weapons.byId[weapon.id] = weapon
	if weapon.gamePassId and weapon.gamePassId > 0 then
		Weapons.byGamePass[weapon.gamePassId] = weapon
	end
end

-- `achievements` is a set like { FrequentFlyer = true };
-- `owned` is a set of weapon ids bought with Robux, like { RocketLauncher = true }
function Weapons.isUnlocked(weapon, achievements, owned)
	return weapon.starter == true
		or (weapon.unlockedBy ~= nil and achievements[weapon.unlockedBy] == true)
		or owned[weapon.id] == true
end

return Weapons
