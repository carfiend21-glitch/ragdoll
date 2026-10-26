-- What each weapon/trap does once it's placed in a room.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ItemModels = require(ReplicatedStorage:WaitForChild("Shared").ItemModels)

local Items = {}

local BLASTS = {
	Mine = { radius = 14, power = 110, damage = 45 },
	Grenade = { radius = 16, power = 130, damage = 55 },
}
local PAD_COLOR = Color3.fromRGB(80, 220, 90)
local GRENADE_COLOR = Color3.fromRGB(70, 110, 50)

local function setUses(item, uses)
	item.uses = uses
	item.usesLabel.Text = tostring(uses)
end

-- Counts down one use; breaks the item when it runs out
local function useUp(arena, item)
	setUses(item, item.uses - 1)
	if item.uses <= 0 then
		item.broken = true
		-- Short delay so you see the last hit happen first
		task.delay(0.3, function()
			arena:removeItem(item)
		end)
	end
end

function Items.create(weapon, id, position, parent)
	local model = ItemModels.build(weapon.id)
	model:SetAttribute("ItemId", id)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("ItemId", id)
		end
	end

	-- Little number above it showing how many uses are left
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(40, 24)
	billboard.StudsOffset = Vector3.new(0, weapon.size.Y / 2 + 0.8, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = weapon.uses > 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	billboard.Parent = model.PrimaryPart

	model:PivotTo(CFrame.new(position))
	model.Parent = parent

	local item = {
		id = id,
		weapon = weapon,
		model = model,
		position = position,
		usesLabel = label,
		lastUsed = 0,
	}
	setUses(item, weapon.uses)
	return item
end

function Items.move(item, position)
	item.position = position
	item.model:PivotTo(CFrame.new(position) * item.model:GetPivot().Rotation)
end

-- Blows up a mine or grenade
function Items.detonate(arena, item)
	if item.broken or arena.items[item.id] ~= item then
		return
	end
	item.broken = true
	arena:removeItem(item)
	local blast = BLASTS[item.weapon.id]
	arena:explode(item.position, blast.radius, blast.power, blast.damage, item)
end

local function fireCrossbow(arena, item)
	local now = os.clock()
	if item.broken or now - item.lastUsed < 0.3 then
		return
	end
	item.lastUsed = now

	local origin = item.position
	local toTarget = arena.noob.torso.Position - origin
	local direction = if toTarget.Magnitude > 0.5 then toTarget.Unit else Vector3.xAxis

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = arena.noob.parts
	local result = Workspace:Raycast(origin, direction * 200, params)
	local hitPosition = if result then result.Position else origin + direction * 60

	-- A quick streak so you can see the shot
	local streak = Instance.new("Part")
	streak.Anchored = true
	streak.CanCollide = false
	streak.CanTouch = false
	streak.CanQuery = false
	streak.Material = Enum.Material.Neon
	streak.Color = Color3.fromRGB(255, 240, 180)
	streak.Size = Vector3.new(0.12, 0.12, (hitPosition - origin).Magnitude)
	streak.CFrame = CFrame.lookAt(origin:Lerp(hitPosition, 0.5), hitPosition)
	streak.Parent = arena.room
	Debris:AddItem(streak, 0.08)

	if result then
		local part = result.Instance
		part.AssemblyLinearVelocity += direction * 60
		arena.noob:push(direction * 18)
		arena.noob:stickBolt(part, result.Position, direction)
		arena.ignoreImpactUntil = now + 0.1
		arena:addDamage(15, "Crossbow", result.Position, item)
	end
	useUp(arena, item)
end

local function lightGrenade(arena, item)
	if item.lit or item.broken then
		return
	end
	item.lit = true
	local body = item.model:FindFirstChild("Body")
	for blink = 1, 4 do
		if item.broken then
			return -- another explosion got it first
		end
		body.Color = if blink % 2 == 1 then Color3.fromRGB(255, 60, 60) else GRENADE_COLOR
		task.wait(0.12)
	end
	Items.detonate(arena, item)
end

local function bounce(arena, item)
	local now = os.clock()
	if item.broken or now - item.lastUsed < 0.4 then
		return
	end
	item.lastUsed = now

	for _, part in arena.noob.parts do
		local velocity = part.AssemblyLinearVelocity
		part.AssemblyLinearVelocity = Vector3.new(velocity.X * 0.5 + (math.random() - 0.5) * 16, 105, velocity.Z * 0.2)
	end
	arena.noob:spin(15)
	arena.ignoreImpactUntil = now + 0.1
	arena:addDamage(5, "BouncePad", item.position + Vector3.new(0, 1, 0), item)

	local pad = item.model:FindFirstChild("Pad")
	if pad then
		pad.Color = Color3.new(1, 1, 1)
		task.delay(0.15, function()
			pad.Color = PAD_COLOR
		end)
	end
	useUp(arena, item)
end

-- The player clicked/tapped the item
function Items.activate(arena, item)
	local id = item.weapon.id
	if id == "Crossbow" then
		fireCrossbow(arena, item)
	elseif id == "Grenade" then
		task.spawn(lightGrenade, arena, item)
	elseif id == "Mine" then
		Items.detonate(arena, item)
	end
end

-- The noob touched the item
function Items.touched(arena, item)
	local id = item.weapon.id
	if id == "Mine" then
		Items.detonate(arena, item)
	elseif id == "BouncePad" then
		bounce(arena, item)
	end
end

-- Runs every frame
function Items.step(arena, item)
	if item.weapon.id == "Crossbow" and not item.broken then
		-- Crossbows always aim at the noob
		local target = arena.noob.torso.Position
		if (target - item.position).Magnitude > 0.5 then
			item.model:PivotTo(CFrame.lookAt(item.position, target))
		end
	end
end

return Items
