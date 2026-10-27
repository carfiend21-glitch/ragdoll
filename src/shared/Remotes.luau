-- The "phone lines" between the server and players' devices.
-- The server creates them; players' devices wait for them to appear.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- player -> server
	"PlaceItem",
	"MoveItem",
	"RemoveItem",
	"SetRunning",
	"Restart",
	"Spectate",
	"BuyShopItem",
	"EquipShopItem",
	-- server -> player
	"DataSync",
	"AchievementUnlocked",
	"HitFx",
	"Results",
	"Notify",
	"Hint",
	"ReplayReset",
	"ReplayChunk",
	"ReplayPick",
}
local FUNCTIONS = { "GetData" }

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	-- Round info lives in attributes on this folder: Phase and TimeLeft
	local state = Instance.new("Folder")
	state.Name = "GameState"
	state:SetAttribute("Phase", "Waiting")
	state:SetAttribute("TimeLeft", 0)
	state.Parent = folder
	Remotes.GameState = state
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in EVENTS do
		Remotes[name] = folder:WaitForChild(name)
	end
	for _, name in FUNCTIONS do
		Remotes[name] = folder:WaitForChild(name)
	end
	Remotes.GameState = folder:WaitForChild("GameState")
end

return Remotes
