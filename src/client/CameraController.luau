-- During a round, locks the camera to a straight-on side view of your room,
-- like the original game. In the lobby you get the normal Roblox camera back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

-- A narrow field of view makes the room look flat, like a 2D game
local ROOM_FOV = 40
local DEFAULT_FOV = 70

local CameraController = {}

-- The room to look at, or nil while in the lobby
local function roomToShow()
	local room = player:GetAttribute("Room")
	local phase = Remotes.GameState:GetAttribute("Phase")
	if room and room > 0 and (phase == "Round" or phase == "Results") then
		return room
	end
	return nil
end

-- Pulls the camera back just far enough to fit the whole room on screen
local function roomView(room, viewport)
	local origin = Config.getRoomOrigin(room)
	local size = Config.ROOM_SIZE
	local tanHalf = math.tan(math.rad(ROOM_FOV / 2))
	local aspect = viewport.X / math.max(viewport.Y, 1)
	-- Extra room at the top and bottom of the screen for the menus
	local fitHeight = (size.Y * 0.5 * 1.3) / tanHalf
	local fitWidth = (size.X * 0.5 * 1.05) / (tanHalf * aspect)
	local distance = math.max(fitHeight, fitWidth) + size.Z / 2
	local target = origin + Vector3.new(0, size.Y / 2 - 1.5, 0)
	return CFrame.lookAt(target + Vector3.new(0, 0, distance), target)
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
		local room = roomToShow()
		if room then
			if not inRoom then
				inRoom = true
				if controls then
					controls:Disable()
				end
			end
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = ROOM_FOV
			camera.CFrame = roomView(room, camera.ViewportSize)
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
