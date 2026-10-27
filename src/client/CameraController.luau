-- During a round, locks the camera to a straight-on side view of your room (or the
-- room you're spectating), like the original game. In the lobby you get the normal
-- Roblox camera back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Layout = require(script.Parent.Layout)

local player = Players.LocalPlayer

-- A narrow field of view makes the room look flat, like the 2D original,
-- while still showing a sliver of the side walls, floor and ceiling
local ROOM_FOV = 25
local DEFAULT_FOV = 70

local CameraController = {}

-- The room to look at (and whether we're just spectating it), or nil while in the lobby
local function roomToShow()
	local phase = Remotes.GameState:GetAttribute("Phase")
	local room = player:GetAttribute("Room")
	if room and room > 0 and (phase == "Round" or phase == "Results") then
		return room, false
	end
	local watching = player:GetAttribute("Spectating")
	if watching and watching > 0 and phase == "Round" then
		return watching, true
	end
	return nil, false
end

-- Places the camera straight in front of the room so the room's open front
-- exactly fills the space between the menus (see Layout)
local function roomView(room, viewport, spectating)
	local area = if spectating then Layout.getSpectator(viewport) else Layout.get(viewport).room
	local size = Config.ROOM_SIZE
	local tanHalf = math.tan(math.rad(ROOM_FOV / 2))

	-- How far back the camera must be for the room to fit the area's height and width
	local fitHeight = size.Y * viewport.Y / (2 * tanHalf * area.height)
	local fitWidth = size.X * viewport.Y / (2 * tanHalf * area.width)
	local distance = math.max(fitHeight, fitWidth)
	local pixelsPerStud = viewport.Y / (2 * tanHalf * distance)

	-- The area isn't in the middle of the screen (the side panel is on the right),
	-- so slide the camera sideways/up instead of turning it, which keeps the view flat
	local shiftX = (area.x + area.width / 2) - viewport.X / 2
	local shiftY = (area.y + area.height / 2) - viewport.Y / 2
	-- In the room's own directions (+Z comes out of its open front), so this works
	-- whichever way round the ring the room faces
	local offset = Vector3.new(-shiftX / pixelsPerStud, size.Y / 2 + shiftY / pixelsPerStud, size.Z / 2 + distance)
	return Config.getRoomCFrame(room) * CFrame.new(offset) -- looking straight into the room
end

function CameraController.start()
	-- Lets us turn off walking while you're watching your room
	local ok, playerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	local controls = if ok then playerModule:GetControls() else nil

	local inRoom = false
	RunService:BindToRenderStep("RoomCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = Workspace.CurrentCamera
		local room, spectating = roomToShow()
		if room then
			if not inRoom then
				inRoom = true
				if controls then
					controls:Disable()
				end
			end
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = ROOM_FOV
			camera.CFrame = roomView(room, camera.ViewportSize, spectating)
		elseif inRoom then
			inRoom = false
			if controls then
				controls:Enable()
			end
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = DEFAULT_FOV
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end)
end

return CameraController
