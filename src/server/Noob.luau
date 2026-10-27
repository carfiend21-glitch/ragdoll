-- The classic noob ragdoll: six separate body parts held together by floppy
-- ball-and-socket joints, so it tumbles and flops like a rag doll.
-- Each body part has its own hit points. Limbs get torn off when they run out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemModels = require(Shared.ItemModels)
local ShopItems = require(Shared.ShopItems)

local Noob = {}
Noob.__index = Noob

local S = Config.NOOB_SCALE
local YELLOW = BrickColor.new("Bright yellow").Color
local BLUE = BrickColor.new("Bright blue").Color
local GREEN = BrickColor.new("Br. yellowish green").Color
local BLOOD = Color3.fromRGB(130, 0, 0)
local CHARRED = Color3.fromRGB(35, 30, 28)
local CLASSIC_SKIN = ShopItems.byId.ClassicNoob

-- density, friction, elasticity (bounciness), friction weight, elasticity weight
local BODY_PHYSICS = PhysicalProperties.new(0.7, 0.4, 0.4, 1, 1)
local MAX_ARROWS = 25

local function newBodyPart(model, name, size, cframe, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CustomPhysicalProperties = BODY_PHYSICS
	part.Parent = model
	return part
end

-- Joins two body parts with a floppy joint. `pos0`/`pos1` are where the joint
-- sits on each part, `axis` is the way the limb points, `cone` is how far
-- (degrees) it can swing and `twist` how far it can turn.
local function newJoint(part0, pos0, part1, pos1, axis, cone, twist)
	local attachment0 = Instance.new("Attachment")
	attachment0.CFrame = CFrame.fromMatrix(pos0, axis, Vector3.xAxis)
	attachment0.Parent = part0
	local attachment1 = Instance.new("Attachment")
	attachment1.CFrame = CFrame.fromMatrix(pos1, axis, Vector3.xAxis)
	attachment1.Parent = part1

	local socket = Instance.new("BallSocketConstraint")
	socket.Attachment0 = attachment0
	socket.Attachment1 = attachment1
	socket.LimitsEnabled = true
	socket.UpperAngle = cone
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -twist
	socket.TwistUpperAngle = twist
	socket.Parent = part0
	return socket
end

-- Stops two parts that overlap at a joint from shoving each other apart
local function noCollide(model, part0, part1)
	local constraint = Instance.new("NoCollisionConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = model
end

-- A thin red patch glued onto a part (where a limb used to be)
local function addStump(part, spec)
	local stump = Instance.new("Part")
	stump.Name = "Stump"
	stump.Size = spec[2] * S
	stump.CFrame = part.CFrame * CFrame.new(spec[1] * S)
	stump.Color = BLOOD
	stump.Material = Enum.Material.SmoothPlastic
	stump.Massless = true
	stump.CanCollide = false
	stump.CanTouch = false
	stump.CanQuery = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = stump
	weld.Parent = stump
	stump.Parent = part
end

-- `spawnCFrame` = the middle of the room, turned the way the room faces (its +Z
-- points at the camera). `parent` is the room model; the noob's health is shown in its attributes.
function Noob.new(spawnCFrame, parent)
	local self = setmetatable({}, Noob)
	self.spawnCFrame = spawnCFrame
	-- The room's directions: X across the room, Y up, Z toward the camera.
	-- Pushes are mostly kept flat to the camera so the noob stays in view.
	self.space = spawnCFrame.Rotation
	self.parent = parent
	self.onTouched = nil -- set by the room: function(bodyPart, otherPart)
	self:spawn()
	return self
end

-- Builds a fresh noob in the middle of the room (removing the old one)
function Noob:spawn()
	if self.model then
		self.model:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "Noob"

	-- Face the camera, with a small random lean so it never falls the same way twice
	local base = self.spawnCFrame * CFrame.Angles(0, math.pi, math.rad(math.random(-10, 10)))
	local function bodyPart(name, size, offset, color)
		return newBodyPart(model, name, size * S, base * CFrame.new(offset * S), color)
	end
	local torso = bodyPart("Torso", Vector3.new(2, 2, 1), Vector3.zero, BLUE)
	local head = bodyPart("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), YELLOW)
	local leftArm = bodyPart("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), YELLOW)
	local rightArm = bodyPart("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), YELLOW)
	local leftLeg = bodyPart("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), GREEN)
	local rightLeg = bodyPart("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), GREEN)

	-- Classic round head and smile
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	local UP, DOWN = Vector3.yAxis, -Vector3.yAxis
	-- [body part] = the joint holding it onto the torso
	self.joints = {
		[head] = newJoint(torso, Vector3.new(0, 1, 0) * S, head, Vector3.new(0, -0.5, 0) * S, UP, 40, 50),
		[leftArm] = newJoint(torso, Vector3.new(-1.5, 0.5, 0) * S, leftArm, Vector3.new(0, 0.5, 0) * S, DOWN, 150, 80),
		[rightArm] = newJoint(torso, Vector3.new(1.5, 0.5, 0) * S, rightArm, Vector3.new(0, 0.5, 0) * S, DOWN, 150, 80),
		[leftLeg] = newJoint(torso, Vector3.new(-0.5, -1, 0) * S, leftLeg, Vector3.new(0, 1, 0) * S, DOWN, 80, 30),
		[rightLeg] = newJoint(torso, Vector3.new(0.5, -1, 0) * S, rightLeg, Vector3.new(0, 1, 0) * S, DOWN, 80, 30),
	}

	for _, limb in { head, leftArm, rightArm, leftLeg, rightLeg } do
		noCollide(model, torso, limb)
	end
	noCollide(model, head, leftArm)
	noCollide(model, head, rightArm)
	noCollide(model, leftLeg, rightLeg)

	self.model = model
	self.torso = torso
	self.parts = { torso, head, leftArm, rightArm, leftLeg, rightLeg }
	self.attached = {} -- [body part] = true while it's still part of the noob
	self.health = {} -- [body part key] = hit points left
	self.dead = false
	self.arrows = 0
	self.burning = {} -- [body part] = seconds of fire left
	self.scorched = {} -- [body part] = how blackened it is, 0 to 1
	-- A new noob floats, frozen, until the player presses PLAY
	self.frozen = true
	self.savedVelocities = nil
	for _, info in Config.BODY_PARTS do
		self.health[info.key] = info.maxHealth
	end
	for _, part in self.parts do
		part.Anchored = true
		-- Pushes up against some of gravity, so the noob falls at Config.NOOB_GRAVITY
		local center = Instance.new("Attachment")
		center.Parent = part
		local lift = Instance.new("VectorForce")
		lift.Attachment0 = center
		lift.RelativeTo = Enum.ActuatorRelativeTo.World
		lift.ApplyAtCenterOfMass = true
		lift.Force = Vector3.new(0, part:GetMass() * (Workspace.Gravity - Config.NOOB_GRAVITY), 0)
		lift.Parent = part
	end

	-- Dressed in the room owner's noob skin (bought with Noob Bucks)
	ShopItems.applyNoobSkin(self.parts, self.skin or CLASSIC_SKIN)

	model.PrimaryPart = torso
	model.Parent = self.parent

	for _, part in self.parts do
		self.attached[part] = true
		part.Touched:Connect(function(other)
			if self.onTouched then
				self.onTouched(part, other)
			end
		end)
	end
	self:_publishHealth()
end

-- The look of the next noob that spawns (a noob skin from ShopItems)
function Noob:setSkin(skin)
	self.skin = skin
end

-- Sets a body part on fire for `seconds`. Returns true if it wasn't already burning.
function Noob:ignite(part, seconds)
	if not self.attached[part] then
		return false
	end
	local wasBurning = self.burning[part] ~= nil
	self.burning[part] = math.max(self.burning[part] or 0, seconds)
	if not part:FindFirstChild("Flames") then
		local fire = Instance.new("Fire")
		fire.Name = "Flames"
		fire.Size = 3 * S
		fire.Heat = 4
		fire.Parent = part
	end
	return not wasBurning
end

-- Burns fires down by `dt` seconds and puts out the ones that are done.
-- Returns the body parts still burning.
function Noob:updateFires(dt)
	local stillBurning = {}
	for part, secondsLeft in self.burning do
		secondsLeft -= dt
		if secondsLeft <= 0 or not self.attached[part] then
			self.burning[part] = nil
			local fire = part:FindFirstChild("Flames")
			if fire then
				fire:Destroy()
			end
		else
			self.burning[part] = secondsLeft
			table.insert(stillBurning, part)
		end
	end
	return stillBurning
end

-- Blackens a body part a bit more. Returns how blackened it is now (0 to 1).
function Noob:scorch(part, amount)
	local scorched = math.min(1, (self.scorched[part] or 0) + amount)
	self.scorched[part] = scorched
	local original = ShopItems.noobColors(self.skin or CLASSIC_SKIN)[part.Name]
	part.Color = original:Lerp(CHARRED, scorched)
	return scorched
end

-- Holds the noob still exactly where it is (paused)
function Noob:freeze()
	if self.frozen then
		return
	end
	self.frozen = true
	self.savedVelocities = {}
	for _, part in self.parts do
		self.savedVelocities[part] = { part.AssemblyLinearVelocity, part.AssemblyAngularVelocity }
		part.Anchored = true
	end
end

-- Lets physics take over again, carrying on at the speed it had when it was frozen
function Noob:unfreeze()
	if not self.frozen then
		return
	end
	self.frozen = false
	for _, part in self.parts do
		part.Anchored = false
	end
	for _, part in self.parts do
		-- The server runs the physics, so every player sees the same flops
		pcall(part.SetNetworkOwner, part, nil)
		local saved = self.savedVelocities and self.savedVelocities[part]
		if saved then
			part.AssemblyLinearVelocity = saved[1]
			part.AssemblyAngularVelocity = saved[2]
		end
	end
	self.savedVelocities = nil
end

-- Copies hit points onto the room model so players' screens can show them
function Noob:_publishHealth()
	for _, info in Config.BODY_PARTS do
		self.parent:SetAttribute(info.key, math.ceil(self.health[info.key]))
	end
end

-- Takes hit points off a body part.
-- Returns "Torn" if the part got torn off, "Killed" if the noob was destroyed, or nil.
function Noob:damage(part, amount)
	if self.dead or not self.attached[part] then
		return nil
	end
	local info = Config.BODY_PARTS_BY_NAME[part.Name]
	self.health[info.key] = math.max(0, self.health[info.key] - amount)
	local outcome = nil
	if self.health[info.key] <= 0 then
		if info.vital then
			outcome = "Killed"
			self:_destroy()
		else
			outcome = "Torn"
			self:detach(part)
		end
	end
	self:_publishHealth()
	return outcome
end

-- Snaps the joint holding `part` on, so it flies off by itself
function Noob:detach(part)
	local joint = self.joints[part]
	if not joint then
		return
	end
	self.joints[part] = nil
	self.attached[part] = false
	self.health[Config.BODY_PARTS_BY_NAME[part.Name].key] = 0
	joint:Destroy()
	part.AssemblyLinearVelocity += self.space:VectorToWorldSpace(Vector3.new((math.random() - 0.5) * 15, 10, 0))
	if Config.BLOOD_ENABLED then
		local stump = Config.BODY_PARTS_BY_NAME[part.Name].stump
		addStump(self.torso, stump.torso)
		addStump(part, stump.part)
	end
end

-- The noob falls apart into pieces
function Noob:_destroy()
	self.dead = true
	for part in self.joints do
		self:detach(part)
	end
	self.attached[self.torso] = false
	self.health.Torso = 0
end

-- How many arms and legs are still attached
function Noob:limbsLeft()
	local count = 0
	for _, part in self.parts do
		if self.attached[part] and (part.Name:find("Arm") or part.Name:find("Leg")) then
			count += 1
		end
	end
	return count
end

-- Adds speed to every body part (the same for light and heavy parts)
function Noob:push(velocity)
	for _, part in self.parts do
		part.AssemblyLinearVelocity += velocity
	end
end

-- Sets it spinning (around the axis facing the camera, so you can see it)
function Noob:spin(strength)
	for _, part in self.parts do
		part.AssemblyAngularVelocity += self.space.ZVector * (math.random() - 0.5) * 2 * strength
	end
end

-- Throws the whole noob away from a surface (a land mine stuck to the floor, a wall or
-- the ceiling): `away` is the direction out of the surface, in the world. Any speed it
-- had heading into the surface is thrown away first, so it always really bounces
-- instead of the fall swallowing the kick. `sideways` nudges it across the room, away
-- from the blast. Off a wall it gets a little lift too, so it arcs across the room.
function Noob:launchAway(away, speed, sideways)
	local out = self.space:VectorToObjectSpace(away) -- in the room's directions
	for _, part in self.parts do
		local velocity = self.space:VectorToObjectSpace(part.AssemblyLinearVelocity)
		local along = velocity - out * velocity:Dot(out) -- the speed it had along the surface
		local launched = Vector3.new(along.X * 0.4 + sideways, along.Y * 0.4, along.Z * 0.2) + out * speed
		if math.abs(out.X) > 0.5 then
			launched += Vector3.new(0, speed * 0.3, 0)
		end
		part.AssemblyLinearVelocity = self.space:VectorToWorldSpace(launched)
	end
	self:spin(10)
end

-- Throws body parts (and torn-off pieces) away from an explosion.
-- Returns a list of { part, distance } for attached body parts it reached.
function Noob:blast(center, radius, power)
	local reached = {}
	for _, part in self.parts do
		local offset = part.Position - center
		local distance = offset.Magnitude
		if distance < radius then
			local direction = if distance > 0.1 then offset.Unit else Vector3.yAxis
			-- Mostly sideways/up (we watch from the side), with an extra upward kick for fun
			direction = self.space:VectorToObjectSpace(direction)
			direction = self.space:VectorToWorldSpace(Vector3.new(direction.X, direction.Y + 0.5, direction.Z * 0.2).Unit)
			local strength = power * (0.4 + 0.6 * (1 - distance / radius))
			part.AssemblyLinearVelocity += direction * strength
			part.AssemblyAngularVelocity += self.space.ZVector * (math.random() - 0.5) * 20
			if self.attached[part] then
				table.insert(reached, { part = part, distance = distance })
			end
		end
	end
	return reached
end

-- Leaves an arrow stuck in a body part, its head buried in it.
-- Returns where the arrow sits relative to the body part (for replays), or nil.
function Noob:stickArrow(part, position, direction)
	if self.arrows >= MAX_ARROWS then
		return nil
	end
	self.arrows += 1
	local arrow = ItemModels.buildArrow()
	-- Point first, with the head buried in the body part and the feathers sticking out
	arrow:PivotTo(CFrame.lookAt(position - direction * 0.9, position + direction))
	arrow.Parent = self.model
	-- Glued on after it's in place, so it stays exactly there and moves with the body part
	for _, piece in arrow:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Massless = true
			piece.CanCollide = false
			piece.CanTouch = false
			piece.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = piece
			weld.Parent = piece
			piece.Anchored = false
		end
	end
	return part.CFrame:ToObjectSpace(arrow:GetPivot())
end

return Noob
