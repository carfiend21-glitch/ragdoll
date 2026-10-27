-- Every weapon/trap in the game, in the order they appear on the bottom bar,
-- cheapest to most expensive.
-- Prices are based on how much damage a weapon does, weighted toward the first few
-- seconds after PLAY, so weapons that hit hard straight away (flamethrower,
-- explosives, rockets) cost more. Weapons that only hurt if the noob happens to touch
-- them (traps) are cheaper than ones that aim at it.
-- Like the original, weapons get used up: a life bar shows what's left, and used-up
-- weapons are gone after the run (no free refills when you restart).
-- `price` = cash ($) it costs to place one in your room (you get it back if you sell it).
-- `damage` = about how much damage one does in total (shown in the shop, and what the
--   price is based on). Crash damage from knocking the noob around comes on top.
-- `maxPlaced` = how many of this weapon can be in your room at once.
-- `uses` = how many times it works before it breaks.
-- `unlockedBy` = the achievement that unlocks it (starter weapons are always unlocked).
-- `exclusive` = it can only be unlocked with Noob Bucks or Robux, not an achievement
--   (see shared/ShopItems.luau for the Noob Buck prices).
-- `gamePassId` = the Game Pass that sells it for Robux. 0 means "not set up yet":
--   create the pass on the Creator Dashboard, then paste its ID number here.
-- `aims` = it turns to face the noob.
-- `fireInterval` = seconds between shots while the room is playing (it fires by itself).
--   Some only go off when the noob is close enough (boxing glove, tesla coil, ban hammer).
-- `fuse` = seconds of playing before it explodes by itself.
-- `onFloor` = it always sits on the floor. `onCeiling` = it always hangs from the ceiling.
-- `anySurface` = it sticks to the nearest floor, wall or ceiling, facing into the room.
local Weapons = {}

