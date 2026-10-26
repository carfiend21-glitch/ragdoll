-- One player's room: the noob, the weapons placed in it, and the damage score.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)

local Items = require(script.Parent.Items)
local Noob = require(script.Parent.Noob)
local PlayerData = require(script.Parent.PlayerData)

local IMPACT_SPEED = 35 -- how sudden a stop must be to count as a crash
local SURFACE_COOLDOWN = 0.3

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
	self.label = room.label
	self.itemsFolder = room.model.Items
	self.origin = Config.getRoomOrigin(index)
	self.achievements = achievements
	self.owner = nil
	self.active = false
	self.items = {}
	self.itemCount = 0
	self.nextItemId = 0
	self:resetScore()

	self.noob = Noob.new(self.origin + Vector3.new(0, 6, 0), self.room)
	self.noob.onTouched = function(bodyPart, other)
		self:_onNoobTouched(bodyPart, other)
	end
	return self
end

function Arena:resetScore()
	self.damage = 0
	self.combo = 0
	self.lastComboTime = 0
	self.recentTraps = {} -- [itemId] = time it last hit the noob
	self.surfaceCooldowns = {}
	self.lastImpactTime = 0
	self.ignoreImpactUntil = 0
	self.lastSpeed = 0
end

function Arena:respawnNoob()
	self.noob:spawn()
	-- Crashes only score after a weapon has hit this noob,
	-- so the noob flopping over when it appears doesn't count
	self.armed = false
	self.lastVelocity = nil
end

function Arena:startRound(player)
	self:clearItems()
	self:resetScore()
	self:respawnNoob()
	self.owner = player
	self.active = true
	self.label.Text = ("ROOM %d: %s"):format(self.index, player.DisplayName)
end

function Arena:stopRound()
	self.active = false
end

-- Empties the room for the next round
function Arena:clear()
	self.active = false
	self.owner = nil
	self:clearItems()
	self:resetScore()
	self:respawnNoob()
	self.label.Text = "ROOM " .. self.index
end

function Arena:clearItems()
	for _, item in self.items do
		item.broken = true
		item.model:Destroy()
	end
	self.items = {}
	self.itemCount = 0
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

-- The functions below are called when the player asks for something.
-- Never trust what a player's device sends: check everything.

function Arena:placeItem(player, weaponId, position)
	if not self.active or player ~= self.owner then
		return
	end
	local weapon = Weapons.byId[weaponId]
	if not weapon or not isSafeVector(position) then
		return
	end
	if not PlayerData.isWeaponUnlocked(player, weapon.id) or self.itemCount >= Config.MAX_ITEMS_PER_ROOM then
		return
	end
	self.nextItemId += 1
	local id = tostring(self.nextItemId)
	local worldPosition = Config.clampToRoom(self.index, position, weapon.size, weapon.onFloor)
	self.items[id] = Items.create(weapon, id, worldPosition, self.itemsFolder)
	self.itemCount += 1
end

function Arena:moveItem(player, itemId, position)
	if not self.active or player ~= self.owner or not isSafeVector(position) then
		return
	end
	local item = self.items[itemId]
	if item and not item.broken then
		Items.move(item, Config.clampToRoom(self.index, position, item.weapon.size, item.weapon.onFloor))
	end
end

function Arena:activateItem(player, itemId)
	if not self.active or player ~= self.owner then
		return
	end
	local item = self.items[itemId]
	if item then
		Items.activate(self, item)
	end
end

function Arena:resetNoob(player)
	if player ~= self.owner or os.clock() - (self.lastManualReset or 0) < 2 then
		return
	end
	self.lastManualReset = os.clock()
	self:respawnNoob()
end

-- Adds damage to the score. `item` is the weapon that did it (nil for crashes).
-- Weapon hits close together build a combo, and the combo multiplies all damage.
function Arena:addDamage(amount, source, position, item)
	if not self.active or not self.owner then
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
	local points = math.max(1, math.floor(amount * multiplier + 0.5))

	self.damage += points
	self.owner:SetAttribute("Damage", self.damage)
	Remotes.HitFx:FireClient(self.owner, points, position, if inCombo then self.combo else 0)
	self.achievements.onHit(self.owner, self, source)
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

function Arena:explode(center, radius, power, damage, item)
	local explosion = Instance.new("Explosion")
	explosion.Position = center
	explosion.BlastRadius = radius
	explosion.BlastPressure = 0 -- we push the noob ourselves, below
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = self.room

	local closest = self.noob:blast(center, radius, power)
	if closest then
		self.ignoreImpactUntil = os.clock() + 0.15
		self:addDamage(damage * (1 - 0.6 * closest / radius), item.weapon.id, center, item)
	end

	-- Explosions set off other explosives nearby: chain reactions!
	for _, other in self.items do
		if other.weapon.explosive and (other.position - center).Magnitude <= radius then
			task.delay(0.15, Items.detonate, self, other)
		end
	end
end

function Arena:_onNoobTouched(_bodyPart, other)
	local surface = other:GetAttribute("Surface")
	if surface then
		local now = os.clock()
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
	if item and self.active then
		Items.touched(self, item)
	end
end

-- Runs every physics frame
function Arena:step()
	local torso = self.noob.torso
	local relative = torso.Position - self.origin
	local size = Config.ROOM_SIZE
	if
		relative ~= relative -- NaN: physics went haywire
		or math.abs(relative.X) > size.X / 2 + 2
		or relative.Y < -2
		or relative.Y > size.Y + 2
		or math.abs(relative.Z) > size.Z / 2 + 2
	then
		-- It escaped the room somehow: put it back in the middle
		self:respawnNoob()
		return
	end

	-- A sudden big change in speed means it crashed into something
	local now = os.clock()
	local velocity = torso.AssemblyLinearVelocity
	if self.armed and self.lastVelocity and now > self.ignoreImpactUntil and now - self.lastImpactTime > 0.15 then
		local change = (velocity - self.lastVelocity).Magnitude
		if change > IMPACT_SPEED then
			self.lastImpactTime = now
			self:addDamage(math.min((change - IMPACT_SPEED) * 0.6 + 3, 40), "Impact", torso.Position, nil)
		end
	end
	self.lastVelocity = velocity
	self.lastSpeed = velocity.Magnitude

	for _, item in self.items do
		Items.step(self, item)
	end
end

return Arena
