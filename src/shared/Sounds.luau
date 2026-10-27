-- Every sound in the game. They all come from Roblox's free sound library
-- (Roblox, ProSoundEffects and APMOfficial), so they work in any game.
-- `volume` is kept gentle on purpose, and `vary` randomly nudges the pitch a little
-- each time so repeated sounds (like the machine gun) don't get grating.
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local Sounds = {}

Sounds.LIST = {
	-- Weapons
	-- Arrows sound like a Minecraft bow: a light "fwip" when fired (no crossbow clunk),
	-- a soft thunk into the noob, and a sharper "tk" into the wall. (Minecraft's own sounds
	-- belong to Mojang and can't be used, so these are the closest free library sounds.)
	ArrowShot = { id = 9113166206, volume = 0.5, vary = 0.1 }, -- "Arrow Out Whooshing Pass By 1"
	ArrowHit = { id = 9113165572, volume = 0.7, vary = 0.1 }, -- "Arrow In Landing In Mud 14"
	ArrowWall = { id = 9113161406, volume = 0.4, vary = 0.1 }, -- "Arrow In And Hit 13"
	Spring = { id = 12222124, volume = 0.6, vary = 0.08 },
	-- Land mine: the classic "click... BOOM". A metal click as it's armed and when it's
	-- stepped on, then a deep blast that throws up dirt.
	MineClick = { id = 9116543627, volume = 0.7, vary = 0.04 }, -- "Metal Click 1"
	MineBlast = { id = 9114086405, volume = 0.8, vary = 0.06, lifetime = 5 }, -- "Dirt Explosion 1"
	-- Grenade: it clatters as it's dropped in, the pin pings out, it beeps faster and
	-- faster (and a little higher) as the fuse runs down, then a big heavy boom with
	-- bits of shrapnel whizzing past
	GrenadeDrop = { id = 9114659492, volume = 0.6, vary = 0.06 }, -- "Grenade Across Floor 1"
	PinPull = { id = 9114659662, volume = 0.6, vary = 0.05 },
	GrenadeBeep = { id = 9117060347, volume = 0.55, vary = 0, lifetime = 0.5 }, -- "Nasa Transmission Beep 1" (short clean tone)
	GrenadeBlast = { id = 9117876706, volume = 0.85, vary = 0.05, lifetime = 6.5 }, -- "Power Explosions Big Heavy Searing Boom 2"
	Shrapnel = { id = 9119122634, volume = 0.5, vary = 0.1 }, -- "Shrapnel Whiz 1"
	-- A sparkler's crackle, cut off when the Big TNT's 2.5 second fuse runs out
	FuseHiss = { id = 9119380593, volume = 0.4, vary = 0.05, lifetime = 2.6 },
	GunShot = { id = 9114729252, volume = 0.25, vary = 0.12 },
	-- Spinning saw: a steady whir while it spins, and sharp grating bites as it cuts
	SawSpin = { id = 9116635675, volume = 0.25, vary = 0 }, -- "Metal Grind 1" (gentle), looped
	SawCut1 = { id = 9118775692, volume = 0.6, vary = 0.1 }, -- "Saw Blade Sharp 1"
	SawCut2 = { id = 9118775709, volume = 0.6, vary = 0.1 }, -- "Saw Blade Sharp 2"
	FlameBurst = { id = 9114446277, volume = 0.55, vary = 0.08 },
	-- Laser cannon: the most-favorited laser sound on all of Roblox. It's a player's
	-- upload (public since 2020), not from the official libraries like the rest.
	LaserShot = { id = 4571098531, volume = 0.7, vary = 0.05 }, -- "Laser Beam Sound Effect"
	RocketLaunch = { id = 12222065, volume = 0.5, vary = 0.08 },
	BigBoom = { id = 9114224354, volume = 0.6, vary = 0.05, lifetime = 7 },
	-- The noob
	-- The noob crashing into things: a different sound for each surface (see Arena)
	FloorHit = { id = 9113470969, volume = 0.65, vary = 0.1 }, -- "Body Fall Heavy Rustle 3" (on concrete)
	WallHit = { id = 9113535217, volume = 0.65, vary = 0.1 }, -- "Body Slam Low End Thump 2"
	CeilingHit = { id = 9113535176, volume = 0.6, vary = 0.1 }, -- "Body Slam Low End Thump 1"
	Thud = { id = 9113480915, volume = 0.5, vary = 0.15 },
	BodyImpact = { id = 9113525391, volume = 0.5, vary = 0.12 },
	Punch = { id = 9117969687, volume = 0.45, vary = 0.12 },
	Splat = { id = 12222152, volume = 0.6, vary = 0.1 },
	WetSplat = { id = 9113663393, volume = 0.5, vary = 0.1 },
	-- Placing weapons
	Place = { id = 9125665716, volume = 0.4, vary = 0.08 },
	-- Menus and the round
	Click = { id = 15675059323, volume = 0.5, vary = 0.04 },
	Cash = { id = 9113728042, volume = 0.4, vary = 0.03 },
	Achievement = { id = 9116394545, volume = 0.6, vary = 0 },
	Sparkle = { id = 9126073001, volume = 0.35, vary = 0.05 },
	Play = { id = 9118113825, volume = 0.35, vary = 0 },
	Stop = { id = 9125626478, volume = 0.4, vary = 0.03 },
	Restart = { id = 1846544949, volume = 0.4, vary = 0 },
	RoundStart = { id = 9117261163, volume = 0.4, vary = 0 },
	RoundEnd = { id = 1847237532, volume = 0.45, vary = 0 },
	Winner = { id = 1844584698, volume = 0.5, vary = 0 },
	Beep = { id = 9117060347, volume = 0.3, vary = 0 },
	-- Music
	LobbyMusic = { id = 9043887091, volume = 0.3, vary = 0 }, -- "Lo-fi Chill A"
	-- During a round: "Heist Time" (picked by the user), from 55 seconds in.
	-- `startAt` = where in the song it starts. ("Deadly Heist Clock Ticking" is only the
	-- clock layer of a song, so it is just fast ticks on top for the last 15 seconds.)
	RoundMusic = { id = 1837463238, volume = 0.5, vary = 0, startAt = 55 }, -- "Heist Time" (APM)
	FinalTicks = { id = 1835342628, volume = 0.3, vary = 0 }, -- "Deadly Heist Clock Ticking Double Time" (APM)
}

-- Room sounds can be heard all the way from a room's camera (about 80-100 studs out
-- in front of it, across the lobby)
local HEARING_FULL = 100
local HEARING_MAX = 110
-- How loud the rooms are while you're in the lobby (they're all around it)
local LOBBY_ROOM_VOLUME = 0.25