Weapons.list = {
	-- ~25 damage (5 bounces), but launches the noob into crashes
	{
		id = "BouncePad",
		name = "Bounce Pad",
		icon = "⏫",
		price = 20,
		damage = 25,
		maxPlaced = 6,
		description = "Launches the noob away from it. Stick it on the floor, walls or ceiling! 5 bounces.",
		starter = true,
		uses = 5,
		anySurface = true,
		size = Vector3.new(5, 1, 6),
	},
	-- up to ~70 damage (8 stabs), but only if the noob lands on it
	{
		id = "Spikes",
		name = "Spike Strip",
		icon = "📌",
		price = 28,
		damage = 70,
		maxPlaced = 4,
		description = "A row of sharp spikes. Stick it on the floor, walls or ceiling. 8 stabs.",
		unlockedBy = "FirstContact",
		uses = 8,
		anySurface = true,
		size = Vector3.new(5, 1.4, 3),
	},
	-- no damage of its own: it blows the noob across the room into the walls (8 seconds of wind)
	{
		id = "Fan",
		name = "Big Fan",
		icon = "🌀",
		price = 30,
		damage = 30,
		maxPlaced = 2,
		description = "Blows the noob away from it, into the walls. Stick it on any surface. 8 seconds of wind.",
		unlockedBy = "WatchYourStep",
		uses = 8,
		anySurface = true,
		size = Vector3.new(5, 2, 5),
	},
	-- ~80 damage over 12 seconds (6 arrows, headshots do double)
	{
		id = "Crossbow",
		name = "Crossbow",
		icon = "🏹",
		price = 36,
		damage = 80,
		maxPlaced = 4,
		description = "Shoots arrows at the noob by itself. 6 arrows.",
		starter = true,
		aims = true,
		fireInterval = 2,
		uses = 6,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~60 damage (5 punches) plus big crashes, but only when the noob comes close
	{
		id = "BoxingGlove",
		name = "Boxing Glove",
		icon = "🥊",
		price = 40,
		damage = 60,
		maxPlaced = 4,
		description = "Punches the noob hard when it comes close. Stick it on any surface. 5 punches.",
		unlockedBy = "WallSlam",
		fireInterval = 0.8,
		uses = 5,
		anySurface = true,
		size = Vector3.new(3, 2, 3),
	},
	-- ~45 damage to one body part in one snap, and it holds on for a moment
	{
		id = "BearTrap",
		name = "Bear Trap",
		icon = "🪤",
		price = 44,
		damage = 45,
		maxPlaced = 2,
		description = "Snaps shut on whatever steps in it and holds it tight. Floor only. 1 snap.",
		unlockedBy = "ArrowInTheKnee",
		uses = 1,
		onFloor = true,
		size = Vector3.new(4, 1, 3),
	},
	-- ~130 damage in one blast, but only if the noob lands on it
	{
		id = "Mine",
		name = "Land Mine",
		icon = "💣",
		price = 52,
		damage = 130,
		maxPlaced = 4,
		description = "Goes BOOM when the noob touches it. Sticks to the floor, walls or ceiling.",
		starter = true,
		explosive = true,
		uses = 1,
		anySurface = true, -- snaps to the nearest floor, wall or ceiling, like the bounce pad
		size = Vector3.new(3, 1, 3),
	},
	-- ~90 damage, all within 4 seconds (22 bullets)
	{
		id = "MachineGun",
		name = "Machine Gun",
		icon = "🔫",
		price = 56,
		damage = 90,
		maxPlaced = 4,
		description = "Sprays bullets at the noob. 22 bullets.",
		unlockedBy = "Sharpshooter",
		aims = true,
		fireInterval = 0.18,
		uses = 22,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~110 damage over 8 seconds (5 shells of 6 pellets), and each shell knocks the noob back
	{
		id = "Shotgun",
		name = "Shotgun",
		icon = "💥",
		price = 64,
		damage = 110,
		maxPlaced = 2,
		description = "Blasts the noob with 6 pellets at a time and knocks it flying. 5 shells.",
		unlockedBy = "Headshot",
		aims = true,
		fireInterval = 1.6,
		uses = 5,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~90 damage over 7 seconds (3 harpoons), and each one yanks the noob back toward it
	{
		id = "Harpoon",
		name = "Harpoon Gun",
		icon = "🔱",
		price = 68,
		damage = 90,
		maxPlaced = 2,
		description = "Spears the noob and yanks it back across the room. 3 harpoons.",
		unlockedBy = "Destroyed",
		aims = true,
		fireInterval = 2.2,
		uses = 3,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~85 damage (3 cannonballs) plus huge crashes, because each ball sends the noob flying
	{
		id = "Cannon",
		name = "Cannon",
		icon = "⚫",
		price = 74,
		damage = 100,
		maxPlaced = 2,
		description = "Fires heavy cannonballs that send the noob flying into the walls. 3 cannonballs.",
		unlockedBy = "Kaboom",
		aims = true,
		fireInterval = 2.5,
		uses = 3,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~170 damage over 10 seconds (4 beams that also set the noob on fire)
	{
		id = "Laser",
		name = "Laser Cannon",
		icon = "⚡",
		price = 76,
		damage = 170,
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
		damage = 145,
		maxPlaced = 2,
		description = "Blows up 1.5 seconds after you press PLAY.",
		unlockedBy = "FrequentFlyer",
		gamePassId = 0, -- can also be bought early (suggested price: 25 Robux)
		explosive = true,
		fuse = 1.5,
		uses = 1,
		onFloor = false,
		size = Vector3.new(2, 2, 2),
	},
	-- Flips the noob's gravity 4 times: no damage of its own, but every flip is a big
	-- crash into the ceiling or the floor (~120 damage of crashes)
	{
		id = "GravityFlipper",
		name = "Gravity Flipper",
		icon = "🔄",
		price = 84,
		damage = 120,
		maxPlaced = 1,
		description = "Flips gravity upside down, slamming the noob into the ceiling, then back down. 4 flips.",
		exclusive = true,
		gamePassId = 0, -- suggested price: 99 Robux
		fireInterval = 2.2,
		uses = 4,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~145 damage over 7 seconds (6 zaps of up to 3 body parts), but only when the noob is close
	{
		id = "TeslaCoil",
		name = "Tesla Coil",
		icon = "🌩️",
		price = 90,
		damage = 145,
		maxPlaced = 2,
		description = "Zaps the noob with lightning whenever it comes near. 6 zaps.",
		unlockedBy = "Toasty",
		fireInterval = 1.1,
		uses = 6,
		onFloor = false,
		size = Vector3.new(3, 5, 3),
	},
	-- ~60 damage over 9 seconds (4 shots), but each shot freezes the noob solid for
	-- 1.5 seconds, and frozen body parts take 50% more damage from EVERYTHING
	{
		id = "FreezeRay",
		name = "Freeze Ray",
		icon = "❄️",
		price = 96,
		damage = 140,
		maxPlaced = 2,
		description = "Freezes the noob solid. Frozen noobs take 50% more damage from everything! 4 shots.",
		exclusive = true,
		gamePassId = 0, -- suggested price: 99 Robux
		aims = true,
		fireInterval = 2.2,
		uses = 4,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~170 damage over 8 seconds (5 blobs that keep eating away at the body part they hit)
	{
		id = "AcidBlaster",
		name = "Acid Blaster",
		icon = "🧪",
		price = 104,
		damage = 170,
		maxPlaced = 2,
		description = "Splashes the noob with acid that keeps burning. 5 blobs.",
		exclusive = true,
		gamePassId = 0, -- suggested price: 99 Robux
		aims = true,
		fireInterval = 1.6,
		uses = 5,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- up to ~270 damage (30 bites), but only while the noob is touching it
	{
		id = "Saw",
		name = "Spinning Saw",
		icon = "🪚",
		price = 112,
		damage = 270,
		maxPlaced = 2,
		description = "Grabs anything that touches it and grinds it round the blade. Arms and legs saw off fastest. 30 bites.",
		unlockedBy = "Pinball",
		uses = 30,
		onFloor = false,
		size = Vector3.new(5, 5, 3),
	},
	-- ~165 damage over 7.5 seconds (5 lightning bolts that also set the noob on fire)
	{
		id = "StormCloud",
		name = "Storm Cloud",
		icon = "⛈️",
		price = 116,
		damage = 165,
		maxPlaced = 2,
		description = "Hangs from the ceiling and strikes the noob with lightning. 5 bolts.",
		exclusive = true,
		gamePassId = 0, -- suggested price: 149 Robux
		fireInterval = 1.5,
		uses = 5,
		onCeiling = true,
		size = Vector3.new(7, 3, 4),
	},
	-- ~160 damage (10 hits) plus crashes, but only when the noob is in its swing
	{
		id = "WreckingBall",
		name = "Wrecking Ball",
		icon = "⛓️",
		price = 120,
		damage = 160,
		maxPlaced = 2,
		description = "A spiked ball on a chain that swings back and forth from the ceiling. 10 hits.",
		unlockedBy = "WithoutTheHead",
		uses = 10,
		onCeiling = true,
		size = Vector3.new(4, 12, 4),
	},
	-- ~140 damage (4 slams) plus crashes into the floor, when the noob is underneath
	{
		id = "BanHammer",
		name = "Ban Hammer",
		icon = "🔨",
		price = 128,
		damage = 140,
		maxPlaced = 2,
		description = "A giant hammer on the ceiling. Slams down on the noob when it's underneath. 4 slams.",
		exclusive = true,
		gamePassId = 0, -- suggested price: 149 Robux
		fireInterval = 1,
		uses = 4,
		onCeiling = true,
		size = Vector3.new(4, 5, 3),
	},
	-- ~215 damage, guaranteed, in one huge blast 2.5 seconds after PLAY
	{
		id = "BigTNT",
		name = "Big TNT",
		icon = "🧱",
		price = 140,
		damage = 215,
		maxPlaced = 2,
		description = "A HUGE blast 2.5 seconds after you press PLAY.",
		unlockedBy = "Bombing",
		explosive = true,
		fuse = 2.5,
		uses = 1,
		onFloor = true,
		size = Vector3.new(3, 2.4, 2),
	},
	-- ~180 damage over 6 seconds (2 shots that go straight through the whole noob)
	{
		id = "Railgun",
		name = "Railgun",
		icon = "🔋",
		price = 150,
		damage = 180,
		maxPlaced = 1,
		description = "Charges up, then fires a beam that goes through EVERY body part in its way. 2 shots.",
		exclusive = true,
		gamePassId = 0, -- suggested price: 199 Robux
		aims = true,
		fireInterval = 3,
		uses = 2,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~230 damage, 2 seconds after PLAY: one blast, then 5 little bombs go off all around it
	{
		id = "ClusterBomb",
		name = "Cluster Bomb",
		icon = "🎆",
		price = 160,
		damage = 230,
		maxPlaced = 1,
		description = "Blows up 2 seconds after PLAY and throws out 5 little bombs that go off too.",
		unlockedBy = "RedWire",
		explosive = true,
		fuse = 2,
		uses = 1,
		onFloor = false,
		size = Vector3.new(2.4, 2.4, 2.4),
	},
	-- ~180 damage in about 4 seconds (45 bullets after a 1 second spin-up)
	{
		id = "Minigun",
		name = "Minigun",
		icon = "🌪️",
		price = 180,
		damage = 180,
		maxPlaced = 1,
		description = "Spins up, then shreds the noob with a storm of bullets. 45 bullets.",
		exclusive = true,
		gamePassId = 0, -- suggested price: 249 Robux
		aims = true,
		fireInterval = 0.08,
		uses = 45,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~200 damage in about 4.5 seconds (8 missiles that chase the noob)
	{
		id = "MissileSwarm",
		name = "Missile Swarm",
		icon = "🎯",
		price = 190,
		damage = 200,
		maxPlaced = 1,
		description = "Fires little missiles 2 at a time that chase the noob wherever it goes. 8 missiles.",
		exclusive = true,
		gamePassId = 0, -- suggested price: 249 Robux
		aims = true,
		fireInterval = 1.1,
		uses = 4,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~420 damage over 8 seconds (counting the burning), ~250 of it in the first 5 seconds
	{
		id = "Flamethrower",
		name = "Flamethrower",
		icon = "🔥",
		price = 200,
		damage = 420,
		maxPlaced = 1,
		description = "Sets the noob on fire. 5 blasts of flame.",
		unlockedBy = "ChainReaction",
		aims = true,
		fireInterval = 1.6,
		uses = 5,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~250 damage: sucks the noob in and grinds it for 4 seconds, then collapses in a big blast
	{
		id = "BlackHole",
		name = "Black Hole",
		icon = "🕳️",
		price = 210,
		damage = 250,
		maxPlaced = 1,
		description = "Sucks the noob in and spins it round for 4 seconds, then collapses with a BOOM.",
		exclusive = true,
		gamePassId = 0, -- suggested price: 299 Robux
		fuse = 4,
		uses = 1,
		onFloor = false,
		size = Vector3.new(4, 4, 2),
	},
	-- ~525 damage over 7.5 seconds (3 rockets), ~350 of it in the first 5 seconds
	{
		id = "RocketLauncher",
		name = "Rockets",
		icon = "🚀",
		price = 220,
		damage = 525,
		maxPlaced = 1,
		description = "Fires rockets at the noob by itself. 3 rockets.",
		gamePassId = 0, -- Robux only (suggested price: 99 Robux)
		aims = true,
		fireInterval = 2.5,
		uses = 3,
		onFloor = false,
		size = Vector3.new(3, 3, 3),
	},
	-- ~330 damage, guaranteed, 3 seconds after PLAY: a blast that fills the whole room
	-- and sets every body part on fire
	{
		id = "MiniNuke",
		name = "Mini Nuke",
		icon = "☢️",
		price = 250,
		damage = 330,
		maxPlaced = 1,
		description = "3... 2... 1... a blast that fills the WHOLE room and sets the noob on fire.",
		exclusive = true,
		gamePassId = 0, -- suggested price: 399 Robux
		explosive = true,
		fuse = 3,
		uses = 1,
		onFloor = true,
		size = Vector3.new(2.6, 3.2, 2.6),
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
