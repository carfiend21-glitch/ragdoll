-- Picking a weapon, placing it in your room and dragging it around (drop it in
-- the trash can to sell it). Only allowed while setting up, not during a run.
-- Works with a mouse or a touch screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemModels = require(Shared.ItemModels)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)

local player = Players.LocalPlayer

local DRAG_THRESHOLD = 8 -- pixels you must move before a click becomes a drag
local MOVE_SEND_INTERVAL = 0.05 -- seconds between drag updates sent to the server

local Placement = {}
Placement.__index = Placement

-- Your room number while you're allowed to change its weapons
-- (during a round, while setting up, not during a run), or nil
local function activeRoom()
	local room = player:GetAttribute("Room")
	if Remotes.GameState:GetAttribute("Phase") ~= "Round" or not room or room <= 0 then
		return nil
	end
	local rooms = Workspace:FindFirstChild("Rooms")
	local roomModel = rooms and rooms:FindFirstChild("Room" .. room)
	if not roomModel or roomModel:GetAttribute("InRun") then
		return nil
	end
	return room
end

-- What a placed weapon sells back for: its price, times how much of its life is left
local function sellValue(model)
	local weapon = Weapons.byId[model.Name]
	local uses = model:GetAttribute("Uses") or weapon.uses
	return math.floor(weapon.price * uses / weapon.uses)
end

local function screenRay(position)
	return Workspace.CurrentCamera:ScreenPointToRay(position.X, position.Y)
end

-- Where a ray from the screen meets the middle of the room
-- (everything gets placed on that flat middle "sheet", like the 2D original)
local function pointInRoom(ray, room)
	local roomCFrame = Config.getRoomCFrame(room)
	local facing = roomCFrame.ZVector -- the sheet faces the camera, whichever way the room is turned
	local along = ray.Direction:Dot(facing)
	if math.abs(along) < 1e-4 then
		return nil
	end
	local distance = (roomCFrame.Position - ray.Origin):Dot(facing) / along
	if distance <= 0 then
		return nil
	end
	return ray.Origin + ray.Direction * distance
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Placement.new(hud)
	local self = setmetatable({}, Placement)
	self.hud = hud
	self.selected = nil -- weapon id picked from the menu
	self.ghost = nil -- see-through preview that follows the mouse
	self.press = nil -- the item you're currently clicking or dragging

	UserInputService.InputBegan:Connect(function(input, processed)
		self:_onInputBegan(input, processed)
	end)
	UserInputService.InputChanged:Connect(function(input)
		self:_onInputChanged(input)
	end)
	UserInputService.InputEnded:Connect(function(input)
		self:_onInputEnded(input)
	end)
	RunService.RenderStepped:Connect(function()
		self:_updateGhost()
	end)

	local function stopIfNotPlaying()
		if not activeRoom() then
			self:cancel()
			self.press = nil
		end
	end
	Remotes.GameState:GetAttributeChangedSignal("Phase"):Connect(stopIfNotPlaying)
	player:GetAttributeChangedSignal("Room"):Connect(stopIfNotPlaying)
	return self
end

-- Called when a weapon button is pressed. Pressing it again cancels.
function Placement:toggle(weaponId)
	if self.selected == weaponId then
		self:cancel()
		return
	end
	self:cancel()
	if not activeRoom() then
		return
	end
	self.selected = weaponId

	local ghost = ItemModels.build(weaponId)
	for _, part in ghost:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 1 - (1 - part.Transparency) * 0.5
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	self.ghost = ghost
	self.hud:setSelected(weaponId)
end

function Placement:cancel()
	if self.ghost then
		self.ghost:Destroy()
		self.ghost = nil
	end
	if self.selected then
		self.selected = nil
		self.hud:setSelected(nil)
	end
end

