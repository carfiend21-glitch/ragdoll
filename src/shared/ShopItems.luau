-- Everything you can buy with Noob Bucks. Shared by the server (which checks and
-- saves purchases) and players' screens (the shop window).
--
-- What Noob Bucks buy:
--   * EXCLUSIVE weapons, only from the shop. They aren't stronger for their
--     price: like every weapon they cost cash in the round, priced by how much damage
--     they do (see Weapons.luau). They're new ways to play, not a shortcut to winning.
--   * Early unlocks: a weapon now, instead of earning its achievement first.
--   * 1-round trials: try an exclusive weapon for one round, cheap.
--   * Bundles: a few things together for less than buying them one by one.
--   * Looks: noob skins, blood, rooms, weapon finishes, titles and trails.
-- Every day one item is the DEAL OF THE DAY: 40% off for 24 hours (the same deal on
-- every server, worked out from the date).
--
-- Prices: a round winner earns 1 coin, and with up to 8 players that's a few coins
-- an hour for most people. So cheap items (5-15) take a few hours of winning,
-- the big flex items (60-90) are mostly for people who buy coins. 1 coin costs about
-- R$ 5-7 in the packs (see NoobBucks.luau).
local ShopItems = {}

-- The tabs down the side of the shop, in order. (The shop window adds a "Featured" tab
-- on top, with the deal of the day and the bundles, and a "Get Bucks" tab.)
ShopItems.CATEGORIES = {
	{ id = "Exclusive", name = "Exclusive", icon = "⭐" },
	{ id = "Weapon", name = "Unlock Early", icon = "🔓" },
	{ id = "Trial", name = "1-Round Trials", icon = "🎟️" },
	{ id = "NoobSkin", name = "Noob Skins", icon = "🧍" },
	{ id = "Blood", name = "Blood", icon = "🩸" },
	{ id = "Room", name = "Rooms", icon = "🏠" },
	{ id = "Finish", name = "Weapon Finish", icon = "✨" },
	{ id = "Title", name = "Titles", icon = "🏷️" },
	{ id = "Trail", name = "Trails", icon = "🌈" },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local CLASSIC_YELLOW = BrickColor.new("Bright yellow").Color
local CLASSIC_BLUE = BrickColor.new("Bright blue").Color
local CLASSIC_GREEN = BrickColor.new("Br. yellowish green").Color

-- `kind`: "unlock" = a weapon unlocked for good, "rent" = a weapon you can use until the
-- end of the next round you place it in, "bundle" = everything in `contents` at once,
-- "robux" = a weapon only sold for Robux (its card just opens the Game Pass).
-- `new` = it gets a NEW badge. `robux` = the suggested Robux price of the weapon's Game
-- Pass (the shop only shows a Robux button once its `gamePassId` is set in Weapons.luau).
ShopItems.list = {
	-- Exclusive weapons: only from the shop, with Noob Bucks
	{ id = "UnlockGravityFlipper", category = "Exclusive", kind = "unlock", weapon = "GravityFlipper", name = "Gravity Flipper", price = 15, new = true },
	{ id = "UnlockFreezeRay", category = "Exclusive", kind = "unlock", weapon = "FreezeRay", name = "Freeze Ray", price = 20, new = true },
	{ id = "UnlockAcidBlaster", category = "Exclusive", kind = "unlock", weapon = "AcidBlaster", name = "Acid Blaster", price = 20, new = true },
	{ id = "UnlockStormCloud", category = "Exclusive", kind = "unlock", weapon = "StormCloud", name = "Storm Cloud", price = 25, new = true },
	{ id = "UnlockBanHammer", category = "Exclusive", kind = "unlock", weapon = "BanHammer", name = "Ban Hammer", price = 25, new = true },
	{ id = "UnlockRailgun", category = "Exclusive", kind = "unlock", weapon = "Railgun", name = "Railgun", price = 30, new = true },
	{ id = "UnlockMinigun", category = "Exclusive", kind = "unlock", weapon = "Minigun", name = "Minigun", price = 40, new = true },
	{ id = "UnlockMissileSwarm", category = "Exclusive", kind = "unlock", weapon = "MissileSwarm", name = "Missile Swarm", price = 40, new = true },
	{ id = "UnlockRocketLauncher", category = "Exclusive", kind = "unlock", weapon = "RocketLauncher", name = "Rocket Launcher", price = 35, new = true },
	-- Robux only: these two can't be bought with Noob Bucks (only tried for a round, below).
	-- `price` is 0 because they cost no Noob Bucks; `robux` is what the Game Pass costs.
	{ id = "RobuxBlackHole", category = "Exclusive", kind = "robux", weapon = "BlackHole", name = "Black Hole", price = 0, robux = 299, new = true },
	{ id = "RobuxMiniNuke", category = "Exclusive", kind = "robux", weapon = "MiniNuke", name = "Mini Nuke", price = 0, robux = 399, new = true },

	-- Weapons: unlock early instead of earning the achievement first
	{ id = "UnlockSpikes", category = "Weapon", kind = "unlock", weapon = "Spikes", name = "Spike Strip", price = 5, new = true },
	{ id = "UnlockFan", category = "Weapon", kind = "unlock", weapon = "Fan", name = "Big Fan", price = 5, new = true },
	{ id = "UnlockBoxingGlove", category = "Weapon", kind = "unlock", weapon = "BoxingGlove", name = "Boxing Glove", price = 8, new = true },
	{ id = "UnlockBearTrap", category = "Weapon", kind = "unlock", weapon = "BearTrap", name = "Bear Trap", price = 8, new = true },
	{ id = "UnlockMachineGun", category = "Weapon", kind = "unlock", weapon = "MachineGun", name = "Machine Gun", price = 10 },
	{ id = "UnlockGrenade", category = "Weapon", kind = "unlock", weapon = "Grenade", name = "Grenade", price = 10 },
	{ id = "UnlockShotgun", category = "Weapon", kind = "unlock", weapon = "Shotgun", name = "Shotgun", price = 12, new = true },
	{ id = "UnlockHarpoon", category = "Weapon", kind = "unlock", weapon = "Harpoon", name = "Harpoon Gun", price = 12, new = true },
	{ id = "UnlockCannon", category = "Weapon", kind = "unlock", weapon = "Cannon", name = "Cannon", price = 14, new = true },
	{ id = "UnlockSaw", category = "Weapon", kind = "unlock", weapon = "Saw", name = "Spinning Saw", price = 18 },
	{ id = "UnlockTeslaCoil", category = "Weapon", kind = "unlock", weapon = "TeslaCoil", name = "Tesla Coil", price = 18, new = true },
	{ id = "UnlockLaser", category = "Weapon", kind = "unlock", weapon = "Laser", name = "Laser Cannon", price = 20 },
	{ id = "UnlockBigTNT", category = "Weapon", kind = "unlock", weapon = "BigTNT", name = "Big TNT", price = 22 },
	{ id = "UnlockWreckingBall", category = "Weapon", kind = "unlock", weapon = "WreckingBall", name = "Wrecking Ball", price = 22, new = true },
	{ id = "UnlockClusterBomb", category = "Weapon", kind = "unlock", weapon = "ClusterBomb", name = "Cluster Bomb", price = 26, new = true },
	{ id = "UnlockFlamethrower", category = "Weapon", kind = "unlock", weapon = "Flamethrower", name = "Flamethrower", price = 30 },

	-- 1-round trials: a cheap taste of a weapon you don't have (only used up once it's
	-- been placed in a round). After about 5-8 trials, unlocking it is the better deal.
	{ id = "RentRocketLauncher", category = "Trial", kind = "rent", weapon = "RocketLauncher", name = "Rocket Launcher", price = 3 },
	{ id = "RentGravityFlipper", category = "Trial", kind = "rent", weapon = "GravityFlipper", name = "Gravity Flipper", price = 3 },
	{ id = "RentFreezeRay", category = "Trial", kind = "rent", weapon = "FreezeRay", name = "Freeze Ray", price = 3 },
	{ id = "RentAcidBlaster", category = "Trial", kind = "rent", weapon = "AcidBlaster", name = "Acid Blaster", price = 3 },
	{ id = "RentStormCloud", category = "Trial", kind = "rent", weapon = "StormCloud", name = "Storm Cloud", price = 4 },
	{ id = "RentBanHammer", category = "Trial", kind = "rent", weapon = "BanHammer", name = "Ban Hammer", price = 4 },
	{ id = "RentRailgun", category = "Trial", kind = "rent", weapon = "Railgun", name = "Railgun", price = 5 },
	{ id = "RentMinigun", category = "Trial", kind = "rent", weapon = "Minigun", name = "Minigun", price = 6 },
	{ id = "RentMissileSwarm", category = "Trial", kind = "rent", weapon = "MissileSwarm", name = "Missile Swarm", price = 6 },
	{ id = "RentBlackHole", category = "Trial", kind = "rent", weapon = "BlackHole", name = "Black Hole", price = 7 },
	{ id = "RentMiniNuke", category = "Trial", kind = "rent", weapon = "MiniNuke", name = "Mini Nuke", price = 9 },

	-- Bundles (on the Featured tab): cheaper than buying what's in them one by one.
	-- If you already own some of it, the bundle costs less (see ShopItems.bundlePrice).
	{
		id = "BundleArsenal",
		category = "Bundle",
		kind = "bundle",
		name = "Heavy Arsenal",
		contents = { "UnlockShotgun", "UnlockHarpoon", "UnlockCannon" },
		price = 25,
	},
	{
		id = "BundleStorm",
		category = "Bundle",
		kind = "bundle",
		name = "Storm Chaser",
		contents = { "UnlockStormCloud", "UnlockTeslaCoil", "StormTrail" },
		price = 50,
	},
	{
		id = "BundleScientist",
		category = "Bundle",
		kind = "bundle",
		name = "Mad Scientist",
		contents = { "UnlockFreezeRay", "UnlockAcidBlaster", "UnlockRailgun", "ScientistTitle" },
		price = 60,
	},
	{
		id = "BundleDoomsday",
		category = "Bundle",
		kind = "bundle",
		name = "Doomsday",
		contents = { "UnlockMinigun", "UnlockMissileSwarm", "LavaNoob" },
		price = 85,
	},

	-- Noob skins: what the noob in your room looks like (everyone watching sees it too)
	{ id = "ClassicNoob", category = "NoobSkin", name = "Classic Noob", price = 0, colors = { Head = CLASSIC_YELLOW, Torso = CLASSIC_BLUE, Arm = CLASSIC_YELLOW, Leg = CLASSIC_GREEN } },
	{ id = "ZombieNoob", category = "NoobSkin", name = "Zombie Noob", price = 25, colors = { Head = rgb(110, 160, 85), Torso = rgb(115, 85, 60), Arm = rgb(110, 160, 85), Leg = rgb(45, 55, 95) } },
	{ id = "NinjaNoob", category = "NoobSkin", name = "Ninja Noob", price = 25, colors = { Head = rgb(30, 30, 36), Torso = rgb(30, 30, 36), Arm = rgb(30, 30, 36), Leg = rgb(30, 30, 36) } },
	{ id = "RobotNoob", category = "NoobSkin", name = "Robot Noob", price = 40, material = Enum.Material.Metal, colors = { Head = rgb(185, 190, 200), Torso = rgb(150, 155, 165), Arm = rgb(115, 120, 130), Leg = rgb(115, 120, 130) } },
	{ id = "GhostNoob", category = "NoobSkin", name = "Ghost Noob", price = 40, transparency = 0.4, colors = { Head = rgb(235, 240, 255), Torso = rgb(235, 240, 255), Arm = rgb(235, 240, 255), Leg = rgb(235, 240, 255) } },
	{ id = "LavaNoob", category = "NoobSkin", name = "Lava Noob", price = 45, new = true, material = Enum.Material.CrackedLava, colors = { Head = rgb(255, 120, 30), Torso = rgb(70, 30, 25), Arm = rgb(255, 120, 30), Leg = rgb(70, 30, 25) } },
	{ id = "GoldNoob", category = "NoobSkin", name = "Golden Noob", price = 80, material = Enum.Material.Metal, reflectance = 0.25, colors = { Head = rgb(255, 200, 60), Torso = rgb(255, 190, 40), Arm = rgb(255, 200, 60), Leg = rgb(240, 175, 35) } },
	{ id = "DiamondNoob", category = "NoobSkin", name = "Diamond Noob", price = 90, new = true, material = Enum.Material.Glass, reflectance = 0.3, transparency = 0.15, colors = { Head = rgb(170, 240, 255), Torso = rgb(120, 210, 255), Arm = rgb(170, 240, 255), Leg = rgb(120, 210, 255) } },

	-- Blood: the color of the splatter in your room (and your replays)
	{ id = "ClassicBlood", category = "Blood", name = "Classic Blood", price = 0, colors = { rgb(150, 0, 0), rgb(120, 0, 5), rgb(175, 10, 10) } },
	{ id = "SlimeBlood", category = "Blood", name = "Slime", price = 15, colors = { rgb(90, 220, 60), rgb(60, 180, 40), rgb(140, 245, 80) } },
	{ id = "InkBlood", category = "Blood", name = "Ink", price = 15, colors = { rgb(40, 20, 70), rgb(25, 10, 45), rgb(70, 35, 110) } },
	{ id = "RainbowBlood", category = "Blood", name = "Rainbow", price = 35, colors = { rgb(255, 60, 60), rgb(255, 200, 40), rgb(80, 220, 90), rgb(60, 150, 255), rgb(190, 90, 255) } },

	-- Rooms: the walls, floor and ceiling of your test room
	{ id = "ClassicRoom", category = "Room", name = "Test Lab", price = 0, theme = {} },
	{
		id = "DungeonRoom",
		category = "Room",
		name = "Dungeon",
		price = 30,
		theme = {
			Floor = { rgb(85, 82, 78), Enum.Material.Cobblestone },
			Ceiling = { rgb(60, 55, 50), Enum.Material.Slate },
			Wall = { rgb(120, 85, 70), Enum.Material.Brick },
			BackWall = { rgb(105, 75, 62), Enum.Material.Brick },
			Stripe = { rgb(70, 60, 52), Enum.Material.Slate },
			Lamp = { rgb(255, 170, 70), Enum.Material.Neon },
		},
	},
	{
		id = "CandyRoom",
		category = "Room",
		name = "Candy Land",
		price = 30,
		theme = {
			Floor = { rgb(255, 170, 200), Enum.Material.SmoothPlastic },
			Ceiling = { rgb(210, 190, 255), Enum.Material.SmoothPlastic },
			Wall = { rgb(170, 240, 220), Enum.Material.SmoothPlastic },
			BackWall = { rgb(255, 222, 236), Enum.Material.SmoothPlastic },
			Stripe = { rgb(255, 120, 180), Enum.Material.SmoothPlastic },
			Lamp = { rgb(255, 250, 200), Enum.Material.Neon },
		},
	},
	{
		id = "NeonRoom",
		category = "Room",
		name = "Neon Arena",
		price = 50,
		theme = {
			Floor = { rgb(30, 30, 45), Enum.Material.DiamondPlate },
			Ceiling = { rgb(20, 20, 32), Enum.Material.SmoothPlastic },
			Wall = { rgb(28, 28, 44), Enum.Material.SmoothPlastic },
			BackWall = { rgb(18, 18, 30), Enum.Material.SmoothPlastic },
			Stripe = { rgb(0, 230, 255), Enum.Material.Neon },
			Lamp = { rgb(255, 80, 200), Enum.Material.Neon },
		},
	},

	-- Weapon finish: changes the look of every weapon you place (not what it does)
	{ id = "ClassicFinish", category = "Finish", name = "Standard", price = 0 },
	{ id = "FrostFinish", category = "Finish", name = "Frost", price = 35, color = rgb(170, 220, 255), material = Enum.Material.Glass, transparency = 0.1 },
	{ id = "GoldFinish", category = "Finish", name = "Gold", price = 60, color = rgb(255, 200, 60), material = Enum.Material.Metal, reflectance = 0.2 },

	-- Titles: shown above your head in the lobby
	{ id = "NoTitle", category = "Title", name = "No Title", price = 0 },
	{ id = "NoobSlayerTitle", category = "Title", name = "Noob Slayer", price = 10, color = rgb(255, 120, 120) },
	{ id = "RagdollMasterTitle", category = "Title", name = "Ragdoll Master", price = 20, color = rgb(120, 200, 255) },
	{ id = "ScientistTitle", category = "Title", name = "Mad Scientist", price = 20, new = true, color = rgb(120, 255, 90) },
	{ id = "PsychoTitle", category = "Title", name = "Certified Psycho", price = 30, color = rgb(200, 120, 255) },
	{ id = "LegendTitle", category = "Title", name = "LEGEND", price = 75, color = rgb(255, 205, 50) },

	-- Trails: follow you around the lobby
	{ id = "NoTrail", category = "Trail", name = "No Trail", price = 0 },
	{ id = "FireTrail", category = "Trail", name = "Fire", price = 25, colors = { rgb(255, 230, 80), rgb(255, 120, 30), rgb(200, 30, 20) } },
	{ id = "StormTrail", category = "Trail", name = "Storm", price = 30, new = true, colors = { rgb(255, 255, 255), rgb(255, 240, 120), rgb(120, 170, 255) } },
	{ id = "RainbowTrail", category = "Trail", name = "Rainbow", price = 45, colors = { rgb(255, 60, 60), rgb(255, 200, 40), rgb(80, 220, 90), rgb(60, 150, 255), rgb(190, 90, 255) } },
}

