# Remakes the Noob Buck pictures in images/developer-products (the logo and the five
# pack pictures you upload for the Developer Products on the Creator Dashboard).
# The noob is drawn from the same model as the game: the same body parts, sizes and
# colors as src/server/Noob.luau, with Roblox's own classic head and smiley face
# (read from your Roblox Studio install).
# Run it in PowerShell from the project folder:  .\tools\make-noob-buck-images.ps1
$root = Split-Path $PSScriptRoot -Parent
$studio = Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Directory |
    Where-Object { Test-Path "$($_.FullName)\content\avatar\heads\head.mesh" } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $studio) { throw "Couldn't find Roblox Studio (it has the noob's head and face)." }
$content = "$($studio.FullName)\content"
Add-Type -Path "$PSScriptRoot\NoobBuckArt.cs" -ReferencedAssemblies System.Drawing

# The camera looks at the noob's chest from slightly to one side, like the logo in the game
$look = @(0.0, 0.75, 0.0)
$dir = @(0.24, 0.13, -0.96)
$dist = 7.5
$from = @(($look[0] + $dir[0] * $dist), ($look[1] + $dir[1] * $dist), ($look[2] + $dir[2] * $dist))
$noob = [NoobBuckArt]::RenderNoob("$content\avatar\heads\head.mesh", "$content\textures\face.png", 500, $from, $look, 30.0)

$out = "$root\images\developer-products"
[NoobBuckArt]::Logo($noob, "$out\noob-buck-logo.png")
# Pack size = how many bills are in the pile
$packs = @{ 5 = 2; 10 = 3; 25 = 4; 50 = 5; 100 = 6 }
foreach ($bucks in $packs.Keys) {
    [NoobBuckArt]::Pack($noob, $bucks, $packs[$bucks], "$out\noob-bucks-x$bucks.png")
}
Write-Output "Done! The pictures are in $out"