function Placement:_updateGhost()
	local ghost, room = self.ghost, activeRoom()
	if not ghost then
		return
	end
	if not room then
		self:cancel() -- a run started
		return
	end
	-- Touch screens can't hover, so they don't get a preview
	if not UserInputService.MouseEnabled then
		ghost.Parent = nil
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local point = pointInRoom(Workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y), room)
	if not point then
		ghost.Parent = nil
		return
	end
	local weapon = Weapons.byId[self.selected]
	ghost:PivotTo(Config.placementFor(room, weapon, point))
	ghost.Parent = Workspace
end

-- The placed item under the mouse/finger, if any
function Placement:_findItem(ray, room)
	local roomsFolder = Workspace:FindFirstChild("Rooms")
	local roomModel = roomsFolder and roomsFolder:FindFirstChild("Room" .. room)
	local items = roomModel and roomModel:FindFirstChild("Items")
	if not items then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { items }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if not result then
		return nil
	end
	local model = result.Instance
	while model and model.Parent ~= items do
		model = model.Parent
	end
	return model
end

function Placement:_onInputBegan(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		self:cancel() -- right-click cancels
		return
	end
	-- `processed` is true when you clicked a button on screen, not the room
	if processed or not isPress(input) then
		return
	end
	local room = activeRoom()
	if not room then
		return
	end
	local ray = screenRay(input.Position)

	if self.selected then
		local point = pointInRoom(ray, room)
		if point then
			Remotes.PlaceItem:FireServer(self.selected, point)
			self:cancel()
		end
		return
	end

	local model = self:_findItem(ray, room)
	if model then
		self.press = {
			input = input,
			model = model,
			start = Vector2.new(input.Position.X, input.Position.Y),
			dragging = false,
			lastSent = 0,
		}
	end
end

function Placement:_onInputChanged(input)
	local press = self.press
	if not press then
		return
	end
	local isMouseDrag = input.UserInputType == Enum.UserInputType.MouseMovement
		and press.input.UserInputType == Enum.UserInputType.MouseButton1
	if not isMouseDrag and input ~= press.input then
		return
	end
	local room = activeRoom()
	if not room or not press.model.Parent then
		self.press = nil
		return
	end

	local screen = Vector2.new(input.Position.X, input.Position.Y)
	if not press.dragging then
		if (screen - press.start).Magnitude < DRAG_THRESHOLD then
			return
		end
		press.dragging = true
		self.hud:flashHint(("Drag it into the 🗑️ trash can to sell it for %s."):format(Config.formatCash(sellValue(press.model))))
	end

	-- Over the trash can: light it up, and leave the weapon where it was
	local weapon = Weapons.byId[press.model.Name]
	local overTrash = self.hud:isOverTrash(input)
	self.hud:setTrashHover(overTrash, sellValue(press.model))
	if overTrash then
		return
	end

	local point = pointInRoom(screenRay(input.Position), room)
	if not point then
		return
	end
	press.point = point
	-- Move it on our screen right away so dragging feels smooth; the server catches up
	-- (and works out the same spot: snapped to a surface, or kept inside the room)
	local placement = Config.placementFor(room, weapon, point)
	local rotation = if weapon.anySurface then placement.Rotation else press.model:GetPivot().Rotation
	press.model:PivotTo(CFrame.new(placement.Position) * rotation)
	if os.clock() - press.lastSent >= MOVE_SEND_INTERVAL then
		press.lastSent = os.clock()
		Remotes.MoveItem:FireServer(press.model:GetAttribute("ItemId"), point)
	end
end

function Placement:_onInputEnded(input)
	local press = self.press
	if not press then
		return
	end
	local matches = if press.input.UserInputType == Enum.UserInputType.Touch
		then input == press.input
		else input.UserInputType == Enum.UserInputType.MouseButton1
	if not matches then
		return
	end
	self.press = nil
	if not press.dragging then
		return
	end

	local itemId = press.model:GetAttribute("ItemId")
	self.hud:setTrashHover(false)
	if self.hud:isOverTrash(input) then
		Remotes.RemoveItem:FireServer(itemId)
		press.model.Parent = nil -- hide it right away; the server removes it for real
	elseif press.point then
		Remotes.MoveItem:FireServer(itemId, press.point)
	end
end

return Placement
