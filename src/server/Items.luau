-- What each weapon/trap does once it's placed in a room.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemModels = require(Shared.ItemModels)
local ShopItems = require(Shared.ShopItems)
local Sounds = require(Shared.Sounds)

local Items = {}

-- How hard things push the noob is tuned to its gentler gravity (Config.NOOB_GRAVITY).
-- `damage` = hit points taken by each body part right at the center of the blast
local BLASTS = {
	-- `bounce` = how fast a mine throws the noob up into the air (the bounce pad does 55)
	Mine = { radius = 12, power = 65, damage = 30, bounce = 60 },
	Grenade = { radius = 13, power = 75, damage = 35 },
	BigTNT = { radius = 18, power = 95, damage = 45 },
	ClusterBomb = { radius = 11, power = 70, damage = 28 },
	-- Big enough to fill the whole room
	MiniNuke = { radius = 40, power = 140, damage = 55 },
}
local ROCKET_BLAST = { radius = 11, power = 80, damage = 35 }
local BOMBLET_BLAST = { radius = 7, power = 45, damage = 18 } -- each of the cluster bomb's little bombs
local MISSILE_BLAST = { radius = 6, power = 45, damage = 14 }
local ARROW_SPEED = 55 -- studs per second: slow enough to watch the arrow fly
local ARROW_TURN = math.rad(220) -- how fast (per second) an arrow can steer onto the noob in flight
local ROCKET_SPEED = 40
local BULLET_SPEED = 90
local PROJECTILE_RANGE = 150
-- How far ahead of a flying model's middle its tip is (so the tip is what hits)
local PROJECTILE_REACH = {
	Arrow = 1.55,
	Rocket = 0.95,
	Bullet = 0.35,
	Pellet = 0.2,
	Cannonball = 0.5,
	Harpoon = 1.15,
	Missile = 0.6,
	AcidBlob = 0.45,
}
local BOUNCE_SPEED = 55
local ARROW_DAMAGE = 13
local HEADSHOT_DAMAGE = 26
local BULLET_DAMAGE = 4
local BOUNCE_DAMAGE = 5
local SAW_DAMAGE = 6 -- per bite, before the body part and how hard it's pressed in
local SAW_TICK = 0.15 -- seconds between bites of the teeth
local SAW_SPIN = 12 -- radians per second
local SAW_RADIUS = 2.45 -- out to the tips of the teeth
-- How far in front of/behind the blade still counts as touching it. Generous, because
-- we watch from the side: if it looks like it's touching the blade, it is.
local SAW_THICKNESS = 2
local SAW_GRIP = 9 -- how strongly the teeth drag things round with them
local SAW_PUSH_OUT = 9 -- how fast something sunk into the blade gets pushed back out
-- How quickly the saw cuts each body part: thin limbs go fastest, the torso slowest
local SAW_CUT = {
	Head = 1,
	Torso = 0.75,
	["Left Arm"] = 1.35,
	["Right Arm"] = 1.35,
	["Left Leg"] = 1.2,
	["Right Leg"] = 1.2,
}
local FLAME_RANGE = 13
local FLAME_ANGLE = math.rad(25)
local FLAME_DAMAGE = 3
local FLAME_BURST = 0.6 -- seconds each blast of flame lasts
local BURN_TIME = 3
local LASER_DAMAGE = 25
local LASER_CHARGE = 0.5 -- seconds the lens glows brighter before each shot
local LASER_FADE = 0.35 -- seconds the beam takes to thin out and vanish
local LENS_COLOR = Color3.fromRGB(255, 40, 40)
local PAD_COLOR = Color3.fromRGB(80, 220, 90)
local FUSE_COLOR = Color3.fromRGB(255, 60, 60)
-- Seconds between the grenade's beeps: slow when the pin's just pulled, very fast at the end
local BEEP_SLOWEST = 0.45
local BEEP_FASTEST = 0.07
local FIRST_SHOT_DELAY = 0.4 -- seconds after PLAY before a weapon's first shot
local RETRY_DELAY = 0.05 -- how soon a weapon that waits for the noob to come close checks again

-- Spike strip
local SPIKE_DAMAGE = 9
local SPIKE_BOUNCE = 22 -- how fast it pushes the noob back off the spikes
local SPIKE_COOLDOWN = 0.35
-- Big fan
local FAN_RANGE = 24 -- how far the wind reaches
local FAN_WIDTH = 3.5 -- how far either side of the middle of the wind still gets blown
local FAN_PUSH = 110 -- how hard it blows (studs per second, every second)
local FAN_SPIN = 25 -- radians per second
-- Boxing glove
local GLOVE_REACH = 7
local GLOVE_WIDTH = 3
local GLOVE_SPEED = 70
local GLOVE_DAMAGE = 12
local GLOVE_OUT = 2.2 -- how far the glove shoots out
-- Bear trap
local TRAP_DAMAGE = 45
local TRAP_HOLD = 1.6 -- seconds it holds on
local TRAP_CLOSED = math.rad(80) -- how far the jaws swing up when it snaps
local TRAP_FLING = 50 -- how fast it throws the noob back up when it lets go
-- Shotgun
local PELLETS = 6
local PELLET_SPREAD = 0.12
local PELLET_SPEED = 95
local PELLET_DAMAGE = 5
local PELLET_PUSH = 9
-- Harpoon gun
local HARPOON_SPEED = 75
local HARPOON_DAMAGE = 26
local HARPOON_HEAD_DAMAGE = 40
local HARPOON_YANK = 45 -- how fast it drags the noob back toward the gun
-- Cannon
local CANNONBALL_SPEED = 60
local CANNONBALL_DAMAGE = 26
local CANNONBALL_HEAD_DAMAGE = 40
local CANNONBALL_PUSH = 55
-- Tesla coil
local TESLA_RANGE = 13
local TESLA_TARGETS = 3 -- body parts each zap can reach
local TESLA_DAMAGE = 8
local TESLA_JOLT = 18
local SHOCK_TIME = 0.6 -- seconds the noob flickers after a zap
-- Gravity flipper
local FLIP_TIME = 0.9 -- seconds the noob falls UP each flip
-- Freeze ray
local FREEZE_DAMAGE = 14
local FREEZE_TIME = 1.5
local ICE_COLOR = Color3.fromRGB(150, 225, 255)
-- Acid blaster
local ACID_SPEED = 50
local ACID_DAMAGE = 10
local ACID_TIME = 2.5 -- seconds the acid keeps eating away (it hurts like fire)
-- Storm cloud
local BOLT_DAMAGE = 24
local BOLT_BURN = 1
local BOLT_COLOR = Color3.fromRGB(255, 240, 120)
-- Wrecking ball
local SWING_ANGLE = math.rad(65) -- how far it swings either side
local SWING_PERIOD = 2.4 -- seconds for one swing there and back
local CHAIN_LENGTH = 10.1 -- from the hinge at the top to the middle of the ball
local BALL_RADIUS = 2.1 -- with the spikes
local BALL_DAMAGE = 14 -- plus up to 10 more the faster it's swinging
local BALL_COOLDOWN = 0.5
-- Ban hammer
local HAMMER_HALF_WIDTH = 2.6 -- how far either side of the hammer still gets squashed
local HAMMER_DAMAGE = 30 -- the body part it lands on (the rest under it take less)
local HAMMER_SPLASH = 12
local HAMMER_SLAM = 90 -- how fast it drives the noob into the floor
local HAMMER_DROP_TIME = 0.12
local HAMMER_HOLD = 0.15
local HAMMER_RAISE_TIME = 0.5
-- Railgun
local RAIL_CHARGE = 0.9 -- seconds it glows brighter before each shot
local RAIL_DAMAGE = 32 -- to EVERY body part the beam goes through
local RAIL_PUSH = 85
local RAIL_COLOR = Color3.fromRGB(60, 160, 255)
-- Minigun
local MINIGUN_SPIN_UP = 1 -- seconds before it starts firing
local MINIGUN_SPREAD = 0.1
local MINIGUN_SPEED = 100
-- Missile swarm
local MISSILE_SPEED = 40
local MISSILE_TURN = math.rad(300) -- how fast (per second) a missile can turn to chase the noob
-- Black hole
local PULL_RANGE = 18 -- how far away it starts pulling
-- The pull gets stronger the closer you get: PULL_BASE + PULL_CLOSE / (distance + 1)
-- (about 40 at the edge of its range, 100 at 5 studs, 265 right at the middle)
local PULL_BASE = 15
local PULL_CLOSE = 500
local SWIRL = 0.3 -- how much it swirls round as well (part of the pull)
local SWIRL_DRAG = 1.5 -- slows the swirling, so the noob spirals in instead of orbiting
local WEIGHTLESS = 0.85 -- how much of the noob's gravity is cancelled while it's caught
local GRIND_RADIUS = 3.2 -- arms and legs this close to the middle get torn at
local GRIND_DAMAGE = 5
local GRIND_TICK = 0.25
local SWALLOW_RADIUS = 1.2 -- once the middle of the torso or head gets this close, it's swallowed
local SWALLOW_TIME = 0.25 -- seconds for the noob to vanish into it
local SHRINK_TIME = 1.6 -- seconds for the black hole to shrink away afterwards
local ATOM_SCALE = 0.002 -- microscopic: how small it gets before it pops
-- Cluster bomb
local BOMBLETS = 5

local TESLA_COLOR = Color3.fromRGB(150, 200, 255)

local LIFE_GREEN = Color3.fromRGB(80, 220, 90)
local LIFE_ORANGE = Color3.fromRGB(255, 150, 30)
local LIFE_RED = Color3.fromRGB(230, 40, 40)
local LIFE_DARK_RED = Color3.fromRGB(110, 0, 0)

-- Sounds that keep going while a weapon works (looped)
local LOOP_SOUNDS = { Saw = "SawSpin", Fan = "FanWhir", Minigun = "MinigunLoop", BlackHole = "BlackHoleHum" }
-- Parts that spin round while a weapon works
local SPIN_PARTS = {
	Saw = { Blade = true, Tooth = true, Hub = true },
	Fan = { FanBlade = true },
	Minigun = { SpinBarrel = true },
	BlackHole = { Swirl = true },
}
-- Parts that slide out and back when a weapon goes off (the rest of it stays put)
local MOVING_PARTS = {
	BoxingGlove = { Glove = true, Thumb = true, Cuff = true, Rod = true },
	BanHammer = { Head = true, Grip = true, Handle = true },
}

