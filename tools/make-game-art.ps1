# Remakes the thumbnails (images/thumbnails), the game icon (images/icon) and the Game
# Pass / Developer Product pictures (images/game-passes, images/developer-products).
# The noob and the weapons are drawn from the same shapes as the game, with Roblox
# Studio's own head and face. Run it in PowerShell from the project folder:
#   .\tools\make-game-art.ps1
$root = Split-Path $PSScriptRoot -Parent
$studio = Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Directory |
    Where-Object { Test-Path "$($_.FullName)\content\avatar\heads\head.mesh" } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $studio) { throw "Couldn't find Roblox Studio (it has the noob's head and face)." }
$content = "$($studio.FullName)\content"
Add-Type -Path "$PSScriptRoot\GameArt.cs", "$PSScriptRoot\GameArtScenes.cs" -ReferencedAssemblies System.Drawing
[GameArtScenes]::MakeAll("$content\avatar\heads\head.mesh", "$content\textures\face.png", $root)
Write-Output "Done! Look in $root\images"
