-- Starting point on each player's device: camera, on-screen menus and
-- placing weapons.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local CameraController = require(script.Parent.CameraController)
local Hud = require(script.Parent.Hud)
local Placement = require(script.Parent.Placement)

local hud = Hud.new()
local placement = Placement.new(hud)
hud.onWeaponClicked = function(weaponId)
	placement:toggle(weaponId)
end
CameraController.start()

Remotes.DataSync.OnClientEvent:Connect(function(achievementIds)
	hud:setAchievements(achievementIds)
end)
Remotes.AchievementUnlocked.OnClientEvent:Connect(function(id, weaponIds)
	hud:showAchievement(id, weaponIds)
end)
Remotes.HitFx.OnClientEvent:Connect(function(points, position, combo)
	hud:showHit(points, position, combo)
end)
Remotes.Results.OnClientEvent:Connect(function(results)
	hud:showResults(results)
end)

hud:setAchievements(Remotes.GetData:InvokeServer())