ShopItems.byId = {}
ShopItems.defaults = {} -- [category] = the free item everyone has
local unlocks = {} -- [weapon id] = the item that unlocks it for good
for _, item in ShopItems.list do
	ShopItems.byId[item.id] = item
	if item.price == 0 and not item.kind then
		ShopItems.defaults[item.category] = item.id
	end
	if item.kind == "unlock" or item.kind == "robux" then
		unlocks[item.weapon] = item
	end
end

-- The shop item that unlocks a weapon for good (with Noob Bucks, or kind "robux" for
-- Robux-only weapons), or nil if there isn't one
function ShopItems.unlockFor(weaponId)
	return unlocks[weaponId]
end

-- The deal of the day: one item 40% off, a different one every day (midnight UTC).
-- Server and players' screens work it out the same way from the date, so no message
-- is needed. Free items, trials and bundles are never the deal.
ShopItems.DEAL_DISCOUNT = 0.4
local DAY = 24 * 60 * 60
local dealable = {}
for _, item in ShopItems.list do
	if item.price >= 10 and item.kind ~= "rent" and item.kind ~= "bundle" then
		table.insert(dealable, item)
	end
end

-- `now` = os.time()
function ShopItems.dealOfTheDay(now)
	local day = math.floor(now / DAY)
	-- Jumps around the list, so the deal isn't always the next item along
	return dealable[(day * 37) % #dealable + 1]
end

-- Seconds until the next deal
function ShopItems.dealEndsIn(now)
	return DAY - now % DAY
end

-- What an item costs right now (the deal of the day is cheaper)
function ShopItems.priceFor(item, now)
	if ShopItems.dealOfTheDay(now) == item then
		return math.max(1, math.floor(item.price * (1 - ShopItems.DEAL_DISCOUNT)))
	end
	return item.price
end

-- What a bundle costs you: its price, cut down by how much of it you already own.
-- `owns(item)` says whether you own one of the things in it. Returns the price, and
-- what everything you don't own yet would cost bought one by one.
function ShopItems.bundlePrice(bundle, owns)
	local total, missing = 0, 0
	for _, id in bundle.contents do
		local item = ShopItems.byId[id]
		total += item.price
		if not owns(item) then
			missing += item.price
		end
	end
	if missing == 0 then
		return 0, 0
	end
	return math.max(1, math.ceil(bundle.price * missing / total)), missing
end

-- The look of `category` someone has equipped (`equipped` = { [category] = item id })
function ShopItems.equippedItem(equipped, category)
	local item = ShopItems.byId[equipped and equipped[category] or ""]
	if item and item.category == category then
		return item
	end
	return ShopItems.byId[ShopItems.defaults[category]]
end

-- The colors of each body part for a noob skin: { [body part name] = Color3 }
function ShopItems.noobColors(skin)
	local colors = skin.colors
	return {
		Head = colors.Head,
		Torso = colors.Torso,
		["Left Arm"] = colors.Arm,
		["Right Arm"] = colors.Arm,
		["Left Leg"] = colors.Leg,
		["Right Leg"] = colors.Leg,
	}
end

-- Dresses noob body parts (named like "Left Arm") in a skin
function ShopItems.applyNoobSkin(parts, skin)
	local colors = ShopItems.noobColors(skin)
	for _, part in parts do
		if colors[part.Name] then
			part.Color = colors[part.Name]
			part.Material = skin.material or Enum.Material.SmoothPlastic
			part.Reflectance = skin.reflectance or 0
			part.Transparency = skin.transparency or 0
		end
	end
end

-- A random blood color for a blood style
function ShopItems.bloodColor(style)
	local colors = style.colors
	return colors[math.random(#colors)]
end

-- Parts a weapon finish leaves alone: the invisible click box, glowing bits
-- (lenses, flames, stripes) and the bounce pad's springy top
local FINISH_SKIP = { Hitbox = true, Pad = true }

-- Gives a weapon model a finish (gold, frost...). The standard finish changes nothing.
function ShopItems.applyFinish(model, finish)
	if not finish or not finish.color then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and not FINISH_SKIP[part.Name] and part.Material ~= Enum.Material.Neon and part.Transparency < 1 then
			part.Color = finish.color
			part.Material = finish.material
			part.Reflectance = finish.reflectance or 0
			part.Transparency = finish.transparency or 0
		end
	end
end

-- Repaints a room's parts in a room theme. `originals` = the parts to paint and their
-- classic look ({ [part] = { color, material } }), used for anything the theme skips.
function ShopItems.applyRoomTheme(theme, originals)
	for part, original in originals do
		local kind = if part.Name == "LeftWall" or part.Name == "RightWall" then "Wall" else part.Name
		local look = theme.theme[kind] or original
		part.Color = look[1]
		part.Material = look[2]
	end
end

return ShopItems
