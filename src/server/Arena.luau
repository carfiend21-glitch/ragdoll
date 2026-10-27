-- One player's room: the noob, the weapons placed in it, and the damage score.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ShopItems = require(Shared.ShopItems)
local Sounds = require(Shared.Sounds)
local Weapons = require(Shared.Weapons)

local Items = require(script.Parent.Items)
local Leaderboards = require(script.Parent.Leaderboards)
local Noob = require(script.Parent.Noob)
local PlayerData = require(script.Parent.PlayerData)
local Recorder = require(script.Parent.Recorder)

local IMPACT_SPEED = 25 -- how sudden a stop must be to count as a crash
local SURFACE_COOLDOWN = 0.3
-- A run ends by itself once the noob has been (almost) still for this long
local SETTLE_SPEED = 1.5
local SETTLE_SPIN = 1.5
local SETTLE_TIME = 1.5
local BURN_TICK = 0.3 -- seconds between burn damage
local BURN_DAMAGE = 3
local AIRBORNE_HEIGHT = 3.5 -- every body part must be this high off the floor to count as flying
-- Weapons that make their own sound when placed (the rest use "Place")
local PLACE_SOUNDS = { Mine = "MineClick", Grenade = "GrenadeDrop" }

local Arena = {}
Arena.__index = Arena

local function isSafeVector(value)
	return typeof(value) == "Vector3"
		and value.X == value.X -- false for NaN ("not a number")
		and value.Y == value.Y
		and value.Z == value.Z
		and value.Magnitude < 1e5
end

-- `room` comes from WorldBuilder. `achievements` gets told about hits and crashes.
function Arena.new(index, room, achievements)
	local self = setmetatable({}, Arena)
	self.index = index
	self.room = room.model
	self.nameLabel = room.nameLabel -- under "ROOM #" on the sign: who's playing in it
	self.itemsFolder = room.model.Items
	self.roomCFrame = Config.getRoomCFrame(index) -- where the room is and which way it faces
	self.origin = self.roomCFrame.Position -- middle of the floor
	self.achievements = achievements
	self.owner = nil
	self.active = false
	self.items = {}
	self.itemCount = 0
	self.nextItemId = 0
	self.noobNumber = 0
	self.projectiles = {} -- arrows and rockets in flight
	self.projectilesFolder = Instance.new("Folder")
	self.projectilesFolder.Name = "Projectiles"
	self.projectilesFolder.Parent = self.room
	self.recorder = Recorder.new(self)
	self:resetScore()

	-- The room's classic look, so a room theme can be put on and taken off again
	self.roomParts = {}
	for _, part in self.room:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Glass" and part.Name ~= "Sign" then
			self.roomParts[part] = { part.Color, part.Material }
		end
	end

	-- The noob floats in the middle of the room until PLAY is pressed.
	-- Pressing PLAY starts a "run": weapons are locked until the run ends.
	self.running = false
	self.inRun = false
	self.runDamage = 0
	self.stillTime = 0
	self.noob = Noob.new(self.roomCFrame * CFrame.new(0, Config.ROOM_SIZE.Y / 2, 0), self.room)
	self.noob.onTouched = function(bodyPart, other)
		self:_onNoobTouched(bodyPart, other)
	end
	self:_applyLooks({})
	self:respawnNoob()
	return self
end

-- Dresses the room in the owner's Noob Buck looks (`equipped` = { [category] = item id }):
-- noob skin, blood color, room theme and weapon finish. {} = all classic.
function Arena:_applyLooks(equipped)
	self.looks = {}
	for _, category in { "NoobSkin", "Blood", "Room", "Finish" } do
		self.looks[category] = ShopItems.equippedItem(equipped, category)
	end
	ShopItems.applyRoomTheme(self.looks.Room, self.roomParts)
	self.noob:setSkin(self.looks.NoobSkin)
	-- Blood is drawn on players' screens, so they read the color from here
	self.room:SetAttribute("BloodStyle", self.looks.Blood.id)
end

