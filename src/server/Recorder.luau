-- Records a room during a round so everyone can watch it back afterwards.
-- Ten times a second it takes a snapshot of where every body part and weapon is.
-- It also notes explosions and the running damage total, for the replay's counter.
-- Everything is stored relative to the room, so the replay can draw it anywhere.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Recorder = {}
Recorder.__index = Recorder

function Recorder.new(arena)
	local self = setmetatable({}, Recorder)
	self.arena = arena
	self.recording = false
	self:reset()
	return self
end

function Recorder:reset()
	self.frames = {} -- { t = seconds, noob = { CFrame x6 }, items = { { id, weaponId, CFrame } } }
	self.events = {} -- { t = seconds, kind = "damage" | "boom", ... }
	self.framesSent = 0
	self.eventsSent = 0
	self.startTime = os.clock()
	self.nextSample = 0
end

function Recorder:start()
	self:reset()
	self.recording = true
end

function Recorder:stop()
	self.recording = false
end

function Recorder:_time()
	return os.clock() - self.startTime
end

-- How long the recording is, in seconds
function Recorder:duration()
	local last = self.frames[#self.frames]
	return if last then last.t else 0
end

-- Called every frame; takes a snapshot when it's time for the next one
function Recorder:step()
	if not self.recording then
		return
	end
	local t = self:_time()
	if t < self.nextSample then
		return
	end
	self.nextSample = t + 1 / Config.REPLAY_SAMPLE_RATE

	-- Stored in the room's own directions, so the replay can draw the room facing any way
	local origin = self.arena.roomCFrame
	local noob = {}
	for index, part in self.arena.noob.parts do
		noob[index] = origin:ToObjectSpace(part.CFrame)
	end
	local items = {}
	for id, item in self.arena.items do
		if item.model.Parent then
			-- (4th: how big it is, only while it isn't full size, like a shrinking black hole)
			local scale = item.model:GetScale()
			table.insert(items, { id, item.weapon.id, origin:ToObjectSpace(item.model:GetPivot()), if scale ~= 1 then scale else nil })
		end
	end
	-- Arrows and rockets in flight (and arrows stuck in the walls): { "Arrow" or "Rocket", CFrame }
	local projectiles = {}
	for _, projectile in self.arena.projectilesFolder:GetChildren() do
		table.insert(projectiles, { projectile.Name, origin:ToObjectSpace(projectile:GetPivot()) })
	end
	-- `n` numbers the snapshots, so players' devices can put the pieces back in order
	table.insert(self.frames, { n = #self.frames + 1, t = t, noob = noob, items = items, projectiles = projectiles })
end

-- Notes something that happened, with any details in `fields`. Kinds:
--   "damage" { damage = new total }      "hit" { position, points (score), damage (real), part }
--   "boom" { position, radius }           "arrow" { part = body part number, offset = CFrame }
--   "torn" { part = body part number }    "play" / "pause" / "restart"
--   "nuke" { position }                   "radiation" (the room glows for the rest of the round)
--   "swallow" { position } (the black hole swallowed the noob)
-- Positions (`position`, `target`) and directions are given in the world and stored in
-- the room's own directions.
function Recorder:event(kind, fields)
	if not self.recording then
		return
	end
	local event = fields or {}
	event.n = #self.events + 1
	event.t = self:_time()
	event.kind = kind
	local room = self.arena.roomCFrame
	if event.position then
		event.position = room:PointToObjectSpace(event.position)
	end
	if event.target then
		event.target = room:PointToObjectSpace(event.target)
	end
	if event.direction then
		event.direction = room:VectorToObjectSpace(event.direction)
	end
	table.insert(self.events, event)
end

-- Everything recorded since the last call (sent to players a bit at a time,
-- so there's no huge download when the round ends)
function Recorder:takeNew()
	local frames = table.move(self.frames, self.framesSent + 1, #self.frames, 1, {})
	local events = table.move(self.events, self.eventsSent + 1, #self.events, 1, {})
	self.framesSent = #self.frames
	self.eventsSent = #self.events
	return frames, events
end

return Recorder
