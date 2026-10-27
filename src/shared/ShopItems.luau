-- Everything you can buy with Noob Bucks. Shared by the server (which checks and
-- saves purchases) and players' screens (the shop window).
--
-- The rule: Noob Bucks buy LOOKS and EARLIER ACCESS, never extra power. Every weapon
-- here can still be unlocked for free with its achievement, and nothing does more
-- damage than what free players get.
--
-- Prices: a round winner earns 1 coin, and with up to 8 players that's a few coins
-- an hour for most people. So cheap items (10-15) take a few hours of winning,
-- the big flex items (60-80) are mostly for people who buy coins. 1 coin costs about
-- R$ 3.3-5 in the packs (see NoobBucks.luau).
local ShopItems = {}

ShopItems.CATEGORIES = {
	{ id = "Weapon", name = "Weapons", icon = "🔓" },
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

-- `kind` for Weapon items: "unlock" = unlocked for good (skip the achievement),
-- "rent" = can be used until the end of the next round you play
ShopItems.list = {
	-- Weapons: unlock early instead of earning the achievement first
	{ id = "UnlockMachineGun", category = "Weapon", kind = "unlock", weapon = "MachineGun", name = "Machine Gun", price = 10 },
	{ id = "UnlockGrenade", category = "Weapon", kind = "unlock", weapon = "Grenade", name = "Grenade", price = 10 },
	{ id = "UnlockSaw", category = "Weapon", kind = "unlock", weapon = "Saw", name = "Spinning Saw", price = 18 },
	{ id = "UnlockLaser", category = "Weapon", kind = "unlock", weapon = "Laser", name = "Laser Cannon", price = 20 },
	{ id = "UnlockBigTNT", category = "Weapon", kind = "unlock", weapon = "BigTNT", name = "Big TNT", price = 22 },
	{ id = "UnlockFlamethrower", category = "Weapon", kind = "unlock", weapon = "Flamethrower", name = "Flamethrower", price = 30 },
	-- A taste of the Robux-only Rocket Launcher. After about 8 rentals the Game Pass is the better deal.
	{ id = "RentRocketLauncher", category = "Weapon", kind = "rent", weapon = "RocketLauncher", name = "Rocket Launcher (1 round)", price = 3 },

	-- Noob skins: what the noob in your room looks like (everyone watching sees it too)
	{ id = "ClassicNoob", category = "NoobSkin", name = "Classic Noob", price = 0, colors = { Head = CLASSIC_YELLOW, Torso = CLASSIC_BLUE, Arm = CLASSIC_YELLOW, Leg = CLASSIC_GREEN } },
	{ id = "ZombieNoob", category = "NoobSkin", name = "Zombie Noob", price = 25, colors = { Head = rgb(110, 160, 85), Torso = rgb(115, 85, 60), Arm = rgb(110, 160, 85), Leg = rgb(45, 55, 95) } },
	{ id = "NinjaNoob", category = "NoobSkin", name = "Ninja Noob", price = 25, colors = { Head = rgb(30, 30, 36), Torso = rgb(30, 30, 36), Arm = rgb(30, 30, 36), Leg = rgb(30, 30, 36) } },
	{ id = "RobotNoob", category = "NoobSkin", name = "Robot Noob", price = 40, material = Enum.Material.Metal, colors = { Head = rgb(185, 190, 200), Torso = rgb(150, 155, 165), Arm = rgb(115, 120, 130), Leg = rgb(115, 120, 130) } },
	{ id = "GhostNoob", category = "NoobSkin", name = "Ghost Noob", price = 40, transparency = 0.4, colors = { Head = rgb(235, 240, 255), Torso = rgb(235, 240, 255), Arm = rgb(235, 240, 255), Leg = rgb(235, 240, 255) } },
	{ id = "GoldNoob", category = "NoobSkin", name = "Golden Noob", price = 80, material = Enum.Material.Metal, reflectance = 0.25, colors = { Head = rgb(255, 200, 60), Torso = rgb(255, 190, 40), Arm = rgb(255, 200, 60), Leg = rgb(240, 175, 35) } },

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
	{ id = "PsychoTitle", category = "Title", name = "Certified Psycho", price = 30, color = rgb(200, 120, 255) },
	{ id = "LegendTitle", category = "Title", name = "LEGEND", price = 75, color = rgb(255, 205, 50) },

	-- Trails: follow you around the lobby
	{ id = "NoTrail", category = "Trail", name = "No Trail", price = 0 },
	{ id = "FireTrail", category = "Trail", name = "Fire", price = 25, colors = { rgb(255, 230, 80), rgb(255, 120, 30), rgb(200, 30, 20) } },
	{ id = "RainbowTrail", category = "Trail", name = "Rainbow", price = 45, colors = { rgb(255, 60, 60), rgb(255, 200, 40), rgb(80, 220, 90), rgb(60, 150, 255), rgb(190, 90, 255) } },
}

ShopItems.byId = {}
ShopItems.defaults = {} -- [category] = the free item everyone has
for _, item in ShopItems.list do
	ShopItems.byId[item.id] = item
	if item.price == 0 then
		ShopItems.defaults[item.category] = item.id
	end
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