-- The look ids, for the replays: { NoobSkin = id, Blood = id, Room = id, Finish = id }
function Arena:lookIds()
	local ids = {}
	for category, item in self.looks do
		ids[category] = item.id
	end
	return ids
end

function Arena:resetScore()
	self.damage = 0 -- the score (real damage x Config.SCORE_MULTIPLIER)
	self.realDamage = 0 -- what the noob actually took (cash is paid on this)
	self.combo = 0
	self.lastComboTime = 0
	self.recentTraps = {} -- [itemId] = time it last hit the noob
	self.surfaceCooldowns = {}
	self.lastSurface = {} -- [body part name] = { kind = "Floor" | "Wall" | "Ceiling", time } (for crash sounds)
	self.ignoreImpactUntil = 0
	self.lastSpeed = 0
	self.airTime = 0 -- seconds in the air not yet paid out as cash
	self.roundStats = { arrowHits = 0, mineHits = 0 } -- for achievements
	self.runStats = { wallHits = 0 }
end

-- A fresh noob, floating (paused) in the middle of the room
function Arena:respawnNoob()
	self.noob:spawn()
	self.noobNumber += 1
	self:_setRunning(false)
	-- Crashes only score after a weapon has hit this noob,
	-- so the noob flopping over when it appears doesn't count
	self.armed = false
	self.lastVelocities = {} -- [body part] = its speed last frame
	self.lastImpactTimes = {} -- [body part] = when it last took crash damage
	self.burnTimer = 0
end

function Arena:_setInRun(inRun)
	self.inRun = inRun
	self.stillTime = 0
	self.runStats = { wallHits = 0 }
	self.runDamage = 0 -- damage done since PLAY was pressed
	self.room:SetAttribute("InRun", inRun)
end

-- Ends the current run and a fresh noob floats in the middle, ready for the next one.
-- Like the original, weapons are used up: anything used up is gone, and the rest
-- keep whatever life they have left (no free refills).
function Arena:_endRun()
	if self.inRun then
		self:_recordRun()
		self:_clearProjectiles()
		for _, item in self.items do
			if item.broken then
				self:removeItem(item)
			else
				Items.resetForNextRun(item)
			end
		end
		self:_safetyNet()
	end
	self:_setInRun(false)
	self:respawnNoob()
	self.recorder:event("restart")
end

-- If someone has used up everything and can't afford even a crossbow,
-- top them up so they can keep playing
function Arena:_safetyNet()
	local cheapestUseful = Weapons.byId.Crossbow.price
	if self.owner and self.itemCount == 0 and PlayerData.getCash(self.owner) < cheapestUseful then
		PlayerData.addCash(self.owner, cheapestUseful - PlayerData.getCash(self.owner))
		Remotes.Hint:FireClient(self.owner, ("Out of weapons and cash? Here's %s to keep going!"):format(Config.formatCash(cheapestUseful)))
	end
end

function Arena:_clearProjectiles()
	self.projectilesFolder:ClearAllChildren()
	self.projectiles = {}
end

function Arena:startRound(player)
	self:clearItems()
	self:resetScore()
	self:_setInRun(false)
	self:_applyLooks(PlayerData.getEquipped(player))
	self:respawnNoob()
	self.owner = player
	self.active = true
	PlayerData.resetCash(player) -- everyone starts each round with the same small amount
	self.nameLabel.Text = player.DisplayName
	self.recorder:start()
end

function Arena:stopRound()
	if self.inRun then
		self:_recordRun() -- the round ended in the middle of a run
	end
	self.active = false
	self.recorder:stop()
end

-- A run just finished: is it the player's best ever? (for the lobby leaderboard)
function Arena:_recordRun()
	local damage = self.runDamage
	self.runDamage = 0
	if self.owner and damage > 0 and PlayerData.recordRun(self.owner, damage) then
		Leaderboards.recordRun(self.owner, damage)
		Remotes.Notify:FireClient(self.owner, "⭐ NEW BEST RUN!", Config.formatScore(damage) .. " points in one run")
	end
end

-- Empties the room for the next round
function Arena:clear()
	self.active = false
	self.owner = nil
	self:clearItems()
	self:resetScore()
	self:_setInRun(false)
	self:_applyLooks({})
	self:respawnNoob()
	self.nameLabel.Text = ""
