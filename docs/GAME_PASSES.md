# Game Pass plan

This is a plan only. None of these passes exist yet, and none are built in code except the
weapon passes, which already have a `gamePassId` slot in `src/shared/Weapons.luau`.

**The rule for every pass:** it must never let someone win a round just by paying. Rounds
are won by damage, and everyone starts with the same cash. So passes give **choice**
(new weapons, priced fairly in round cash), **speed** (more Noob Bucks) or **looks**,
never extra cash, extra weapon slots or stronger weapons.

## 1. Weapon passes (code ready: just paste the pass IDs)

Each one unlocks a weapon forever. They can also be unlocked with Noob Bucks in the shop,
so free players can get them too. The Robux price is a little cheaper than buying the same
Noob Bucks, so the pass feels like the "real" deal.

| Pass | Suggested price | Notes |
| --- | --- | --- |
| Gravity Flipper | (no pass) | Noob Bucks only |
| Freeze Ray | (no pass) | Noob Bucks only |
| Acid Blaster | (no pass) | Noob Bucks only |
| Storm Cloud | (no pass) | Noob Bucks only |
| Ban Hammer | (no pass) | Noob Bucks only |
| Railgun | (no pass) | Noob Bucks only |
| Minigun | (no pass) | Noob Bucks only |
| Missile Swarm | (no pass) | Noob Bucks only |
| Black Hole | R$ 299 | **Robux only** (see below) |
| Mini Nuke | R$ 399 | **Robux only** (see below), the "flex" one |
| Rocket Launcher | (no pass) | Noob Bucks only (35) |
| Grenade (early) | R$ 25 | Already in the game (skip the achievement) |

## 2x Noob Bucks (code ready: just paste the IDs)

Doubles the Noob Bucks you get for **winning a round** and for being **voted best sequence**
(1 becomes 2). It never doubles the cash you spend inside a round.

| What | Suggested price | Type | Where the ID goes |
| --- | --- | --- | --- |
| 2x Noob Bucks forever | R$ 499 (set) | Game Pass | `NoobBucks.DOUBLE_PASS.gamePassId` in `src/shared/NoobBucks.luau` |
| 2x Noob Bucks for 1 hour | R$ 99 (set) | Developer Product | `NoobBucks.BOOST.productId` in the same file |

The 1-hour boost counts real time (it keeps ticking even if you leave), and buying it again
adds another hour. Players who own the pass can't buy the boost (they're already at 2x).

## Noob Buck packs (set)

| Pack | Price |
| --- | --- |
| 5 | R$ 25 |
| 10 | R$ 50 |
| 25 | R$ 150 |
| 50 | R$ 350 |
| 100 | R$ 700 |

## Black Hole and Mini Nuke: Robux-only price plan

These two are the strongest weapons in the game, so they're the only exclusives you can't buy
with Noob Bucks. Their round price stays fair ($210 and $250 in round cash, the most
expensive on the bar), so buying them gives a fun, flashy weapon, not a free win.

| Way to get it | Black Hole | Mini Nuke | Notes |
| --- | --- | --- | --- |
| **Game Pass (forever)** | **R$ 299** | **R$ 399** | The main way to buy them. Code ready: paste the pass IDs into `gamePassId`. |
| 1-round trial (Noob Bucks) | 💵 7 | 💵 9 | A cheap taste that makes people want the pass. Already in the shop. |
| "Doomsday Duo" pass (both) | R$ 599 together (save R$ 99) | | Optional; needs a little code (one pass unlocking two weapons). |

Why these numbers: the other exclusive weapons cost R$ 99-249, so these two sit at the top
of the range, and the Mini Nuke costs more because it's the bigger "show-off" weapon.
For comparison, 100 Noob Bucks cost R$ 329.

## 2. Passes still to build

| Pass | Suggested price | What it does | Why it's fair |
| --- | --- | --- | --- |
| **Exclusive Arsenal** | R$ 1,499 | All 10 exclusive weapons at once (about 30% off buying them one by one) | Same weapons anyone can unlock |
| **VIP** | R$ 299 | Gold name on your room's sign, a "VIP" title, a gold trail, and +1 bonus Noob Buck every 5 rounds you play (win or lose) | Looks, plus a small reward for playing |
| **Every Room Theme** | R$ 199 | All room themes, now and any added later | Looks only |
| **Replay Star** | R$ 149 | Your room is always shown in the replays when you finish top 3, with a gold frame and your title on the card | Looks only (the top 3 are still picked by damage) |
| **Victory Effects** | R$ 99 | A firework, confetti or lightning burst over the noob when you destroy it (pick one) | Looks only |

## Deliberately NOT sold

- **Extra starting cash** or **more cash per hit**: you'd place better weapons sooner and win more.
- **Extra weapon slots** (more than 8): more weapons at once = more damage.
- **Stronger versions** of weapons: same reason.
- **Skip the round timer** or **extra time**: everyone gets the same 90 seconds.

## How to set one up later

1. Publish the game, then on create.roblox.com open it → **Monetization → Passes → Create a Pass**.
2. Give it a name, a picture and a price, and turn on **Item for Sale**.
3. For a weapon pass: copy the pass's ID number into that weapon's `gamePassId` in
   `src/shared/Weapons.luau`. The weapon bar and the shop then offer it for Robux.
4. For the passes in section 2: ask for them to be built first; they need code.
