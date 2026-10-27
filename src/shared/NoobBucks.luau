-- Noob Bucks: a saved currency. The winner of each round earns some, and they can
-- also be bought with Robux in packs. (What they buy is still to be decided.)
local NoobBucks = {}

-- How many the winner of a round gets (everyone tied for first gets them)
NoobBucks.WIN_REWARD = 1
-- What the player voted "best sequence of attacks" (out of the top 3) gets
NoobBucks.VOTE_REWARD = 1

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

-- 2x Noob Bucks: winning a round and being voted best sequence give double Noob Bucks.
-- (Only Noob Bucks: the cash you spend in a round is never doubled.)
-- The Game Pass is forever; the Developer Product lasts 1 hour (real time) and buying it
-- again adds another hour. They don't stack: someone with the pass is already at 2x.
-- `gamePassId` / `productId` = 0 means "not set up yet" (paste the IDs from the Creator
-- Dashboard). `robux` is only the suggested price shown in the shop.
NoobBucks.DOUBLE_PASS = { gamePassId = 0, robux = 199 }
NoobBucks.BOOST = { productId = 0, robux = 25, seconds = 60 * 60 }

-- How many times over Noob Buck rewards count: 2 with the pass or a boost running, else 1.
-- `boostUntil` = when the boost runs out (os.time()), `now` = os.time()
function NoobBucks.multiplier(hasPass, boostUntil, now)
	return if hasPass or (boostUntil or 0) > now then 2 else 1
end

NoobBucks.byProductId = {}
for _, pack in NoobBucks.PACKS do
	if pack.productId > 0 then
		NoobBucks.byProductId[pack.productId] = pack
	end
end

return NoobBucks