end

function Arena:clearItems()
	for _, item in self.items do
		item.broken = true
		item.model:Destroy()
	end
	self.items = {}
	self.itemCount = 0
	self:_clearProjectiles()
end

function Arena:removeItem(item)
	if self.items[item.id] ~= item then
		return
	end
	item.broken = true
	self.items[item.id] = nil
	self.itemCount -= 1
	item.model:Destroy()
end

function Arena:_addItem(weapon, placement)
	self.nextItemId += 1
	local id = tostring(self.nextItemId)
	self.items[id] = Items.create(weapon, id, placement, self.itemsFolder, self.looks.Finish)
	self.itemCount += 1
end

-- The functions below are called when the player asks for something.
-- Never trust what a player's device sends: check everything.
-- Weapons can only be added, moved or removed while setting up (not during a run).

function Arena:_canEdit(player)
	return self.active and player == self.owner and not self.inRun
end

function Arena:placeItem(player, weaponId, position)
	if not self:_canEdit(player) then
		return
	end
	local weapon = Weapons.byId[weaponId]
	if not weapon or not isSafeVector(position) then
		return
	end
	if not PlayerData.isWeaponUnlocked(player, weapon.id) then
		return
	end
	if self.itemCount >= Config.MAX_ITEMS_PER_ROOM then
		Remotes.Hint:FireClient(player, ("Your room is full! (%d weapons max)"):format(Config.MAX_ITEMS_PER_ROOM))
		return
	end
	-- Like the original, each weapon has a limit on how many can be placed
	local sameKind = 0
	for _, item in self.items do
		if item.weapon == weapon then
			sameKind += 1
		end
	end
	if sameKind >= weapon.maxPlaced then
		Remotes.Hint:FireClient(player, ("You can only place %d %s at a time."):format(weapon.maxPlaced, weapon.name))
		return
	end
	-- Each weapon you place costs cash, like in the original game
	if not PlayerData.spendCash(player, weapon.price) then
		Remotes.Hint:FireClient(player, ("Not enough cash! The %s costs %s."):format(weapon.name, Config.formatCash(weapon.price)))
		return
	end
	local placement = Config.placementFor(self.index, weapon, position)
	self:_addItem(weapon, placement)
	Sounds.playAt(PLACE_SOUNDS[weapon.id] or "Place", placement.Position)
	-- A rented weapon only gets used up once it's actually been placed in a round
	PlayerData.useRental(player, weapon.id)
end

function Arena:moveItem(player, itemId, position)
	if not self:_canEdit(player) or not isSafeVector(position) then
		return
	end
	local item = self.items[itemId]
	if item and not item.broken then
		Items.move(item, Config.placementFor(self.index, item.weapon, position))
	end
end

-- Dragging a weapon into the trash can sells it back
function Arena:takeOutItem(player, itemId)
	if not self:_canEdit(player) then
		return
	end
	local item = self.items[itemId]
	if item then
		-- A partly used weapon only sells for the life it has left
		local value = Items.sellValue(item)
		self:removeItem(item)
		PlayerData.addCash(player, value)
		Remotes.Hint:FireClient(player, ("Sold the %s back: +%s"):format(item.weapon.name, Config.formatCash(value)))
	end
end

-- Sets a body part on fire
function Arena:ignite(part, seconds)
	if self.noob:ignite(part, seconds) and self.active and self.owner then
		self.achievements.onIgnite(self.owner, self)
	end
end

-- PLAY (true) or STOP (false). While stopped, the noob, arrows, rockets and fuses are frozen.
function Arena:_setRunning(running)
	self.running = running
	self.room:SetAttribute("Running", running)
	if running then
		self.noob:unfreeze()
		-- Don't count the noob starting to move again as a crash
		self.lastVelocities = {}
		self.ignoreImpactUntil = os.clock() + 0.1
	else
		self.noob:freeze()
	end
end