-- The life bar's color: green when full, orange around the middle, red near the end,
-- and dark red once it's used up
local function lifeColor(fraction)
	if fraction <= 0 then
		return LIFE_DARK_RED
	elseif fraction <= 0.2 then
		return LIFE_RED
	elseif fraction <= 0.5 then
		return LIFE_RED:Lerp(LIFE_ORANGE, (fraction - 0.2) / 0.3)
	end
	return LIFE_ORANGE:Lerp(LIFE_GREEN, (fraction - 0.5) / 0.5)
end

local function setUses(item, uses)
	item.uses = uses
	local fraction = uses / item.weapon.uses
	item.lifeFill.Size = UDim2.fromScale(math.max(fraction, 0), 1)
	item.lifeFill.BackgroundColor3 = lifeColor(fraction)
	-- When it's empty, the whole bar shows dark red for a moment before it disappears
	item.lifeBack.BackgroundColor3 = if uses <= 0 then LIFE_DARK_RED else Color3.fromRGB(25, 25, 30)
	item.model:SetAttribute("Uses", uses) -- players' screens use this for the sell-back price
end

-- Counts down one use; breaks the item when it runs out
local function useUp(arena, item)
	setUses(item, item.uses - 1)
	if item.uses <= 0 then
		item.broken = true
		-- Short delay so you see the last hit (and the dark red bar) first
		task.delay(0.6, function()
			arena:removeItem(item)
		end)
	end
end

-- A glowing part for effects (lasers, lightning, sparks) that can't be touched or clicked
local function laserPart(parent, size, cframe, color, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Shape = shape or Enum.PartType.Block
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

-- A ball of light (or smoke) at `position` that swells to `size` and fades away
local function puff(parent, position, size, color, seconds)
	local ball = laserPart(parent, Vector3.one * 0.5, CFrame.new(position), color, Enum.PartType.Ball)
	TweenService:Create(ball, TweenInfo.new(seconds), { Size = Vector3.one * size, Transparency = 1 }):Play()
	Debris:AddItem(ball, seconds + 0.05)
	return ball
end

-- The point of a (box-shaped) body part closest to `point`
local function nearestPointOn(part, point)
	local inPart = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return part.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp(inPart.X, -half.X, half.X),
		math.clamp(inPart.Y, -half.Y, half.Y),
		math.clamp(inPart.Z, -half.Z, half.Z)
	))
end

