-- What each weapon/trap does once it's placed in a room.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemModels = require(Shared.ItemModels)
local Sounds = require(Shared.Sounds)

local Items = {}

-- How hard things push the noob is tuned to its gentler gravity (Config.NOOB_GRAVITY).
-- `damage` = hit points taken by each body part right at the center of the blast
local BLASTS = {
	-- `bounce` = how fast a mine throws the noob up into the air (the bounce pad does 55)
	Mine = { radius = 12, power = 65, damage = 30, bounce = 60 },
	Grenade = { radius = 13, power = 75, damage = 35 },
	BigTNT = { radius = 18, power = 95, damage = 45 },
}
local ROCKET_BLAST = { radius = 11, power = 80, damage = 35 }
local ARROW_SPEED = 55 -- studs per second: slow enough to watch the arrow fly
local ARROW_TURN = math.rad(220) -- how fast (per second) an arrow can steer onto the noob in flight
local ROCKET_SPEED = 40
local BULLET_SPEED = 90
local PROJECTILE_RANGE = 150
-- How far ahead of a flying model's middle its tip is (so the tip is what hits)
local PROJECTILE_REACH = { Arrow = 1.55, Rocket = 0.95, Bullet = 0.35 }
local BOUNCE_SPEED = 55
local ARROW_DAMAGE = 13
local HEADSHOT_DAMAGE = 26
local BULLET_DAMAGE = 4
local BOUNCE_DAMAGE = 5
local SAW_DAMAGE = 6
local SAW_TICK = 0.15 -- seconds between grinds
local SAW_SPIN = 12 -- radians per second
local FLAME_RANGE = 13
local FLAME_ANGLE = math.rad(25)
local FLAME_DAMAGE = 3
local FLAME_BURST = 0.6 -- seconds each blast of flame lasts
local BURN_TIME = 3
local LASER_DAMAGE = 25
local PAD_COLOR = Color3.fromRGB(80, 220, 90)
local FUSE_COLOR = Color3.fromRGB(255, 60, 60)
local FIRST_SHOT_DELAY = 0.4 -- seconds after PLAY before a weapon's first shot

local LIFE_GREEN = Color3.fromRGB(80, 220, 90)
local LIFE_ORANGE = Color3.fromRGB(255, 150, 30)
local LIFE_RED = Color3.fromRGB(230, 40, 40)
local LIFE_DARK_RED = Color3.fromRGB(110, 0, 0)

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

-- A run ended: the weapon keeps whatever life it has left, ready for the next run
function Items.resetForNextRun(item)
	item.timer = nil
	item.fuseTime = nil
	item.burstLeft = 0
	item.grindTimer = nil
	if item.flames then
		item.flames.Enabled = false
	end
	if item.body and item.bodyColor then
		item.body.Color = item.bodyColor
	end
end

-- What it sells back for: the price, times how much of its life is left
function Items.sellValue(item)
	return math.floor(item.weapon.price * item.uses / item.weapon.uses)
end

-- `placement` is a CFrame from Config.placementFor (where it goes, and which way round)
function Items.create(weapon, id, placement, parent)
	local model = ItemModels.build(weapon.id)
	model:SetAttribute("ItemId", id)
	local spinParts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("ItemId", id)
			if part.Name == "Blade" or part.Name == "Tooth" or part.Name == "Hub" then
				table.insert(spinParts, part)
			end
		end
	end

	-- Life bar above it, showing how much is left before it's used up
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LifeBar"
	billboard.Size = UDim2.fromOffset(54, 9)
	-- Offset along the item's own "up", so a bounce pad on the ceiling or a wall
	-- shows its bar on the room side, not inside the wall
	billboard.StudsOffsetWorldSpace = Vector3.new(0, weapon.size.Y / 2 + 0.9, 0)
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
		lifeBack = back,
		lifeFill = fill,
		lastUsed = 0,
		body = body,
		bodyColor = body and body.Color,
		flames = model:FindFirstChild("Flames", true),
		spinParts = spinParts,
	}
	setUses(item, weapon.uses)
	return item
end

-- `placement` is a CFrame from Config.placementFor
function Items.move(item, placement)
	item.position = placement.Position
	-- Surface weapons turn to face the surface they're on; aiming weapons keep aiming
	local rotation = if item.weapon.anySurface then placement.Rotation else item.model:GetPivot().Rotation
	item.model:PivotTo(CFrame.new(placement.Position) * rotation)