function Arena:setRunning(player, running)
	if not self.active or player ~= self.owner or type(running) ~= "boolean" or running == self.running then
		return
	end
	if running and self.noob.dead then
		return -- a fresh noob is on its way
	end
	if running and not self.inRun then
		self:_setInRun(true) -- starting a run: weapons are locked until it ends
	end
	self:_setRunning(running)
	self.recorder:event(if running then "play" else "pause")
end

-- Ends the run early. The damage score carries on.
function Arena:restart(player)
	if not self.active or player ~= self.owner or os.clock() - (self.lastRestart or 0) < 1 then
		return
	end
	self.lastRestart = os.clock()
	self:_endRun()
end

-- One attack (a shot, a blast, a bounce or a crash) hitting one or more body parts.
-- `hits` is a list of { part = BasePart, amount = number, position = Vector3? }.
-- `item` is the weapon that did it (nil for crashes).
-- Weapon hits close together build a combo, and the combo multiplies all damage.
function Arena:hit(source, item, hits)
	if not self.active or not self.owner or self.noob.dead then
		return
	end
	local now = os.clock()
	if item then
		self.armed = true
		self.combo = if now - self.lastComboTime <= Config.COMBO_WINDOW then self.combo + 1 else 1
		self.lastComboTime = now
		self.recentTraps[item.id] = now
	end
	local inCombo = now - self.lastComboTime <= Config.COMBO_WINDOW
	local multiplier = if inCombo then math.min(1 + 0.25 * (self.combo - 1), Config.MAX_COMBO_MULTIPLIER) else 1

	-- What happened to each body part, sent to the player's screen
	local reports = {}
	for _, hit in hits do
		if self.noob.attached[hit.part] then
			local info = Config.BODY_PARTS_BY_NAME[hit.part.Name]
			-- `damage` is what the body part really loses; `points` is the (much bigger) score for it
			local damage = math.max(1, math.floor(hit.amount * multiplier + 0.5))
			local points = damage * Config.SCORE_MULTIPLIER
			local position = hit.position or hit.part.Position
			local outcome = self.noob:damage(hit.part, damage)
			-- Damage earns cash straight away: $1 each time the total passes another DAMAGE_PER_CASH
			local earned = (self.realDamage + damage) // Config.DAMAGE_PER_CASH - self.realDamage // Config.DAMAGE_PER_CASH
			self.realDamage += damage
			self.damage += points
			if self.inRun then
				self.runDamage += points
			end
			if earned > 0 then
				PlayerData.addCash(self.owner, earned)
			end
			self.recorder:event("hit", { position = position, points = points, damage = damage, part = info.name })
			if outcome then
				-- Torn off (or the whole noob fell apart): the replay shows the red stumps
				for index, part in self.noob.parts do
					if part == hit.part or (outcome == "Killed" and part ~= self.noob.torso) then
						self.recorder:event("torn", { part = index })
					end
				end
			end
			table.insert(reports, {
				part = info.name,
				joint = info.joint,
				points = points,
				damage = damage,
				position = position,
				outcome = outcome,
				source = source,
			})
			self.achievements.onPartHit(self.owner, self, source, info.key, outcome)
			if outcome == "Killed" then
				self:_onDestroyed(source, info.key)
				break
			end
		end
	end
	if #reports == 0 then
		return
	end

	self.owner:SetAttribute("Damage", self.damage)
	self.recorder:event("damage", { damage = self.damage })
	self:_playHitSounds(source, reports)
	-- The player and anyone spectating them see the hit numbers and blood
	local comboShown = if inCombo then self.combo else 0
	for _, viewer in Players:GetPlayers() do
		if viewer == self.owner or viewer:GetAttribute("Spectating") == self.index then
			Remotes.HitFx:FireClient(viewer, reports, comboShown)
		end
	end
	self.achievements.onHit(self.owner, self, source)
end

-- What a crash sounds like, by what the noob hit (the Surface attribute on room parts)
local CRASH_SOUNDS = { Floor = "FloorHit", Wall = "WallHit", Ceiling = "CeilingHit" }
local OTHER_CRASH_SOUNDS = { "Thud", "BodyImpact" } -- hitting anything else
local SURFACE_MEMORY = 0.25 -- seconds a touch still counts as "what it just hit"
local BULLET_SOUND_GAP = 0.12 -- the machine gun fires fast, so not every bullet thwacks

