-- Where everything goes on screen during a round, laid out like the original game:
-- a top bar, an orange bottom bar, a task/achievement panel on the right, and the room
-- filling exactly the space left over. The camera and the HUD both use this,
-- so the room's walls line up with the edges of the menus.
local GuiService = game:GetService("GuiService")

local Layout = {}

-- Sizes the bars are designed at; on small screens they shrink
Layout.TOP_BAR = 44
Layout.BOTTOM_BAR = 100

-- All numbers are in pixels from the top-left corner of the whole screen
function Layout.get(viewport)
	local scale = if viewport.Y < 600 then 0.72 else 1
	local inset = GuiService:GetGuiInset().Y -- Roblox's own buttons along the top
	local topBar = math.floor(Layout.TOP_BAR * scale)
	local bottomBar = math.floor(Layout.BOTTOM_BAR * scale)
	local sidePanel = math.clamp(math.floor(viewport.X * 0.2), 170, 300)
	return {
		scale = scale,
		inset = inset,
		topBar = topBar,
		bottomBar = bottomBar,
		sidePanel = sidePanel,
		room = {
			x = 0,
			y = inset + topBar,
			width = viewport.X - sidePanel,
			height = viewport.Y - inset - topBar - bottomBar,
		},
	}
end

-- While spectating there's no side panel or weapon bar, just a strip at the top
-- (who you're watching) and the arrows at the bottom
function Layout.getSpectator(viewport)
	local inset = GuiService:GetGuiInset().Y
	local top, bottom = 64, 90
	return { x = 0, y = inset + top, width = viewport.X, height = viewport.Y - inset - top - bottom }
end

return Layout