end

-- Blows up a mine, grenade or TNT
function Items.detonate(arena, item)
	if item.broken or arena.items[item.id] ~= item then
		return
	end
	item.broken = true
	arena:removeItem(item)
	local blast = BLASTS[item.weapon.id]
	if item.weapon.id == "BigTNT" then
		Sounds.playAt("BigBoom", item.position) -- a deep rumble on top of the normal bang
	elseif item.weapon.id == "Mine" then
		Sounds.playAt("MineClick", item.position) -- the click of stepping on it...
		Sounds.playAt("MineBlast", item.position) -- ...and the dirt-throwing blast
	elseif item.weapon.id == "Grenade" then
		Sounds.playAt("GrenadeBlast", item.position)
		task.delay(0.08, Sounds.playAt, "Shrapnel", item.position) -- shrapnel flies just after the crack
	end
	arena:explode(item.position, blast.radius, blast.power, blast.damage, item)

	-- A land mine launches the noob up into the air, the way a real one would
	local noob = arena.noob
	if blast.bounce and not noob.frozen and (noob.torso.Position - item.position).Magnitude <= blast.radius then
		local away = noob.torso.Position.X - item.position.X
		local sideways = math.clamp(away * 3, -12, 12) + (math.random() - 0.5) * 6
		noob:bounceUp(blast.bounce, sideways)
		arena.ignoreImpactUntil = os.clock() + 0.15
	end
end

---------------------------------------------------------------------------
-- Things that fly: arrows, rockets and bullets
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
		kind = model.Name, -- "Arrow", "Rocket" or "Bullet"
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
		-- It can't leave the room
		local relative = target - arena.origin
		target = arena.origin
			+ Vector3.new(
				math.clamp(relative.X, -half.X + 1, half.X - 1),
				math.clamp(relative.Y, 1, Config.ROOM_SIZE.Y - 1),
				math.clamp(relative.Z, -half.Z + 1, half.Z - 1)
			)
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

local function bulletHit(arena, projectile, result)
	local part = result.Instance
	part.AssemblyLinearVelocity += projectile.direction * 12
	arena.ignoreImpactUntil = os.clock() + 0.05
	arena:hit("MachineGun", projectile.item, { { part = part, amount = BULLET_DAMAGE, position = result.Position } })
end

-- Moves everything in flight along. Rockets blow up on the first thing they hit;
-- arrows stick into the noob, or into the wall for a moment if they miss.
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
			local hitNoob = result and table.find(arena.noob.parts, result.Instance)
			if projectile.kind == "Rocket" then
				projectile.model:Destroy()
				if result then
					local blast = ROCKET_BLAST
					arena:explode(result.Position, blast.radius, blast.power, blast.damage, projectile.item)
				end
			elseif projectile.kind == "Bullet" then
				projectile.model:Destroy()
				if hitNoob then
					bulletHit(arena, projectile, result)
				end
			elseif hitNoob then
				projectile.model:Destroy()
				arrowHit(arena, projectile, result)
			else
				-- Missed: the arrow sticks in the wall for a moment, head first
				if result then
					projectile.model:PivotTo(pivot.Rotation + (result.Position - projectile.direction * 0.9))
					Sounds.playAt("ArrowWall", result.Position)
				end
				Debris:AddItem(projectile.model, 2)
			end
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

local function fireLaser(arena, item)
	local muzzle = item.model:GetPivot() * CFrame.new(0, 0, -1.9)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = arena.noob.parts
	local result = Workspace:Raycast(muzzle.Position, muzzle.LookVector * 100, params)
	local target = if result then result.Position else muzzle.Position + muzzle.LookVector * 60

	-- The beam: a glowing red line that fades quickly
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 40, 40)
	beam.Size = Vector3.new(0.25, 0.25, (target - muzzle.Position).Magnitude)
	beam.CFrame = CFrame.lookAt(muzzle.Position:Lerp(target, 0.5), target)
	beam.Parent = arena.room
	Debris:AddItem(beam, 0.25)
	arena.recorder:event("laser", { position = muzzle.Position, target = target - arena.origin })
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

local FIRE = {
	Crossbow = fireCrossbow,
	RocketLauncher = fireRocket,
	MachineGun = fireMachineGun,
	Flamethrower = fireFlamethrower,
	Laser = fireLaser,
}