-- Every room has its own sound group ("RoomSounds3" for room 3), so each player's
-- screen can play only the room they're watching: the rooms all face the lobby, so a
-- room's camera is just as close to the other rooms as to its own.
-- Sounds that aren't in a room go in "RoomSounds".
local function soundGroup(name)
	local group = SoundService:FindFirstChild(name)
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	return group
end

local function roomSoundGroup(position)
	local room = Config.roomAt(position)
	return soundGroup(if room then "RoomSounds" .. room else "RoomSounds")
end

-- Which room's sounds this player hears: `watching` = the room number they're
-- playing in or spectating, or nil in the lobby (then every room plays quietly).
-- Players' devices only (changing it there only changes it for that player).
function Sounds.setRoomSounds(watching)
	for room = 1, Config.ROOM_COUNT do
		local group = SoundService:FindFirstChild("RoomSounds" .. room)
		if group then
			group.Volume = if watching == nil then LOBBY_ROOM_VOLUME elseif watching == room then 1 else 0
		end
	end
end
-- The server makes the groups straight away, so they're there for everyone
if RunService:IsServer() then
	soundGroup("RoomSounds")
	for room = 1, Config.ROOM_COUNT do
		soundGroup("RoomSounds" .. room)
	end
end

local function newSound(name)
	local info = Sounds.LIST[name]
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. info.id
	sound.Volume = info.volume
	sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * info.vary
	return sound, info
end

-- Plays a sound at a spot in the world (heard by anyone close enough).
-- `volumeScale` makes it quieter or louder, e.g. for small vs big crashes.
-- Returns the Sound, in case it needs stopping early.
function Sounds.playAt(name, position, volumeScale)
	local sound, info = newSound(name)
	sound.Volume *= volumeScale or 1
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = HEARING_FULL
	sound.RollOffMaxDistance = HEARING_MAX
	sound.SoundGroup = roomSoundGroup(position)
	local spot = Instance.new("Attachment")
	spot.Name = "Sound"
	spot.Parent = Workspace.Terrain
	spot.WorldPosition = position
	sound.Parent = spot
	sound:Play()
	task.delay(info.lifetime or 4, function()
		spot:Destroy()
	end)
	return sound
end

-- A looping sound stuck to a part (like a saw's whir), heard like Sounds.playAt.
-- Starts stopped: set .Playing to turn it on and off.
function Sounds.newLoop(name, part)
	local sound = newSound(name)
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = HEARING_FULL
	sound.RollOffMaxDistance = HEARING_MAX
	sound.SoundGroup = roomSoundGroup(part.Position)
	sound.Parent = part
	return sound
end

-- Plays a sound just for you, at the same volume wherever you are (menus, music cues)
local uiSounds = {}
function Sounds.playUI(name)
	local sound = uiSounds[name]
	if not sound then
		sound = newSound(name)
		sound.Parent = SoundService
		uiSounds[name] = sound
	end
	local info = Sounds.LIST[name]
	sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * info.vary
	SoundService:PlayLocalSound(sound)
end

-- A looping sound for background music
function Sounds.newMusic(name)
	local sound = newSound(name)
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	return sound
end

return Sounds