-- Crashes sound like the surface they hit, louder and deeper the harder they were,
-- with a fleshy smack on top of big ones. Bullets thwack, and torn-off limbs splat.
function Arena:_playHitSounds(source, reports)
	local biggest = reports[1]
	for _, report in reports do
		if report.outcome then
			Sounds.playAt("Splat", report.position)
			Sounds.playAt("WetSplat", report.position, 0.8)
		end
		if report.damage > biggest.damage then
			biggest = report
		end
	end
	if source == "Impact" then
		local hard = math.clamp(biggest.damage / 20, 0, 1) -- 0 = a tap, 1 = a huge crash
		local touched = self.lastSurface[biggest.part]
		local surface = touched and os.clock() - touched.time <= SURFACE_MEMORY and touched.kind
		local name = CRASH_SOUNDS[surface] or OTHER_CRASH_SOUNDS[math.random(#OTHER_CRASH_SOUNDS)]
		local sound = Sounds.playAt(name, biggest.position, 0.45 + hard * 0.9)
		sound.PlaybackSpeed *= 1.12 - hard * 0.3 -- harder = deeper
		if hard > 0.5 then
			Sounds.playAt("BodyImpact", biggest.position, hard * 0.7)
		end
	elseif source == "MachineGun" then
		local now = os.clock()
		if now - (self.lastBulletSound or 0) > BULLET_SOUND_GAP then
			self.lastBulletSound = now
			Sounds.playAt("Punch", biggest.position, 0.5)
		end
	end
end

function Arena:_onDestroyed(source, partKey)
	self.achievements.onDestroyed(self.owner, self, source, partKey)
	-- A cash bonus for finishing it off
	PlayerData.addCash(self.owner, Config.KILL_CASH)
	Remotes.Hint:FireClient(self.owner, ("Noob destroyed! +%s"):format(Config.formatCash(Config.KILL_CASH)))
	-- Nothing keeps attacking the pieces: shots already flying vanish, and weapons
	-- wait for the fresh noob (see Items.step)
	self:_clearProjectiles()
	-- Swap in a fresh noob after a moment (unless it's already been replaced)
	local number = self.noobNumber
	task.delay(Config.RESPAWN_DELAY, function()
		if self.noobNumber == number then
			self:_endRun()
		end
	end)
end

-- How many different traps hit the noob in the last couple of seconds
function Arena:countRecentTraps()
	local now, count = os.clock(), 0
	for _, time in self.recentTraps do
		if now - time <= Config.COMBO_WINDOW then
			count += 1
		end
	end
	return count
end

-- `damage` is how much a body part right at the center takes; it drops off with distance
function Arena:explode(center, radius, power, damage, item)
	local explosion = Instance.new("Explosion")
	explosion.Position = center
	explosion.BlastRadius = radius
	explosion.BlastPressure = 0 -- we push the noob ourselves, below
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = self.room
	self.recorder:event("boom", { position = center, radius = radius })

	local hits = {}
	for _, reached in self.noob:blast(center, radius, power) do
		table.insert(hits, { part = reached.part, amount = damage * (1 - 0.7 * reached.distance / radius) })
	end
	if #hits > 0 then
		self.ignoreImpactUntil = os.clock() + 0.15
		self:hit(item.weapon.id, item, hits)
	end

	-- Explosions set off other explosives nearby: chain reactions!
	for _, other in self.items do
		if other.weapon.explosive and (other.position - center).Magnitude <= radius then
			task.delay(0.15, Items.detonate, self, other)
		end
	end
end

function Arena:_onNoobTouched(bodyPart, other)
	local surface = other:GetAttribute("Surface")
	if surface then
		local now = os.clock()
		-- Remembered so a crash right after sounds like what it hit
		self.lastSurface[bodyPart.Name] = { kind = surface, time = now }
		if now - (self.surfaceCooldowns[surface] or 0) > SURFACE_COOLDOWN then
			self.surfaceCooldowns[surface] = now
			if self.active and self.owner then
				self.achievements.onSurface(self.owner, self, surface, self.lastSpeed)
			end
		end
		return
	end

	local itemId = other:GetAttribute("ItemId")
	local item = itemId and self.items[itemId]
	if item and self.active and self.noob.attached[bodyPart] then
		Items.touched(self, item, bodyPart)
	end
end

-- Runs every physics frame. `dt` is the seconds since the last frame.
function Arena:step(dt)
	if self.running then
		Items.stepProjectiles(self, dt)
	end
	self.recorder:step()

	local noob = self.noob
	local relative = self.roomCFrame:PointToObjectSpace(noob.torso.Position)
	local size = Config.ROOM_SIZE
	if
		relative ~= relative -- NaN: physics went haywire
		or math.abs(relative.X) > size.X / 2 + 2
		or relative.Y < -2
		or relative.Y > size.Y + 2
		or math.abs(relative.Z) > size.Z / 2 + 2
	then
		-- It escaped the room somehow: put it back in the middle
		self:_endRun()
		return
	end
	self.lastSpeed = noob.torso.AssemblyLinearVelocity.Magnitude

	-- Once the noob has stopped moving, the run is over: back to the middle
	if self.running and self.inRun and not noob.dead and #self.projectiles == 0 then
		local moving = false
		for _, part in noob.parts do
			if
				noob.attached[part]
				and (
					part.AssemblyLinearVelocity.Magnitude > SETTLE_SPEED
					or part.AssemblyAngularVelocity.Magnitude > SETTLE_SPIN
				)
			then
				moving = true
				break
			end
		end
		self.stillTime = if moving then 0 else self.stillTime + dt
		if self.stillTime >= SETTLE_TIME then
			self:_endRun()
			return
		end
	end

	-- A sudden big change in a body part's speed means it crashed into something
	local now = os.clock()
	local crashes = {}
	for _, part in noob.parts do
		local velocity = part.AssemblyLinearVelocity
		local last = self.lastVelocities[part]
		self.lastVelocities[part] = velocity
		if
			last
			and self.running
			and self.armed
			and noob.attached[part]
			and now > self.ignoreImpactUntil
			and now - (self.lastImpactTimes[part] or 0) > 0.2
		then
			local change = (velocity - last).Magnitude
			if change > IMPACT_SPEED then
				self.lastImpactTimes[part] = now
				table.insert(crashes, { part = part, amount = math.min((change - IMPACT_SPEED) * 0.8 + 2, 30) })
			end
		end
	end
	if #crashes > 0 then
		self:hit("Impact", nil, crashes)
	end

	if self.running then
		self:_stepFire(dt)
		self:_stepAirTime(dt)
	end
	for _, item in self.items do
		Items.step(self, item, dt)
	end
end

-- Burning body parts take damage and blacken a little at a time
function Arena:_stepFire(dt)
	local burning = self.noob:updateFires(dt)
	self.burnTimer -= dt
	if #burning == 0 or self.burnTimer > 0 then
		return
	end
	self.burnTimer = BURN_TICK
	local hits = {}
	for _, part in burning do
		local scorched = self.noob:scorch(part, 0.08)
		self.recorder:event("burn", { part = table.find(self.noob.parts, part), scorched = scorched })
		table.insert(hits, { part = part, amount = BURN_DAMAGE })
	end
	self:hit("Flamethrower", nil, hits)
end

-- The longer the noob stays in the air during a run, the more cash you earn (like the original)
function Arena:_stepAirTime(dt)
	if not self.inRun or self.noob.dead or not self.owner or not self.active then
		return
	end
	for _, part in self.noob.parts do
		if self.noob.attached[part] and part.Position.Y - self.origin.Y < AIRBORNE_HEIGHT then
			return -- on (or nearly on) the floor
		end
	end
	self.airTime += dt
	if self.airTime >= 1 / Config.AIRTIME_CASH_PER_SECOND then
		self.airTime = 0
		PlayerData.addCash(self.owner, 1)
	end
end

return Arena