---------------------------------------------------------------------------
-- Traps
---------------------------------------------------------------------------

local function bounce(arena, item, bodyPart)
	local now = os.clock()
	if item.broken or now - item.lastUsed < 0.4 then
		return
	end
	item.lastUsed = now

	-- Launch straight away from the pad: up off the floor, sideways off a wall
	-- (with a little lift so it arcs across the room), or down off the ceiling
	local away = item.model:GetPivot().UpVector
	local launch = away * BOUNCE_SPEED
	if math.abs(away.X) > 0.5 then
		launch += Vector3.new(0, BOUNCE_SPEED * 0.3, 0)
	end
	for _, part in arena.noob.parts do
		local velocity = part.AssemblyLinearVelocity
		-- Keep a bit of the speed it had along the pad, plus a little randomness
		local along = velocity - away * velocity:Dot(away)
		local wobble = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 10
		part.AssemblyLinearVelocity = launch + Vector3.new(along.X, along.Y, along.Z * 0.4) * 0.5 + wobble
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

-- Spins the blade, and grinds (and flings) any body part touching it
local function stepSaw(arena, item, dt)
	local center = item.model:GetPivot()
	local turn = center * CFrame.Angles(0, 0, -SAW_SPIN * dt) * center:Inverse()
	for _, part in item.spinParts do
		part.CFrame = turn * part.CFrame
	end

	item.grindTimer = (item.grindTimer or 0) - dt
	if item.grindTimer > 0 then
		return
	end
	item.grindTimer = SAW_TICK
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = arena.noob.parts
	local hits = {}
	for _, part in Workspace:GetPartsInPart(item.model.PrimaryPart, params) do
		if arena.noob.attached[part] then
			-- Thrown along the edge of the blade, the way it spins, and a bit outwards
			local outward = part.Position - center.Position
			outward = Vector3.new(outward.X, outward.Y, 0)
			outward = if outward.Magnitude > 0.1 then outward.Unit else Vector3.yAxis
			local along = Vector3.new(outward.Y, -outward.X, 0)
			part.AssemblyLinearVelocity = along * 28 + outward * 10
			table.insert(hits, { part = part, amount = SAW_DAMAGE })
		end
	end
	if #hits > 0 then
		arena.ignoreImpactUntil = os.clock() + 0.1
		-- Only a fresh touch builds the combo, not every grind
		local now = os.clock()
		local fresh = now - (item.lastGrind or 0) > 0.6
		item.lastGrind = now
		if now - (item.lastGrindSound or 0) > 0.5 then
			item.lastGrindSound = now
			Sounds.playAt("SawGrind", item.position)
		end
		arena:hit("Saw", if fresh then item else nil, hits)
		useUp(arena, item)
	end
end

-- The noob's `bodyPart` touched the item
function Items.touched(arena, item, bodyPart)
	local id = item.weapon.id
	if id == "Mine" then
		Items.detonate(arena, item)
	elseif id == "BouncePad" then
		bounce(arena, item, bodyPart)
	end
end

-- Runs every frame. While the room is playing, weapons fire and fuses burn by themselves.
function Items.step(arena, item, dt)
	local weapon = item.weapon
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
	if not arena.running then
		if item.flames then
			item.flames.Enabled = false
		end
		return -- paused
	end

	if weapon.fireInterval then
		item.timer = (item.timer or FIRST_SHOT_DELAY) - dt
		if item.timer <= 0 then
			item.timer = weapon.fireInterval
			FIRE[weapon.id](arena, item)
		end
	elseif weapon.fuse then
		if not item.fuseTime then
			-- The fuse just got lit
			Sounds.playAt(if weapon.id == "Grenade" then "PinPull" else "FuseHiss", item.position)
		end
		item.fuseTime = (item.fuseTime or 0) + dt
		-- Blink red faster and faster until it goes off
		if item.body then
			local blinkSpeed = 4 + 12 * item.fuseTime / weapon.fuse
			item.body.Color = if math.floor(item.fuseTime * blinkSpeed) % 2 == 0 then item.bodyColor else FUSE_COLOR
		end
		if item.fuseTime >= weapon.fuse then
			Items.detonate(arena, item)
		end
	elseif weapon.id == "Saw" then
		stepSaw(arena, item, dt)
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