-- Puts a weapon's moving parts (see MOVING_PARTS) where they rest, moved by `offset`
-- (a CFrame in the weapon's own directions)
local function poseMovers(item, offset)
	local pivot = item.model:GetPivot()
	for part, rest in item.movers do
		part.CFrame = pivot * offset * rest
	end
end

-- The ban hammer's head `drop` studs below where it rests, its handle stretched to reach it
local function poseHammer(item, drop)
	local pivot = item.model:GetPivot()
	for part, rest in item.movers do
		if part == item.handle then
			part.Size = item.handleSize + Vector3.new(drop, 0, 0) -- (a cylinder: its length is its X)
			part.CFrame = pivot * CFrame.new(0, -drop / 2, 0) * rest
		else
			part.CFrame = pivot * CFrame.new(0, -drop, 0) * rest
		end
	end
end

-- Where the wrecking ball hangs when it's not swinging
local function wreckingBallRest(item)
	return CFrame.new(item.position) * item.restRotation
end

-- A run ended: the weapon keeps whatever life it has left, ready for the next run
function Items.resetForNextRun(item)
	item.timer = nil
	item.nextBeep = nil
	item.fuseTime = nil
	item.burstLeft = 0
	item.grindTimer = nil
	item.blowTime = nil
	item.punchTime = nil
	item.slamTime = nil
	item.charging = nil
	item.spin = 0
	item.swingTime = nil
	item.loopWanted = item.weapon.id == "Saw" or item.weapon.id == "Fan"
	if item.flames then
		item.flames.Enabled = false
	end
	if item.wind then
		item.wind.Enabled = false
	end
	if item.body and item.bodyColor then
		item.body.Color = item.bodyColor
	end
	if item.lens then
		item.lens.Size = item.lensSize
		item.lens.Color = LENS_COLOR
		item.lensLight.Brightness = 0
	end
	if item.core then
		item.core.Size = item.coreSize
	end
	if item.handle then
		poseHammer(item, 0)
	elseif next(item.movers) and item.weapon.id ~= "BearTrap" then
		poseMovers(item, CFrame.new())
	end
	if item.weapon.id == "WreckingBall" then
		item.model:PivotTo(wreckingBallRest(item))
	end
end

-- What it sells back for: the price, times how much of its life is left
function Items.sellValue(item)
	return math.floor(item.weapon.price * item.uses / item.weapon.uses)
end

-- `placement` is a CFrame from Config.placementFor (where it goes, and which way round).
-- `finish` is the owner's weapon finish from ShopItems (just a look).
function Items.create(weapon, id, placement, parent, finish)
	local model = ItemModels.build(weapon.id)
	ShopItems.applyFinish(model, finish)
	model:SetAttribute("ItemId", id)
	local spinNames = SPIN_PARTS[weapon.id] or {}
	local moverNames = MOVING_PARTS[weapon.id] or {}
	local spinParts, moving = {}, {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("ItemId", id)
			if spinNames[part.Name] then
				table.insert(spinParts, part)
			end
			if moverNames[part.Name] or part:GetAttribute("Jaw") then
				table.insert(moving, part)
			end
		end
	end

	-- Life bar above it, showing how much is left before it's used up
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LifeBar"
	billboard.Size = UDim2.fromOffset(54, 9)
	-- Offset along the item's own "up", so a bounce pad on the ceiling or a wall
	-- shows its bar on the room side, not inside the wall. Things hanging from the
	-- ceiling show it underneath them.
	local barHeight = weapon.size.Y / 2 + 0.9
	billboard.StudsOffsetWorldSpace = Vector3.new(0, if weapon.onCeiling then -barHeight else barHeight, 0)
	billboard.AlwaysOnTop = true
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.Parent = billboard
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0.5, 0)
	backCorner.Parent = back
	local outline = Instance.new("UIStroke")
	outline.Thickness = 1.5
	outline.Color = Color3.new(0, 0, 0)
	outline.Parent = back
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill
	billboard.Parent = model.PrimaryPart

	model:PivotTo(placement)
	model.Parent = parent

	local body = model:FindFirstChild("Body")
	local item = {
		id = id,
		weapon = weapon,
		model = model,
		position = placement.Position,
		restRotation = placement.Rotation,
		lifeBack = back,
		lifeFill = fill,
		lastUsed = 0,
		body = body,
		bodyColor = body and body.Color,
		flames = model:FindFirstChild("Flames", true),
		wind = model:FindFirstChild("Wind", true),
		spinParts = spinParts,
		movers = {}, -- [part] = where it rests, relative to the weapon's middle
		spin = 0,
		loopWanted = weapon.id == "Saw" or weapon.id == "Fan",
	}
	for _, part in moving do
		item.movers[part] = placement:ToObjectSpace(part.CFrame)
	end
	if weapon.id == "BanHammer" then
		item.handle = model:FindFirstChild("Handle")
		item.handleSize = item.handle.Size
	end
	-- The saw whirs while it spins, the fan hums, and so on
	if LOOP_SOUNDS[weapon.id] then
		item.loopSound = Sounds.newLoop(LOOP_SOUNDS[weapon.id], model.PrimaryPart)
	end
	-- The laser cannon's lens glows up before each shot
	local lens = weapon.id == "Laser" and model:FindFirstChild("Lens")
	if lens then
		item.lens = lens
		item.lensSize = lens.Size
		item.lensLight = Instance.new("PointLight")
		item.lensLight.Color = Color3.fromRGB(255, 60, 60)
		item.lensLight.Brightness = 0
		item.lensLight.Parent = lens
	end
	-- ...and the railgun's core swells up while it charges
	local core = weapon.id == "Railgun" and model:FindFirstChild("Core")
	if core then
		item.core = core
		item.coreSize = core.Size
	end
	setUses(item, weapon.uses)
	return item
end

-- `placement` is a CFrame from Config.placementFor
function Items.move(item, placement)
	item.position = placement.Position
	-- Surface weapons turn to face the surface they're on; aiming weapons keep aiming
	local rotation = if item.weapon.anySurface then placement.Rotation else item.model:GetPivot().Rotation
	item.restRotation = if item.weapon.anySurface then placement.Rotation else item.restRotation
	item.model:PivotTo(CFrame.new(placement.Position) * rotation)
end

-- The cluster bomb throws its little bombs out all round it, and each one goes off
-- where it lands
local function throwBomblets(arena, item, center)
	local number = arena.noobNumber
	local room = arena.roomCFrame
	local half = Config.ROOM_SIZE / 2
	local middle = room:PointToObjectSpace(center)
	for index = 1, BOMBLETS do
		local angle = index / BOMBLETS * math.pi * 2 + math.random() * 0.8
		local spot = middle + Vector3.new(math.cos(angle), math.sin(angle), 0) * (4 + math.random() * 5)
		-- (worked out in the room's directions, and kept inside the room)
		spot = Vector3.new(math.clamp(spot.X, -half.X + 1, half.X - 1), math.clamp(spot.Y, 1, Config.ROOM_SIZE.Y - 1), 0)
		local target = room:PointToWorldSpace(spot)
		local bomb = laserPart(arena.room, Vector3.one * 0.6, CFrame.new(center), Color3.fromRGB(200, 40, 40), Enum.PartType.Ball)
		bomb.Material = Enum.Material.SmoothPlastic
		local flight = 0.3 + index * 0.08
		TweenService:Create(bomb, TweenInfo.new(flight, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target }):Play()
		task.delay(flight + 0.1, function()
			bomb:Destroy()
			-- Not if the noob was replaced (or the round ended) in the meantime
			if arena.noobNumber ~= number or arena.noob.dead or not arena.active then
				return
			end
			Sounds.playAt("Bomblet", target)
			arena:explode(target, BOMBLET_BLAST.radius, BOMBLET_BLAST.power, BOMBLET_BLAST.damage, item)
		end)
	end
end

-- The whole inside of the room lights up in `color`, then fades over `seconds`
-- (exactly room-sized, so it never spills into the rooms next door)
local function roomFlash(arena, color, seconds)
	local room = Config.ROOM_SIZE
	local glow = laserPart(arena.room, room - Vector3.new(0.2, 0.2, 0.2), arena.roomCFrame * CFrame.new(0, room.Y / 2, 0), color)
	TweenService:Create(glow, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(glow, seconds + 0.05)
end

-- The nuke's blast: a blinding white flash and a fireball that fill the whole room,
-- with explosions going off all over it
local function nukeFlash(arena, position)
	local room = Config.ROOM_SIZE
	local middle = arena.roomCFrame * CFrame.new(0, room.Y / 2, 0)
	roomFlash(arena, Color3.new(1, 1, 1), 0.8)
	roomFlash(arena, Color3.fromRGB(255, 140, 40), 2)
	puff(arena.room, middle.Position, room.Y - 0.5, Color3.fromRGB(255, 220, 110), 1.4)
	for _, spot in { { -0.35, 0.2 }, { 0.35, 0.2 }, { -0.2, 0.6 }, { 0.2, 0.6 }, { 0, 0.85 }, { -0.4, 0.85 }, { 0.4, 0.85 } } do
		task.delay(math.random() * 0.4, function()
			local explosion = Instance.new("Explosion")
			explosion.Position = (arena.roomCFrame * CFrame.new(spot[1] * room.X, spot[2] * room.Y, 0)).Position
			explosion.BlastRadius = 12
			explosion.BlastPressure = 0 -- just for show
			explosion.DestroyJointRadiusPercent = 0
			explosion.ExplosionType = Enum.ExplosionType.NoCraters
			explosion.Parent = arena.room
		end)
	end
	arena.recorder:event("nuke", { position = position })
end

-- Blows up a mine, grenade, TNT, cluster bomb or nuke
function Items.detonate(arena, item)
	if item.broken or arena.items[item.id] ~= item or arena.noob.dead then
		return -- (once the noob is destroyed, chain reactions stop and explosives are kept)
	end
	item.broken = true
	arena:removeItem(item)
	local blast = BLASTS[item.weapon.id]
	local id = item.weapon.id
	if id == "BigTNT" then
		Sounds.playAt("BigBoom", item.position) -- a deep rumble on top of the normal bang
	elseif id == "Mine" then
		Sounds.playAt("MineClick", item.position) -- the click of stepping on it...
		Sounds.playAt("MineBlast", item.position) -- ...and the dirt-throwing blast
	elseif id == "Grenade" or id == "ClusterBomb" then
		Sounds.playAt("GrenadeBlast", item.position)
		task.delay(0.08, Sounds.playAt, "Shrapnel", item.position) -- shrapnel flies just after the crack
	elseif id == "MiniNuke" then
		Sounds.playAt("NukeBlast", item.position)
		Sounds.playAt("BigBoom", item.position)
		nukeFlash(arena, item.position)
	end
	arena:explode(item.position, blast.radius, blast.power, blast.damage, item)

	if id == "ClusterBomb" then
		throwBomblets(arena, item, item.position)
	elseif id == "MiniNuke" then
		-- Infinite damage: nothing survives a nuke
		arena:destroyNoob(id, item)
		-- Everything that's left of the noob catches fire
		for _, part in arena.noob.parts do
			arena:ignite(part, BURN_TIME * 0.7)
		end
		-- ...and the room stays radioactive for the rest of the round
		arena:startRadiation()
	end

	-- A land mine launches the noob away from whatever it's stuck to: up off the floor,
	-- across the room off a wall, or slammed down off the ceiling
	local noob = arena.noob
	if blast.bounce and not noob.frozen and (noob.torso.Position - item.position).Magnitude <= blast.radius then
		local away = item.model:GetPivot().UpVector -- the mine's top faces into the room
		local sideways = 0
		if math.abs(arena.roomCFrame:VectorToObjectSpace(away).Y) > 0.5 then
			-- On the floor or ceiling: also nudge it across the room, away from the blast
			local across = arena.roomCFrame:VectorToObjectSpace(noob.torso.Position - item.position).X
			sideways = math.clamp(across * 3, -12, 12) + (math.random() - 0.5) * 6
		end
		noob:launchAway(away, blast.bounce, sideways)
		arena.ignoreImpactUntil = os.clock() + 0.15
	end
end

---------------------------------------------------------------------------
-- Things that fly: arrows, rockets, bullets, pellets, cannonballs, harpoons,
-- missiles and blobs of acid
---------------------------------------------------------------------------

-- Sends a model flying straight ahead (it moves in Items.stepProjectiles)
local function launch(arena, item, model, cframe, speed)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	model:PivotTo(cframe)
	model.Parent = arena.projectilesFolder
	table.insert(arena.projectiles, {
		model = model,
		direction = cframe.LookVector,
		speed = speed,
		kind = model.Name, -- "Arrow", "Rocket", "Bullet", "Pellet", "Cannonball", "Harpoon", "Missile" or "AcidBlob"
		item = item,
		travelled = 0,
	})
end

-- Where the noob will be by the time something flying at `speed` from `from` gets there,
-- so arrows aim ahead of a moving noob instead of at where it was
local function predictNoob(arena, from, speed)
	local torso = arena.noob.torso
	local velocity = torso.AssemblyLinearVelocity
	-- Lying still on the floor, gravity won't pull it any lower
	local falling = torso.Position.Y - arena.origin.Y > 5 or math.abs(velocity.Y) > 2
	local half = Config.ROOM_SIZE / 2
	local target = torso.Position
	for _ = 1, 3 do -- each guess makes the flight time (and so the next guess) more exact
		local t = (target - from).Magnitude / speed
		target = torso.Position + velocity * t
		if falling then
			target -= Vector3.new(0, 0.5 * Config.NOOB_GRAVITY * t * t, 0)
		end
		-- It can't leave the room (worked out in the room's own directions)
		local relative = arena.roomCFrame:PointToObjectSpace(target)
		target = arena.roomCFrame:PointToWorldSpace(Vector3.new(
			math.clamp(relative.X, -half.X + 1, half.X - 1),
			math.clamp(relative.Y, 1, Config.ROOM_SIZE.Y - 1),
			math.clamp(relative.Z, -half.Z + 1, half.Z - 1)
		))
	end
	return target
end

-- Turns an arrow in flight a little toward the body part it's heading for,
-- so a noob that moves after the shot still gets hit
local function steerArrow(arena, projectile, position, dt)
	local noob = arena.noob
	local best, bestDot = nil, 0.5 -- only parts roughly ahead (within 60 degrees)
	for _, part in noob.parts do
		local offset = part.Position - position
		if noob.attached[part] and offset.Magnitude > 0.1 then
			local dot = projectile.direction:Dot(offset.Unit)
			if dot > bestDot then
				best, bestDot = offset.Unit, dot
			end
		end
	end
	if not best then
		return -- nothing ahead (it already flew past): keep going straight
	end
	local angle = math.acos(math.clamp(bestDot, -1, 1))
	if angle > 0.001 then
		projectile.direction = projectile.direction:Lerp(best, math.min(1, ARROW_TURN * dt / angle)).Unit
	end
end

-- Turns a missile toward the noob's torso, wherever it is (it really chases it)
local function steerMissile(arena, projectile, position, dt)
	local noob = arena.noob
	local offset = noob.torso.Position - position
	if noob.dead or offset.Magnitude < 0.1 then
		return
	end
	local angle = math.acos(math.clamp(projectile.direction:Dot(offset.Unit), -1, 1))
	-- (straight behind it, there's no "which way" to turn, so it keeps going)
	if angle > 0.001 and angle < 3.1 then
		projectile.direction = projectile.direction:Lerp(offset.Unit, math.min(1, MISSILE_TURN * dt / angle)).Unit
	end
end

-- An arrow reached the noob: knock that body part back and leave the arrow stuck in it
local function arrowHit(arena, projectile, result)
	local part, direction = result.Instance, projectile.direction
	Sounds.playAt("ArrowHit", result.Position)
	part.AssemblyLinearVelocity += direction * 30
	arena.noob:push(direction * 8)
	local offset = arena.noob:stickArrow(part, result.Position, direction)
	if offset then
		arena.recorder:event("arrow", { part = table.find(arena.noob.parts, part), offset = offset })
	end
	arena.ignoreImpactUntil = os.clock() + 0.1
	local amount = if part.Name == "Head" then HEADSHOT_DAMAGE else ARROW_DAMAGE
	arena:hit("Crossbow", projectile.item, { { part = part, amount = amount, position = result.Position } })
end

-- A machine gun or minigun bullet
local function bulletHit(arena, projectile, result)
	local part = result.Instance
	part.AssemblyLinearVelocity += projectile.direction * 12
	arena.ignoreImpactUntil = os.clock() + 0.05
	arena:hit(projectile.item.weapon.id, projectile.item, { { part = part, amount = BULLET_DAMAGE, position = result.Position } })
end

-- One shotgun pellet: a shell is 6 of these, so a close shot knocks the noob right back
local function pelletHit(arena, projectile, result)
	local part = result.Instance
	part.AssemblyLinearVelocity += projectile.direction * PELLET_PUSH
	arena.noob:push(projectile.direction * 3)
	arena.ignoreImpactUntil = os.clock() + 0.05
	local amount = if part.Name == "Head" then PELLET_DAMAGE * 1.6 else PELLET_DAMAGE
	arena:hit("Shotgun", projectile.item, { { part = part, amount = amount, position = result.Position } })
end

-- A harpoon spears the noob and the rope yanks it back toward the gun
local function harpoonHit(arena, projectile, result)
	local part, direction = result.Instance, projectile.direction
	Sounds.playAt("ArrowHit", result.Position)
	arena.noob:push(-direction * HARPOON_YANK)
	part.AssemblyLinearVelocity -= direction * 15
	arena.noob:spin(6)
	-- The rope, pulled tight for a moment
	local gun = projectile.item.model
	if gun.Parent then
		local from = gun:GetPivot().Position
		local length = (result.Position - from).Magnitude
		local rope = laserPart(arena.room, Vector3.new(0.1, 0.1, length), CFrame.lookAt(from:Lerp(result.Position, 0.5), result.Position), Color3.fromRGB(205, 180, 130))
		rope.Material = Enum.Material.Fabric
		Debris:AddItem(rope, 0.35)
	end
	arena.ignoreImpactUntil = os.clock() + 0.15
	local amount = if part.Name == "Head" then HARPOON_HEAD_DAMAGE else HARPOON_DAMAGE
	arena:hit("Harpoon", projectile.item, { { part = part, amount = amount, position = result.Position } })
end

-- A cannonball sends the whole noob flying (into the walls, for big crashes)
local function cannonballHit(arena, projectile, result)
	local part, direction = result.Instance, projectile.direction
	Sounds.playAt("BodyImpact", result.Position)
	Sounds.playAt("Punch", result.Position)
	arena.noob:push(direction * CANNONBALL_PUSH + arena.roomCFrame.UpVector * 15)
	arena.noob:spin(10)
	arena.ignoreImpactUntil = os.clock() + 0.15
	local amount = if part.Name == "Head" then CANNONBALL_HEAD_DAMAGE else CANNONBALL_DAMAGE
	arena:hit("Cannon", projectile.item, { { part = part, amount = amount, position = result.Position } })
end

-- Acid splashes the body part and keeps eating away at it (like fire, but green)
local function acidHit(arena, projectile, result)
	local part = result.Instance
	Sounds.playAt("AcidSizzle", result.Position)
	part.AssemblyLinearVelocity += projectile.direction * 8
	arena:ignite(part, ACID_TIME, true)
	arena:hit("AcidBlaster", projectile.item, { { part = part, amount = ACID_DAMAGE, position = result.Position } })
end

-- Missed: an arrow or harpoon sticks in the wall for a moment, point first
local function stickInWall(projectile, result, pivot)
	if result then
		projectile.model:PivotTo(pivot.Rotation + (result.Position - projectile.direction * (PROJECTILE_REACH[projectile.kind] - 0.65)))
		Sounds.playAt("ArrowWall", result.Position)
	end
	Debris:AddItem(projectile.model, 2)
end

-- What happens when each kind of projectile hits something (`result` = the raycast hit,
-- or nil if it flew too far), `hitNoob` = it hit a body part
local LANDINGS = {
	Rocket = function(arena, projectile, result)
		projectile.model:Destroy()
		if result then
			local blast = ROCKET_BLAST
			arena:explode(result.Position, blast.radius, blast.power, blast.damage, projectile.item)
		end
	end,
	Missile = function(arena, projectile, result)
		projectile.model:Destroy()
		if result then
			local blast = MISSILE_BLAST
			Sounds.playAt("MissileBlast", result.Position)
			arena:explode(result.Position, blast.radius, blast.power, blast.damage, projectile.item)
		end
	end,
	Bullet = function(arena, projectile, result, hitNoob)
		projectile.model:Destroy()
		if hitNoob then
			bulletHit(arena, projectile, result)
		end
	end,
	Pellet = function(arena, projectile, result, hitNoob)
		projectile.model:Destroy()
		if hitNoob then
			pelletHit(arena, projectile, result)
		end
	end,
	Cannonball = function(arena, projectile, result, hitNoob)
		projectile.model:Destroy()
		if hitNoob then
			cannonballHit(arena, projectile, result)
		elseif result then
			Sounds.playAt("Thud", result.Position)
		end
	end,
	AcidBlob = function(arena, projectile, result, hitNoob)
		projectile.model:Destroy()
		if hitNoob then
			acidHit(arena, projectile, result)
		elseif result then
			Sounds.playAt("AcidSizzle", result.Position, 0.5)
		end
	end,
	Arrow = function(arena, projectile, result, hitNoob, pivot)
		if hitNoob then
			projectile.model:Destroy()
			arrowHit(arena, projectile, result)
		else
			stickInWall(projectile, result, pivot)
		end
	end,
	Harpoon = function(arena, projectile, result, hitNoob, pivot)
		if hitNoob then
			projectile.model:Destroy()
			harpoonHit(arena, projectile, result)
		else
			stickInWall(projectile, result, pivot)
		end
	end,
}

-- Moves everything in flight along. Rockets and missiles blow up on the first thing
-- they hit; arrows and harpoons stick into the noob, or into the wall for a moment
-- if they miss.
function Items.stepProjectiles(arena, dt)
	if #arena.projectiles == 0 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { arena.itemsFolder, arena.projectilesFolder }

	for index = #arena.projectiles, 1, -1 do
		local projectile = arena.projectiles[index]
		local pivot = projectile.model:GetPivot()
		if projectile.kind == "Arrow" then
			steerArrow(arena, projectile, pivot.Position, dt)
		elseif projectile.kind == "Missile" then
			steerMissile(arena, projectile, pivot.Position, dt)
		end
		local step = projectile.direction * projectile.speed * dt
		local reach = projectile.direction * PROJECTILE_REACH[projectile.kind]
		-- Check the whole length from the tail to where the tip will be, so a body part
		-- that swings into the middle of the arrow still counts as a hit (a ray that
		-- starts inside a part can't see it)
		local result = Workspace:Raycast(pivot.Position - reach, step + reach * 2, params)
		projectile.travelled += step.Magnitude
		if not result and projectile.travelled <= PROJECTILE_RANGE then
			local position = pivot.Position + step
			projectile.model:PivotTo(CFrame.lookAt(position, position + projectile.direction))
		else
			table.remove(arena.projectiles, index)
			local hitNoob = result ~= nil and table.find(arena.noob.parts, result.Instance) ~= nil
			LANDINGS[projectile.kind](arena, projectile, result, hitNoob, pivot)
		end
	end
end

---------------------------------------------------------------------------
-- Weapons that fire by themselves
---------------------------------------------------------------------------

local function fireCrossbow(arena, item)
	-- Aim where the noob is going to be, not where it is now
	local start = (item.model:GetPivot() * CFrame.new(0, 0.33, -0.3)).Position
	local aim = CFrame.lookAt(start, predictNoob(arena, start, ARROW_SPEED))
	item.model:PivotTo(CFrame.lookAt(item.position, item.position + aim.LookVector))
	launch(arena, item, ItemModels.buildArrow(), aim, ARROW_SPEED)
	Sounds.playAt("ArrowShot", item.position)
	useUp(arena, item)
end

local function fireRocket(arena, item)
	local launcher = item.model:GetPivot()
	launch(arena, item, ItemModels.buildRocket(), launcher * CFrame.new(0, 0, -1.8), ROCKET_SPEED)
	Sounds.playAt("RocketLaunch", item.position)
	useUp(arena, item)
end

local function fireMachineGun(arena, item)
	local gun = item.model:GetPivot()
	Sounds.playAt("GunShot", item.position)
	-- A little spread, like a real machine gun
	local spread = CFrame.Angles((math.random() - 0.5) * 0.08, (math.random() - 0.5) * 0.08, 0)
	launch(arena, item, ItemModels.buildBullet(), gun * CFrame.new(0, 0.1, -2.2) * spread, BULLET_SPEED)
	useUp(arena, item)
end

local function fireFlamethrower(arena, item)
	item.burstLeft = FLAME_BURST
	item.nextFlameTick = 0
	local nozzle = item.model:GetPivot() * CFrame.new(0, 0.2, -1.8)
	arena.recorder:event("flame", { position = nozzle.Position, direction = nozzle.LookVector })
	Sounds.playAt("FlameBurst", item.position)
	useUp(arena, item)
end

-- Body parts inside the flamethrower's cone catch fire
local function burnCone(arena, item)
	local nozzle = item.model:GetPivot() * CFrame.new(0, 0.2, -1.8)
	local hits = {}
	for _, part in arena.noob.parts do
		local offset = part.Position - nozzle.Position
		local distance = offset.Magnitude
		if
			arena.noob.attached[part]
			and distance <= FLAME_RANGE
			and distance > 0
			and math.acos(math.clamp(offset.Unit:Dot(nozzle.LookVector), -1, 1)) <= FLAME_ANGLE
		then
			arena:ignite(part, BURN_TIME)
			table.insert(hits, { part = part, amount = FLAME_DAMAGE })
		end
	end
	if #hits > 0 then
		arena:hit("Flamethrower", item, hits)
	end
end

-- The shot: a white-hot core inside a thick glow (red, unless `color` says otherwise)
-- that flashes on and then thins out to nothing, a flash at the muzzle, and (if it
-- hit) a burst of light and sparks flying off the noob. `thickness` makes it fatter.
local function laserEffects(arena, from, to, hit, color, thickness)
	color = color or Color3.fromRGB(255, 30, 30)
	thickness = thickness or 1
	local length = (to - from).Magnitude
	local cframe = CFrame.lookAt(from:Lerp(to, 0.5), to)
	local fade = TweenInfo.new(LASER_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local glow = laserPart(arena.room, Vector3.new(0.8, 0.8, length) * Vector3.new(thickness, thickness, 1), cframe, color)
	glow.Transparency = 0.45
	local core = laserPart(arena.room, Vector3.new(0.25, 0.25, length) * Vector3.new(thickness, thickness, 1), cframe, color:Lerp(Color3.new(1, 1, 1), 0.85))
	for _, part in { glow, core } do
		TweenService:Create(part, fade, { Size = Vector3.new(0, 0, length), Transparency = 1 }):Play()
		Debris:AddItem(part, LASER_FADE + 0.05)
	end

	local flashColor = color:Lerp(Color3.new(1, 1, 1), 0.4)
	local flashes = { { from, 1.6 * thickness } }
	if hit then
		table.insert(flashes, { to, 3.5 * thickness })
	end
	for _, spot in flashes do
		local flash = laserPart(arena.room, Vector3.one * 0.5, CFrame.new(spot[1]), flashColor, Enum.PartType.Ball)
		TweenService:Create(flash, TweenInfo.new(LASER_FADE), { Size = Vector3.one * spot[2], Transparency = 1 }):Play()
		Debris:AddItem(flash, LASER_FADE + 0.05)
	end

	if hit then
		local space = arena.roomCFrame.Rotation
		local back = space:VectorToObjectSpace((from - to).Unit)
		local sparkColor = color:Lerp(Color3.fromRGB(255, 220, 140), 0.6)
		for _ = 1, 8 do
			-- Mostly bouncing back toward the cannon, spread out, and kept flat to the camera
			-- (worked out in the room's directions, then turned back to the world's)
			local spray = (back + Vector3.new(math.random() - 0.5, math.random() - 0.3, 0) * 1.6) * Vector3.new(1, 1, 0.2)
			spray = space:VectorToWorldSpace(spray)
			local spark = laserPart(arena.room, Vector3.new(0.12, 0.12, 0.5), CFrame.lookAt(to, to + spray), sparkColor)
			local seconds = 0.25 + math.random() * 0.2
			TweenService:Create(spark, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.lookAt(to + spray.Unit * (2 + math.random() * 2), to + spray * 2),
				Size = Vector3.new(0.05, 0.05, 0.2),
				Transparency = 1,
			}):Play()
			Debris:AddItem(spark, seconds + 0.05)
		end
	end
end

-- Before each shot the lens swells up and glows brighter and brighter, so you can
-- see the shot coming
local function chargeLaser(item)
	local progress = if item.timer then math.clamp(1 - item.timer / LASER_CHARGE, 0, 1) else 0
	local grow = 1 + progress * 1.3
	item.lens.Size = Vector3.new(item.lensSize.X, item.lensSize.Y * grow, item.lensSize.Z * grow)
	item.lens.Color = LENS_COLOR:Lerp(Color3.fromRGB(255, 230, 230), progress)
	item.lensLight.Brightness = progress * 8
	item.lensLight.Range = 2 + progress * 8
end

-- A beam fired straight ahead from `muzzle` (a CFrame): the raycast hit on the first body
-- part it reaches (or nil), and where the beam ends
local function beamAt(arena, muzzle)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = arena.noob.parts
	local result = Workspace:Raycast(muzzle.Position, muzzle.LookVector * 100, params)
	local target = if result then result.Position else muzzle.Position + muzzle.LookVector * 60
	return result, target
end

local function fireLaser(arena, item)
	local muzzle = item.model:GetPivot() * CFrame.new(0, 0, -1.9)
	local result, target = beamAt(arena, muzzle)

	laserEffects(arena, muzzle.Position, target, result ~= nil)
	arena.recorder:event("laser", { position = muzzle.Position, target = target })
	Sounds.playAt("LaserShot", item.position)

	if result then
		local part = result.Instance
		part.AssemblyLinearVelocity += muzzle.LookVector * 12
		arena.ignoreImpactUntil = os.clock() + 0.05
		arena:ignite(part, BURN_TIME * 0.6)
		arena:hit("Laser", item, { { part = part, amount = LASER_DAMAGE, position = result.Position } })
	end
	useUp(arena, item)
end

-- A jagged bolt of lightning from one point to another that flickers out
local function boltEffect(arena, from, to, color, thickness)
	local space = arena.roomCFrame.Rotation
	local points = { from }
	local segments = 6
	for index = 1, segments - 1 do
		-- Zig-zagging, kept flat to the camera
		local jitter = space:VectorToWorldSpace(Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 1.6)
		table.insert(points, from:Lerp(to, index / segments) + jitter)
	end
	table.insert(points, to)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local length = (b - a).Magnitude
		local segment = laserPart(arena.room, Vector3.new(thickness, thickness, length), CFrame.lookAt(a:Lerp(b, 0.5), b), color)
		TweenService:Create(segment, TweenInfo.new(0.3), { Size = Vector3.new(0.05, 0.05, length), Transparency = 1 }):Play()
		Debris:AddItem(segment, 0.35)
	end
	puff(arena.room, to, 3, Color3.new(1, 1, 1), 0.3)
end

local function fireShotgun(arena, item)
	local gun = item.model:GetPivot() * CFrame.new(0, 0.15, -2.1)
	for _ = 1, PELLETS do
		local spread = CFrame.Angles((math.random() - 0.5) * 2 * PELLET_SPREAD, (math.random() - 0.5) * 2 * PELLET_SPREAD, 0)
		launch(arena, item, ItemModels.buildProjectile("Pellet"), gun * spread, PELLET_SPEED)
	end
	puff(arena.room, gun.Position, 1.6, Color3.fromRGB(255, 200, 120), 0.15)
	Sounds.playAt("ShotgunBlast", item.position)
	useUp(arena, item)
end

local function fireHarpoon(arena, item)
	-- Aims ahead of a moving noob, like the crossbow
	local start = (item.model:GetPivot() * CFrame.new(0, 0.05, -1.9)).Position
	local aim = CFrame.lookAt(start, predictNoob(arena, start, HARPOON_SPEED))
	item.model:PivotTo(CFrame.lookAt(item.position, item.position + aim.LookVector))
	launch(arena, item, ItemModels.buildProjectile("Harpoon"), aim, HARPOON_SPEED)
	Sounds.playAt("HarpoonShot", item.position)
	useUp(arena, item)
end

local function fireCannon(arena, item)
	local start = (item.model:GetPivot() * CFrame.new(0, 0.15, -1.9)).Position
	local aim = CFrame.lookAt(start, predictNoob(arena, start, CANNONBALL_SPEED))
	item.model:PivotTo(CFrame.lookAt(item.position, item.position + aim.LookVector))
	launch(arena, item, ItemModels.buildProjectile("Cannonball"), aim, CANNONBALL_SPEED)
	Sounds.playAt("CannonFire", item.position)
	puff(arena.room, start, 3, Color3.fromRGB(200, 200, 205), 0.6).Material = Enum.Material.SmoothPlastic -- smoke
	useUp(arena, item)
end

-- Body parts close enough to `item`, inside the strip `reach` long and `width` either
-- side, straight out of its top. Returns the closest one, or nil.
local function closestInFront(arena, item, reach, width)
	local pivot = item.model:GetPivot()
	local up = pivot.UpVector
	local space = arena.roomCFrame.Rotation
	local closest, closestAlong = nil, math.huge
	for _, part in arena.noob.parts do
		if arena.noob.attached[part] then
			local offset = part.Position - pivot.Position
			local along = offset:Dot(up)
			-- How far off to the side, ignoring how near or far from the camera
			local side = space:VectorToObjectSpace(offset - up * along) * Vector3.new(1, 1, 0)
			if along > 0 and along <= reach and side.Magnitude <= width and along < closestAlong then
				closest, closestAlong = part, along
			end
		end
	end
	return closest
end

-- Only punches once the noob is right in front of it
local function fireGlove(arena, item)
	local target = closestInFront(arena, item, GLOVE_REACH, GLOVE_WIDTH)
	if not target then
		return false
	end
	item.punchTime = 0
	Sounds.playAt("GloveRelease", item.position)
	Sounds.playAt("GlovePunch", target.Position)
	arena.noob:launchAway(item.model:GetPivot().UpVector, GLOVE_SPEED, 0)
	arena.ignoreImpactUntil = os.clock() + 0.15
	arena:hit("BoxingGlove", item, { { part = target, amount = GLOVE_DAMAGE } })
	useUp(arena, item)
	return true
end

-- Zaps up to 3 of the nearest body parts, once the noob comes in range
local function fireTesla(arena, item)
	local top = (item.model:GetPivot() * CFrame.new(0, 1.9, 0)).Position
	local targets = {}
	for _, part in arena.noob.parts do
		if arena.noob.attached[part] and (part.Position - top).Magnitude <= TESLA_RANGE then
			table.insert(targets, part)
		end
	end
	if #targets == 0 then
		return false
	end
	table.sort(targets, function(a, b)
		return (a.Position - top).Magnitude < (b.Position - top).Magnitude
	end)
	local space = arena.roomCFrame.Rotation
	local hits = {}
	for index = 1, math.min(TESLA_TARGETS, #targets) do
		local part = targets[index]
		boltEffect(arena, top, part.Position, TESLA_COLOR, 0.22)
		arena.recorder:event("laser", { position = top, target = part.Position, color = TESLA_COLOR, width = 0.35 })
		-- The jolt makes it jerk about
		part.AssemblyLinearVelocity += space:VectorToWorldSpace(Vector3.new(math.random() - 0.5, math.random(), 0)) * TESLA_JOLT
		table.insert(hits, { part = part, amount = TESLA_DAMAGE })
	end
	-- The noob flickers electric blue and sparks fly off it
	local zapped, numbers = {}, {}
	for _, hit in hits do
		table.insert(zapped, hit.part)
		table.insert(numbers, table.find(arena.noob.parts, hit.part))
	end
	arena.noob:shock(zapped, SHOCK_TIME)
	arena.recorder:event("shock", { parts = numbers, seconds = SHOCK_TIME })
	Sounds.playAt("ShockBuzz", zapped[1].Position)
	arena.ignoreImpactUntil = os.clock() + 0.1
	Sounds.playAt("TeslaZap", item.position)
	arena:hit("TeslaCoil", item, hits)
	useUp(arena, item)
	return true
end

-- The noob falls UP for a moment, then gravity comes back and it falls down again
local function fireGravityFlip(arena, item)
	local noob, number = arena.noob, arena.noobNumber
	noob:setGravity(-1)
	arena.flippedUntil = os.clock() + FLIP_TIME -- (for the "Upside Down" achievement)
	task.delay(FLIP_TIME, function()
		if arena.noobNumber == number then -- (a fresh noob already has normal gravity)
			noob:setGravity(1)
		end
	end)
	arena.armed = true -- the crashes it causes count
	puff(arena.room, item.position, 5, Color3.fromRGB(170, 70, 255), 0.4)
	Sounds.playAt("GravityFlip", item.position)
	useUp(arena, item)
end

local function fireFreeze(arena, item)
	local muzzle = item.model:GetPivot() * CFrame.new(0, 0, -1.9)
	local result, target = beamAt(arena, muzzle)
	laserEffects(arena, muzzle.Position, target, result ~= nil, ICE_COLOR)
	arena.recorder:event("laser", { position = muzzle.Position, target = target, color = ICE_COLOR })
	Sounds.playAt("FreezeShot", item.position)
	if result then
		Sounds.playAt("IceCrack", result.Position)
		arena:hit("FreezeRay", item, { { part = result.Instance, amount = FREEZE_DAMAGE, position = result.Position } })
		arena:freezeNoob(FREEZE_TIME)
		-- Frozen in its tracks: it slows right down, then drops like a statue
		for _, part in arena.noob.parts do
			part.AssemblyLinearVelocity *= 0.3
			part.AssemblyAngularVelocity *= 0.3
		end
		arena.ignoreImpactUntil = os.clock() + 0.1
	end
	useUp(arena, item)
end

local function fireAcid(arena, item)
	local start = (item.model:GetPivot() * CFrame.new(0, -0.05, -1.9)).Position
	local aim = CFrame.lookAt(start, predictNoob(arena, start, ACID_SPEED))
	launch(arena, item, ItemModels.buildProjectile("AcidBlob"), aim, ACID_SPEED)
	Sounds.playAt("AcidSpray", item.position)
	useUp(arena, item)
end

-- Lightning strikes whichever body part is closest to the cloud
local function fireStorm(arena, item)
	local cloud = (item.model:GetPivot() * CFrame.new(0, -1.4, 0)).Position
	local target, best = nil, math.huge
	for _, part in arena.noob.parts do
		local distance = (part.Position - cloud).Magnitude
		if arena.noob.attached[part] and distance < best then
			target, best = part, distance
		end
	end
	if not target then
		return false
	end
	boltEffect(arena, cloud, target.Position, BOLT_COLOR, 0.35)
	arena.recorder:event("laser", { position = cloud, target = target.Position, color = BOLT_COLOR, width = 0.5 })
	Sounds.playAt("Thunder", item.position)
	Sounds.playAt("LightningCrack", target.Position)
	target.AssemblyLinearVelocity += (target.Position - cloud).Unit * 30
	arena.noob:spin(6)
	arena.ignoreImpactUntil = os.clock() + 0.1
	arena:ignite(target, BOLT_BURN)
	arena:hit("StormCloud", item, { { part = target, amount = BOLT_DAMAGE, position = target.Position } })
	useUp(arena, item)
	return true
end

-- Slams down once the noob is underneath the hammer: the body part it lands on takes
-- the most, and everything under it gets driven into the floor
local function fireHammer(arena, item)
	local room = arena.roomCFrame
	local head = room:PointToObjectSpace((item.model:GetPivot() * CFrame.new(0, -1.55, 0)).Position)
	local under, top, topY = {}, nil, -math.huge
	for _, part in arena.noob.parts do
		local spot = room:PointToObjectSpace(part.Position)
		if arena.noob.attached[part] and math.abs(spot.X - head.X) <= HAMMER_HALF_WIDTH and spot.Y < head.Y then
			table.insert(under, part)
			if spot.Y > topY then
				top, topY = part, spot.Y
			end
		end
	end
	if not top then
		return false
	end
	item.slamTime = 0
	item.slamDrop = math.max(0, head.Y - 0.9) -- all the way down to the floor
	local down = -room.UpVector
	arena.noob:push(down * HAMMER_SLAM * 0.5)
	local hits = {}
	for _, part in under do
		part.AssemblyLinearVelocity += down * HAMMER_SLAM * 0.5
		table.insert(hits, { part = part, amount = if part == top then HAMMER_DAMAGE else HAMMER_SPLASH })
	end
	Sounds.playAt("SwingWhoosh", item.position)
	task.delay(HAMMER_DROP_TIME, Sounds.playAt, "HammerSlam", top.Position)
	arena.ignoreImpactUntil = os.clock() + 0.1
	arena:hit("BanHammer", item, hits)
	useUp(arena, item)
	return true
end

-- Starts charging up; it fires when the charge is full (see chargeRailgun)
local function startRailgun(arena, item)
	item.charging = RAIL_CHARGE
	Sounds.playAt("RailgunCharge", item.position)
end

-- The railgun's beam goes straight through the noob: every body part in its way is hit
local function fireRailgun(arena, item)
	local muzzle = item.model:GetPivot() * CFrame.new(0, 0, -2.3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local remaining = {}
	for _, part in arena.noob.parts do
		if arena.noob.attached[part] then
			table.insert(remaining, part)
		end
	end
	local hits = {}
	while #remaining > 0 do
		params.FilterDescendantsInstances = remaining
		local result = Workspace:Raycast(muzzle.Position, muzzle.LookVector * 100, params)
		if not result then
			break
		end
		table.insert(hits, { part = result.Instance, amount = RAIL_DAMAGE, position = result.Position })
		table.remove(remaining, table.find(remaining, result.Instance))
	end
	-- The beam carries on until it hits the wall
	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Exclude
	wallParams.FilterDescendantsInstances = { arena.itemsFolder, arena.projectilesFolder, arena.noob.model }
	local wall = Workspace:Raycast(muzzle.Position, muzzle.LookVector * 100, wallParams)
	local target = if wall then wall.Position else muzzle.Position + muzzle.LookVector * 60

	laserEffects(arena, muzzle.Position, target, #hits > 0, RAIL_COLOR, 1.4)
	arena.recorder:event("laser", { position = muzzle.Position, target = target, color = RAIL_COLOR, width = 1 })
	Sounds.playAt("RailgunFire", item.position)
	if #hits > 0 then
		arena.noob:push(muzzle.LookVector * RAIL_PUSH)
		arena.noob:spin(8)
		arena.ignoreImpactUntil = os.clock() + 0.15
		arena:hit("Railgun", item, hits)
	end
	item.core.Size = item.coreSize
	useUp(arena, item)
end

-- Only fires once the barrels are spinning at full speed (see spinMinigun)
local function fireMinigun(arena, item)
	if item.spin < 1 then
		return false
	end
	local gun = item.model:GetPivot()
	local spread = CFrame.Angles((math.random() - 0.5) * MINIGUN_SPREAD, (math.random() - 0.5) * MINIGUN_SPREAD, 0)
	launch(arena, item, ItemModels.buildBullet(), gun * CFrame.new(0, 0, -2.3) * spread, MINIGUN_SPEED)
	useUp(arena, item)
	return true
end

-- Two missiles at a time, one curving up and one curving down before they home in
local function fireMissiles(arena, item)
	local pod = item.model:GetPivot()
	item.volley = (item.volley or 0) + 1
	local row = if item.volley % 2 == 0 then 0.4 else -0.4
	for _, x in { -0.4, 0.4 } do
		local curve = CFrame.Angles(if x < 0 then 0.35 else -0.35, 0, 0)
		launch(arena, item, ItemModels.buildProjectile("Missile"), pod * CFrame.new(x, row, -1.4) * curve, MISSILE_SPEED)
	end
	Sounds.playAt("MissileLaunch", item.position)
	useUp(arena, item)
end

-- Each weapon's shot. Weapons that only go off when the noob is close enough return
-- false when it isn't, so they check again straight away instead of waiting.
local FIRE = {
	Crossbow = fireCrossbow,
	RocketLauncher = fireRocket,
	MachineGun = fireMachineGun,
	Flamethrower = fireFlamethrower,
	Laser = fireLaser,
	Shotgun = fireShotgun,
	Harpoon = fireHarpoon,
	Cannon = fireCannon,
	BoxingGlove = fireGlove,
	TeslaCoil = fireTesla,
	GravityFlipper = fireGravityFlip,
	FreezeRay = fireFreeze,
	AcidBlaster = fireAcid,
	StormCloud = fireStorm,
	BanHammer = fireHammer,
	Railgun = startRailgun,
	Minigun = fireMinigun,
	MissileSwarm = fireMissiles,
}

---------------------------------------------------------------------------
-- Traps and gadgets
---------------------------------------------------------------------------

local function bounce(arena, item, bodyPart)
	local now = os.clock()
	if item.broken or now - item.lastUsed < 0.4 then
		return
	end
	item.lastUsed = now

	-- Launch straight away from the pad: up off the floor, sideways off a wall
	-- (with a little lift so it arcs across the room), or down off the ceiling
	-- (worked out in the room's own directions: X across, Y up, Z toward the camera)
	local space = arena.roomCFrame.Rotation
	local away = space:VectorToObjectSpace(item.model:GetPivot().UpVector)
	local launch = away * BOUNCE_SPEED
	if math.abs(away.X) > 0.5 then
		launch += Vector3.new(0, BOUNCE_SPEED * 0.3, 0)
	end
	for _, part in arena.noob.parts do
		local velocity = space:VectorToObjectSpace(part.AssemblyLinearVelocity)
		-- Keep a bit of the speed it had along the pad, plus a little randomness
		local along = velocity - away * velocity:Dot(away)
		local wobble = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 10
		local launched = launch + Vector3.new(along.X, along.Y, along.Z * 0.4) * 0.5 + wobble
		part.AssemblyLinearVelocity = space:VectorToWorldSpace(launched)
	end
	arena.noob:spin(8)
	arena.ignoreImpactUntil = now + 0.1
	Sounds.playAt("Spring", item.position)
	arena:hit("BouncePad", item, { { part = bodyPart, amount = BOUNCE_DAMAGE } })

	local pad = item.model:FindFirstChild("Pad")
	if pad then
		pad.Color = Color3.new(1, 1, 1)
		task.delay(0.15, function()
			pad.Color = PAD_COLOR
		end)
	end
	useUp(arena, item)
end

-- A body part landed on the spikes: stab it, and it bounces back off them
local function stab(arena, item, bodyPart)
	local now = os.clock()
	if item.broken or now - item.lastUsed < SPIKE_COOLDOWN then
		return
	end
	item.lastUsed = now
	local up = item.model:GetPivot().UpVector -- out of the spikes, into the room
	bodyPart.AssemblyLinearVelocity += up * SPIKE_BOUNCE
	arena.noob:push(up * SPIKE_BOUNCE * 0.4)
	arena.ignoreImpactUntil = now + 0.1
	Sounds.playAt("SpikeStab", bodyPart.Position)
	arena:hit("Spikes", item, { { part = bodyPart, amount = SPIKE_DAMAGE, position = nearestPointOn(bodyPart, item.position) } })
	useUp(arena, item)
end

-- The jaws slam shut on a body part and hold it (see stepTrap). One snap and it's spent.
local function snapTrap(arena, item, bodyPart)
	if item.closed or item.broken then
		return
	end
	item.closed = true
	item.held = bodyPart
	item.holdLeft = TRAP_HOLD
	setUses(item, 0) -- (it's taken away once it lets go)
	-- Each jaw swings up round its hinge in the middle
	local pivot = item.model:GetPivot()
	for part, rest in item.movers do
		local side = part:GetAttribute("Jaw")
		local hinge = CFrame.new(side * 0.25, -0.35, 0)
		part.CFrame = pivot * hinge * CFrame.Angles(0, 0, side * TRAP_CLOSED) * hinge:Inverse() * rest
	end
	Sounds.playAt("TrapSnap", item.position)
	if not Config.FAMILY_FRIENDLY then
		Sounds.playAt("BoneCrunch", bodyPart.Position)
	end
	arena.ignoreImpactUntil = os.clock() + 0.2
	arena:hit("BearTrap", item, { { part = bodyPart, amount = TRAP_DAMAGE } })
end

-- Holds the trapped body part down in the jaws, then springs open and flings the noob
-- back up into the room
local function stepTrap(arena, item, dt)
	if not item.holdLeft then
		return
	end
	item.holdLeft -= dt
	local pivot = item.model:GetPivot()
	local grip = (pivot * CFrame.new(0, 0.6, 0)).Position
	local part = item.held
	part.AssemblyLinearVelocity = (grip - part.Position) * 10
	-- Being held still isn't the end of the run (a run ends once the noob stops moving,
	-- and that used to happen just before the trap let go)
	arena.stillTime = 0
	if item.holdLeft <= 0 then
		item.holdLeft = nil
		item.broken = true
		arena.noob:launchAway(pivot.UpVector, TRAP_FLING, (math.random() - 0.5) * 20)
		arena.ignoreImpactUntil = os.clock() + 0.15
		Sounds.playAt("Spring", item.position)
		task.delay(0.6, function()
			arena:removeItem(item)
		end)
	end
end

-- Where a body part touches the spinning blade, if it does.
-- The blade is a flat disc facing the camera, so only its round edge matters: we find
-- the point of the body part closest to the blade's middle and see if it's inside the
-- edge. Returns that point, how deep it's in, and which way is "out" from the middle
-- and "along" the edge (the way the teeth are moving there), or nil if not touching.
local function sawContact(center, part)
	-- The closest point of the (box-shaped) body part to the middle of the blade
	local closest = nearestPointOn(part, center.Position)
	local relative = center:PointToObjectSpace(closest)
	if math.abs(relative.Z) > SAW_THICKNESS then
		return nil -- in front of or behind the blade, not touching its edge
	end
	local flat = Vector3.new(relative.X, relative.Y, 0)
	local distance = flat.Magnitude
	if distance >= SAW_RADIUS then
		return nil
	end
	-- Deep inside (or right on the middle): push it out the way the part's middle is
	if distance < 0.2 then
		flat = center:PointToObjectSpace(part.Position) * Vector3.new(1, 1, 0)
		flat = if flat.Magnitude > 0.01 then flat else Vector3.yAxis
	end
	local out = flat.Unit
	-- The blade turns clockwise (as seen from the camera), so this is where the teeth go
	local along = Vector3.new(out.Y, -out.X, 0)
	return closest, SAW_RADIUS - distance, center:VectorToWorldSpace(out), center:VectorToWorldSpace(along)
end

-- Spins the blade. Anything touching it gets grabbed by the teeth and dragged round
-- the edge (like real friction), can't sink into the solid blade, and judders as the
-- teeth bite. Body parts still on the noob get cut while they're in contact: thin
-- arms and legs saw through faster than the head, and the tough torso slowest.
local function stepSaw(arena, item, dt)
	local center = item.model:GetPivot()
	local turn = center * CFrame.Angles(0, 0, -SAW_SPIN * dt) * center:Inverse()
	for _, part in item.spinParts do
		part.CFrame = turn * part.CFrame
	end

	item.grindTimer = (item.grindTimer or 0) - dt
	local biteNow = item.grindTimer <= 0
	if biteNow then
		item.grindTimer = SAW_TICK
	end
	local rimSpeed = SAW_SPIN * SAW_RADIUS
	local grip = 1 - math.exp(-SAW_GRIP * dt) -- how much of the teeth's speed it picks up this frame
	local noob = arena.noob
	local hits = {}
	for _, part in noob.parts do
		local point, depth, out, along = sawContact(center, part)
		if point then
			local velocity = part.AssemblyLinearVelocity
			-- The blade is solid: no sinking into it, and anything inside gets pushed back out
			local outSpeed = velocity:Dot(out)
			local wanted = depth * SAW_PUSH_OUT
			if outSpeed < wanted then
				velocity += out * (wanted - outSpeed)
			end
			-- The teeth drag it round the edge
			velocity += along * (rimSpeed - velocity:Dot(along)) * grip
			if biteNow then
				-- Each bite of the teeth knocks it out a little, so it judders against the blade
				velocity += out * (3 + math.random() * 5)
				part.AssemblyAngularVelocity += center.LookVector * (math.random() - 0.5) * 12
				if noob.attached[part] and not noob.dead then
					local cut = SAW_CUT[part.Name] or 1
					local bite = 0.7 + 0.6 * math.min(depth / 0.6, 1) -- pressed in harder = deeper cut
					table.insert(hits, { part = part, amount = SAW_DAMAGE * cut * bite, position = point })
				end
			end
			part.AssemblyLinearVelocity = velocity
			arena.ignoreImpactUntil = os.clock() + 0.1 -- being dragged round isn't a crash
		end
	end

	if #hits > 0 then
		-- Only a fresh touch builds the combo, not every bite
		local now = os.clock()
		local fresh = now - (item.lastGrind or 0) > 0.6
		item.lastGrind = now
		if now - (item.lastGrindSound or 0) > 0.3 then
			item.lastGrindSound = now
			item.cutSound = if item.cutSound == "SawCut1" then "SawCut2" else "SawCut1"
			Sounds.playAt(item.cutSound, hits[1].position)
		end
		arena:hit("Saw", if fresh then item else nil, hits)
		useUp(arena, item)
	end
end

-- Spins `parts` round the line through `center` pointing along `axis`
local function spinRound(parts, center, axis, angle)
	local turn = CFrame.new(center) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-center)
	for _, part in parts do
		part.CFrame = turn * part.CFrame
	end
end

-- Blows everything in front of it (the noob, and any bits torn off it) away across the
-- room. Each second of wind is one use.
local function stepFan(arena, item, dt)
	local pivot = item.model:GetPivot()
	local up = pivot.UpVector
	spinRound(item.spinParts, pivot.Position, up, FAN_SPIN * dt)
	local space = arena.roomCFrame.Rotation
	for _, part in arena.noob.parts do
		local offset = part.Position - pivot.Position
		local along = offset:Dot(up)
		local side = space:VectorToObjectSpace(offset - up * along) * Vector3.new(1, 1, 0)
		if along > 0 and along < FAN_RANGE and side.Magnitude < FAN_WIDTH then
			-- Weaker further away
			part.AssemblyLinearVelocity += up * FAN_PUSH * (1 - 0.5 * along / FAN_RANGE) * dt
			arena.armed = true -- the crashes it causes count
			arena.fanPushedAt = os.clock() -- (for the "Gone With the Wind" achievement)
		end
	end
	item.blowTime = (item.blowTime or 0) + dt
	if item.blowTime >= 1 then
		item.blowTime -= 1
		useUp(arena, item)
	end
end

-- Swings back and forth like a pendulum. The spiked ball smashes whatever it meets,
-- sending it flying the way the ball is going.
local function stepWreckingBall(arena, item, dt)
	local before = item.swingTime or 0
	item.swingTime = before + dt
	local phase = item.swingTime / SWING_PERIOD * math.pi * 2
	local angle = SWING_ANGLE * math.sin(phase)
	local half = item.weapon.size.Y / 2
	local hinge = wreckingBallRest(item) * CFrame.new(0, half, 0)
	local swung = hinge * CFrame.Angles(0, 0, angle) -- (turning round the line facing the camera)
	item.model:PivotTo(swung * CFrame.new(0, -half, 0))
	local ball = swung * CFrame.new(0, -CHAIN_LENGTH, 0)
	-- A whoosh each time it swings through the bottom
	if before > 0 and math.sin(before / SWING_PERIOD * math.pi * 2) * math.sin(phase) <= 0 then
		Sounds.playAt("SwingWhoosh", ball.Position)
	end

	local now = os.clock()
	if now - item.lastUsed < BALL_COOLDOWN then
		return
	end
	for _, part in arena.noob.parts do
		local touching = nearestPointOn(part, ball.Position)
		if arena.noob.attached[part] and (touching - ball.Position).Magnitude <= BALL_RADIUS then
			item.lastUsed = now
			-- How fast the ball is going (it's fastest at the bottom of the swing)
			local turnSpeed = SWING_ANGLE * math.pi * 2 / SWING_PERIOD * math.cos(phase)
			local velocity = ball.RightVector * turnSpeed * CHAIN_LENGTH
			local away = part.Position - ball.Position
			away = if away.Magnitude > 0.01 then away.Unit else -ball.UpVector
			arena.noob:push(velocity * 1.1 + away * 15)
			arena.noob:spin(8)
			arena.ignoreImpactUntil = now + 0.15
			Sounds.playAt("ChainSmash", touching)
			local amount = BALL_DAMAGE + 10 * math.min(velocity.Magnitude / 30, 1)
			arena:hit("WreckingBall", item, { { part = part, amount = amount, position = touching } })
			useUp(arena, item)
			return
		end
	end
end

-- The black hole is done: it shrinks smaller and smaller, spinning faster, until it's
-- microscopic, and then it's gone with a pop
local function collapseBlackHole(arena, item)
	item.broken = true -- used up (Items.step leaves it alone from now on)
	item.uses = 0
	if item.loopSound then
		item.loopSound.Playing = false
	end
	task.spawn(function()
		local elapsed = 0
		while elapsed < SHRINK_TIME and arena.items[item.id] == item do
			local step = RunService.Heartbeat:Wait()
			elapsed += step
			local shrink = math.clamp(elapsed / SHRINK_TIME, 0, 1)
			local center = item.model:GetPivot()
			spinRound(item.spinParts, center.Position, center.LookVector, (4 + 20 * shrink) * step)
			-- Slow at first, then faster and faster
			pcall(item.model.ScaleTo, item.model, math.max(ATOM_SCALE, 1 - shrink * shrink))
		end
		if arena.items[item.id] == item then
			local center = item.model:GetPivot().Position
			Sounds.playAt("LimbPop", center, 1.5)
			puff(arena.room, center, 1.2, Color3.fromRGB(230, 200, 255), 0.25)
			arena.recorder:event("pop", { position = center })
			arena:removeItem(item)
		end
	end)
end

-- The noob reached the middle: it's sucked into the void (infinite damage), vanishing
-- into the black hole, and then the black hole shrinks away
local function swallow(arena, item)
	local center = item.model:GetPivot().Position
	Sounds.playAt("BlackHoleBoom", center, 0.6)
	arena:destroyNoob("BlackHole", item)
	arena.recorder:event("swallow", { position = center })
	local tween = TweenInfo.new(SWALLOW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in arena.noob.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			TweenService:Create(part, tween, { Size = Vector3.one * 0.05, Position = center, Transparency = 1 }):Play()
		elseif part:IsA("Decal") then
			part.Transparency = 1
		end
	end
	collapseBlackHole(arena, item)
end

-- Sucks everything in and swirls it round, tearing at arms and legs that get right into
-- the middle, and swallows the noob once its body gets there
local function stepBlackHole(arena, item, dt)
	local center = item.model:GetPivot()
	for _, part in { arena.noob.torso, arena.noob.parts[2] } do
		if arena.noob.attached[part] and (part.Position - center.Position).Magnitude <= SWALLOW_RADIUS then
			swallow(arena, item)
			return
		end
	end
	spinRound(item.spinParts, center.Position, center.LookVector, 4 * dt)
	local space = arena.roomCFrame.Rotation
	local towardCamera = space.ZVector
	local grinding = {}
	for _, part in arena.noob.parts do
		local offset = center.Position - part.Position
		local distance = offset.Magnitude
		if distance < PULL_RANGE and distance > 0.01 then
			local inward = offset.Unit
			local swirl = towardCamera:Cross(inward) -- round and round, flat to the camera
			local pull = PULL_BASE + PULL_CLOSE / (distance + 1) -- the closer, the stronger
			local velocity = part.AssemblyLinearVelocity
			-- Slow down the going-round part of its speed, so it spirals inward
			local sideways = velocity - inward * velocity:Dot(inward)
			velocity -= sideways * math.min(SWIRL_DRAG * dt, 1)
			velocity += (inward + swirl * SWIRL) * pull * dt
			-- Caught in the pull, the noob floats instead of falling out of it
			velocity += Vector3.yAxis * Config.NOOB_GRAVITY * WEIGHTLESS * dt
			part.AssemblyLinearVelocity = velocity
			arena.armed = true
			local limb = part ~= arena.noob.torso and part ~= arena.noob.parts[2]
			if distance <= GRIND_RADIUS and limb and arena.noob.attached[part] then
				table.insert(grinding, part)
			end
		end
	end
	arena.ignoreImpactUntil = os.clock() + 0.1 -- being swirled round isn't a crash

	item.grindTimer = (item.grindTimer or 0) - dt
	if #grinding > 0 and item.grindTimer <= 0 then
		item.grindTimer = GRIND_TICK
		local hits = {}
		for _, part in grinding do
			table.insert(hits, { part = part, amount = GRIND_DAMAGE })
		end
		-- Only a fresh grab builds the combo, not every tick
		local now = os.clock()
		local fresh = now - (item.lastGrind or 0) > 0.6
		item.lastGrind = now
		arena:hit("BlackHole", if fresh then item else nil, hits)
	end
end

-- The minigun's barrels spin up before it can fire, and keep spinning while it does
local function spinMinigun(item, dt)
	item.spin = math.min(1, item.spin + dt / MINIGUN_SPIN_UP)
	local gun = item.model:GetPivot()
	spinRound(item.spinParts, gun.Position, gun.LookVector, item.spin * 30 * dt)
	item.loopWanted = item.spin >= 1
end

-- The railgun's core swells and brightens while it charges, then it fires
local function chargeRailgun(arena, item, dt)
	item.charging -= dt
	local progress = 1 - math.max(item.charging, 0) / RAIL_CHARGE
	item.core.Size = item.coreSize * (1 + progress * 1.5)
	if item.charging <= 0 then
		item.charging = nil
		fireRailgun(arena, item)
	end
end

-- The boxing glove and the ban hammer shoot out and come back (this keeps going even
-- once they're used up, so the last punch still finishes)
local function animate(item, dt)
	if item.punchTime then
		item.punchTime += dt
		local t = item.punchTime
		local out = if t < 0.08 then t / 0.08 elseif t < 0.18 then 1 else math.max(0, 1 - (t - 0.18) / 0.3)
		poseMovers(item, CFrame.new(0, out * GLOVE_OUT, 0))
		if out <= 0 then
			item.punchTime = nil
		end
	end
	if item.slamTime then
		item.slamTime += dt
		local t = item.slamTime
		local down = if t < HAMMER_DROP_TIME
			then t / HAMMER_DROP_TIME
			elseif t < HAMMER_DROP_TIME + HAMMER_HOLD then 1
			else math.max(0, 1 - (t - HAMMER_DROP_TIME - HAMMER_HOLD) / HAMMER_RAISE_TIME)
		poseHammer(item, down * item.slamDrop)
		if down <= 0 then
			item.slamTime = nil
		end
	end
end

-- The noob's `bodyPart` touched the item
function Items.touched(arena, item, bodyPart)
	if arena.noob.dead then
		return -- torn-off pieces landing on traps don't set them off
	end
	local id = item.weapon.id
	if id == "Mine" then
		Items.detonate(arena, item)
	elseif id == "BouncePad" then
		bounce(arena, item, bodyPart)
	elseif id == "Spikes" then
		stab(arena, item, bodyPart)
	elseif id == "BearTrap" and arena.running then
		snapTrap(arena, item, bodyPart)
	end
end

-- Runs every frame. While the room is playing, weapons fire and fuses burn by themselves.
function Items.step(arena, item, dt)
	local weapon = item.weapon
	animate(item, dt)
	if item.broken then
		return
	end
	if weapon.aims then
		-- Shooting weapons always aim at the noob
		local target = arena.noob.torso.Position
		if (target - item.position).Magnitude > 0.5 then
			item.model:PivotTo(CFrame.lookAt(item.position, target))
		end
	end
	-- Weapons hold still while paused, and once the noob has been destroyed (nothing
	-- keeps attacking the pieces, or wastes its uses on them)
	local active = arena.running and not arena.noob.dead
	if item.loopSound then
		local on = active and item.loopWanted
		if item.loopSound.Playing ~= on then
			item.loopSound.Playing = on
		end
	end
	if item.wind and item.wind.Enabled ~= active then
		item.wind.Enabled = active
	end
	if not active then
		if item.flames then
			item.flames.Enabled = false
		end
		return
	end

	if weapon.id == "Minigun" then
		spinMinigun(item, dt)
	elseif item.charging then
		chargeRailgun(arena, item, dt)
		if item.broken then
			return -- that was its last shot
		end
	end

	if weapon.fireInterval then
		item.timer = (item.timer or FIRST_SHOT_DELAY) - dt
		if item.timer <= 0 then
			local fired = FIRE[weapon.id](arena, item)
			item.timer = if fired == false then RETRY_DELAY else weapon.fireInterval
		end
		if item.lens then
			chargeLaser(item)
		end
	elseif weapon.fuse then
		if not item.fuseTime then
			-- The fuse just got lit (the black hole starts humming instead)
			if weapon.id == "BlackHole" then
				item.loopWanted = true
			else
				Sounds.playAt(if weapon.id == "Grenade" then "PinPull" else "FuseHiss", item.position)
			end
		end
		item.fuseTime = (item.fuseTime or 0) + dt
		-- Blink red faster and faster until it goes off
		if item.body then
			local blinkSpeed = 4 + 12 * item.fuseTime / weapon.fuse
			item.body.Color = if math.floor(item.fuseTime * blinkSpeed) % 2 == 0 then item.bodyColor else FUSE_COLOR
		end
		-- The grenade (and the nuke) beeps: beep... beep.. beep.beep.beep, faster and a
		-- little higher as the fuse runs out, so you can feel it about to go off
		if (weapon.id == "Grenade" or weapon.id == "MiniNuke") and item.fuseTime >= (item.nextBeep or 0) then
			local left = 1 - item.fuseTime / weapon.fuse -- 1 when lit, 0 when it blows
			item.nextBeep = item.fuseTime + BEEP_FASTEST + (BEEP_SLOWEST - BEEP_FASTEST) * left
			Sounds.playAt("GrenadeBeep", item.position).PlaybackSpeed = 1 + (1 - left) * 0.35
		end
		if weapon.id == "BlackHole" then
			stepBlackHole(arena, item, dt)
			-- Didn't catch the noob in time: it shrinks away anyway
			if not item.broken and item.fuseTime >= weapon.fuse then
				collapseBlackHole(arena, item)
			end
			return
		end
		if item.fuseTime >= weapon.fuse then
			Items.detonate(arena, item)
		end
	elseif weapon.id == "Saw" then
		stepSaw(arena, item, dt)
	elseif weapon.id == "Fan" then
		stepFan(arena, item, dt)
	elseif weapon.id == "WreckingBall" then
		stepWreckingBall(arena, item, dt)
	elseif weapon.id == "BearTrap" then
		stepTrap(arena, item, dt)
	end

	-- A flamethrower keeps burning for a moment after each blast
	if item.flames then
		local burning = (item.burstLeft or 0) > 0
		item.flames.Enabled = burning
		if burning then
			item.burstLeft -= dt
			item.nextFlameTick -= dt
			if item.nextFlameTick <= 0 then
				item.nextFlameTick = 0.15
				burnCone(arena, item)
			end
		end
	end
end

return Items
