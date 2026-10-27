-- Noob Bucks: a saved currency. The winner of each round earns some, and they can
-- also be bought with Robux in packs. (What they buy is still to be decided.)
local NoobBucks = {}

-- How many the winner of a round gets (everyone tied for first gets them)
NoobBucks.WIN_REWARD = 1

-- Robux packs. `productId` = the Developer Product that sells it. 0 means "not set up
-- yet": create a Developer Product for each pack on the Creator Dashboard
-- (your game > Monetization > Developer Products), then paste its ID here.
-- `robux` is only the suggested price shown in the menu: the real price is whatever
-- you set on the Dashboard, so keep the two the same. Bigger packs are a better deal.
NoobBucks.PACKS = {
	{ bucks = 5, robux = 25, productId = 0 },
	{ bucks = 10, robux = 45, productId = 0 },
	{ bucks = 25, robux = 99, productId = 0 },
	{ bucks = 50, robux = 179, productId = 0 },
	{ bucks = 100, robux = 329, productId = 0, best = true },
}

NoobBucks.byProductId = {}
for _, pack in NoobBucks.PACKS do
	if pack.productId > 0 then
		NoobBucks.byProductId[pack.productId] = pack
	end
end

return NoobBucks
