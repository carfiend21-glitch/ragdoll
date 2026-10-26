-- Every sound in the game. They all come from Roblox's free sound library
-- (Roblox, ProSoundEffects and APMOfficial), so they work in any game.
-- `volume` is kept gentle on purpose, and `vary` randomly nudges the pitch a little
-- each time so repeated sounds (like the machine gun) don't get grating.
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

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
	-- Grenade: it clatters as it's dropped in, the pin pings out, then a sharp crack
	-- with bits of shrapnel whizzing past
	GrenadeDrop = { id = 9114659492, volume = 0.6, vary = 0.06 }, -- "Grenade Across Floor 1"
	PinPull = { id = 9114659662, volume = 0.6, vary = 0.05 },
	GrenadeBlast = { id = 9119236749, volume = 0.8, vary = 0.06, lifetime = 5 }, -- "Small Explosion 1"
	Shrapnel = { id = 9119122634, volume = 0.5, vary = 0.1 }, -- "Shrapnel Whiz 1"
	-- A sparkler's crackle, cut off when the Big TNT's 2.5 second fuse runs out
	FuseHiss = { id = 9119380593, volume = 0.4, vary = 0.05, lifetime = 2.6 },
	GunShot = { id = 9114729252, volume = 0.25, vary = 0.12 },
	-- Spinning saw: a steady whir while it spins, and sharp grating bites as it cuts
	SawSpin = { id = 9116635675, volume = 0.25, vary = 0 }, -- "Metal Grind 1" (gentle), looped
	SawCut1 = { id = 9118775692, volume = 0.6, vary = 0.1 }, -- "Saw Blade Sharp 1"
	SawCut2 = { id = 9118775709, volume = 0.6, vary = 0.1 }, -- "Saw Blade Sharp 2"
	FlameBurst = { id = 9114446277, volume = 0.55, vary = 0.08 },
	-- The classic sci-fi "pew": a sharp laser shot that drops in pitch
	LaserShot = { id = 9116226117, volume = 0.6, vary = 0.06 }, -- "Laser Blast 1001"
	RocketLaunch = { id = 12222065, volume = 0.5, vary = 0.08 },
	BigBoom = { id = 9114224354, volume = 0.6, vary = 0.05, lifetime = 7 },
	-- The noob
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
	-- During a round: a focused, ticking game-show bed (marimba, strings, shaker) that
	-- says "the clock is running" without being scary. 99 seconds, about one round long.
	RoundMusic = { id = 9042796310, volume = 0.45, vary = 0 }, -- "Cutting It Close" (APM)
}

-- Room sounds can be heard from your own room's camera, but fade out before the
-- next room over, so you don't hear other players' rooms (or the rooms from the lobby)
local HEARING_FULL = 90
local HEARING_MAX = 118

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
function Sounds.playAt(name, position, volumeScale)
	local sound, info = newSound(name)
	sound.Volume *= volumeScale or 1
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = HEARING_FULL
	sound.RollOffMaxDistance = HEARING_MAX
	local spot = Instance.new("Attachment")
	spot.Name = "Sound"
	spot.Parent = Workspace.Terrain
	spot.WorldPosition = position
	sound.Parent = spot
	sound:Play()
	task.delay(info.lifetime or 4, function()
		spot:Destroy()
	end)
end

-- A looping sound stuck to a part (like a saw's whir), heard like Sounds.playAt.
-- Starts stopped: set .Playing to turn it on and off.
function Sounds.newLoop(name, part)
	local sound = newSound(name)
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = HEARING_FULL
	sound.RollOffMaxDistance = HEARING_MAX
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
