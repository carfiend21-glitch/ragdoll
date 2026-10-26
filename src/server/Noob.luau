-- The classic noob ragdoll: six separate body parts held together by floppy
-- ball-and-socket joints, so it tumbles and flops like a rag doll.
local Noob = {}
Noob.__index = Noob

local YELLOW = BrickColor.new("Bright yellow").Color
local BLUE = BrickColor.new("Bright blue").Color
local GREEN = BrickColor.new("Br. yellowish green").Color

-- density, friction, elasticity (bounciness), friction weight, elasticity weight
local BODY_PHYSICS = PhysicalProperties.new(0.7, 0.4, 0.4, 1, 1)
local MAX_BOLTS = 25

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
end

-- Stops two parts that overlap at a joint from shoving each other apart
local function noCollide(model, part0, part1)
	local constraint = Instance.new("NoCollisionConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = model
end

function Noob.new(spawnPosition, parent)
	local self = setmetatable({}, Noob)
	self.spawnPosition = spawnPosition
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
	local base = CFrame.new(self.spawnPosition) * CFrame.Angles(0, math.pi, math.rad(math.random(-10, 10)))
	local torso = newBodyPart(model, "Torso", Vector3.new(2, 2, 1), base, BLUE)
	local head = newBodyPart(model, "Head", Vector3.new(2, 1, 1), base * CFrame.new(0, 1.5, 0), YELLOW)
	local leftArm = newBodyPart(model, "Left Arm", Vector3.new(1, 2, 1), base * CFrame.new(-1.5, 0, 0), YELLOW)
	local rightArm = newBodyPart(model, "Right Arm", Vector3.new(1, 2, 1), base * CFrame.new(1.5, 0, 0), YELLOW)
	local leftLeg = newBodyPart(model, "Left Leg", Vector3.new(1, 2, 1), base * CFrame.new(-0.5, -2, 0), GREEN)
	local rightLeg = newBodyPart(model, "Right Leg", Vector3.new(1, 2, 1), base * CFrame.new(0.5, -2, 0), GREEN)

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
	newJoint(torso, Vector3.new(0, 1, 0), head, Vector3.new(0, -0.5, 0), UP, 40, 50)
	newJoint(torso, Vector3.new(-1.5, 0.5, 0), leftArm, Vector3.new(0, 0.5, 0), DOWN, 150, 80)
	newJoint(torso, Vector3.new(1.5, 0.5, 0), rightArm, Vector3.new(0, 0.5, 0), DOWN, 150, 80)
	newJoint(torso, Vector3.new(-0.5, -1, 0), leftLeg, Vector3.new(0, 1, 0), DOWN, 80, 30)
	newJoint(torso, Vector3.new(0.5, -1, 0), rightLeg, Vector3.new(0, 1, 0), DOWN, 80, 30)

	for _, limb in { head, leftArm, rightArm, leftLeg, rightLeg } do
		noCollide(model, torso, limb)
	end
	noCollide(model, head, leftArm)
	noCollide(model, head, rightArm)
	noCollide(model, leftLeg, rightLeg)

	model.PrimaryPart = torso
	model.Parent = self.parent

	self.model = model
	self.torso = torso
	self.parts = { torso, head, leftArm, rightArm, leftLeg, rightLeg }
	self.bolts = 0
	for _, part in self.parts do
		-- The server runs the physics, so every player sees the same flops
		pcall(part.SetNetworkOwner, part, nil)
		part.Touched:Connect(function(other)
			if self.onTouched then
				self.onTouched(part, other)
			end
		end)
	end
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
		part.AssemblyAngularVelocity += Vector3.new(0, 0, (math.random() - 0.5) * 2 * strength)
	end
end

-- Throws body parts away from an explosion.
-- Returns how close the nearest body part was, or nil if the blast missed.
function Noob:blast(center, radius, power)
	local closest = nil
	for _, part in self.parts do
		local offset = part.Position - center
		local distance = offset.Magnitude
		if distance < radius then
			local direction = if distance > 0.1 then offset.Unit else Vector3.yAxis
			-- Mostly sideways/up (we watch from the side), with an extra upward kick for fun
			direction = Vector3.new(direction.X, direction.Y + 0.5, direction.Z * 0.2).Unit
			local strength = power * (0.4 + 0.6 * (1 - distance / radius))
			part.AssemblyLinearVelocity += direction * strength
			part.AssemblyAngularVelocity += Vector3.new(0, 0, (math.random() - 0.5) * 40)
			closest = if closest then math.min(closest, distance) else distance
		end
	end
	return closest
end

-- Leaves a crossbow bolt stuck in a body part (no blood, just a funny pincushion)
function Noob:stickBolt(part, position, direction)
	if self.bolts >= MAX_BOLTS then
		return
	end
	self.bolts += 1
	local bolt = Instance.new("Part")
	bolt.Name = "Bolt"
	bolt.Size = Vector3.new(0.15, 0.15, 1.8)
	bolt.CFrame = CFrame.lookAt(position - direction * 0.6, position + direction)
	bolt.Color = Color3.fromRGB(160, 160, 170)
	bolt.Material = Enum.Material.Metal
	bolt.Massless = true
	bolt.CanCollide = false
	bolt.CanTouch = false
	bolt.CanQuery = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = bolt
	weld.Parent = bolt
	bolt.Parent = self.model
end

return Noob
