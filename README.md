English · [Русский](README.ru.md)

# Craftwise

A profession helper for WoW Forever by [addicted](https://addicted.sh).

Hover over any item to see:

- **Used in**: which recipes of your characters (all professions) use the item, and how many. Recipe colors match the profession window: orange and yellow still give skill, grey no longer does.
- **Made from**: the reagents, if the item is crafted.
- **You have**: how many are in your bags and bank, and how many crafts that's enough for.
- **Tip**: "Still levels your profession: keep it" or "Your recipes for it no longer give skill".

At the Auction House, a panel appears next to the sell window: what a vendor would pay, what you'd get after the cut (5%, 15% at the neutral auction houses), the deposit you lose if it doesn't sell, the cheapest price on sale now and how many items are cheaper than yours. Then a verdict: post it, sell it to a vendor, or how often it has to sell to beat the vendor (if it doesn't sell you lose the deposit but get the items back). When others are cheaper it suggests a price to sell first, and the Use button puts it in.

## Bags and bank: what to keep

A small badge in the corner of every bag and bank slot:

- **Green tick**: still levels your profession. The tooltip says about how many you need to reach your current skill cap.
- **Gold coin**: still needed, but you hold more than leveling takes. The tooltip shows how many are spare.
- **Blue tick**: another character of yours still levels with it.
- **Green arrow**: make it into something better first: ore you can smelt into bars you level with, cloth into bolts.
- **Red cross**: can go. Junk, nothing of yours levels with it any more, food, potions or gear 15+ levels below you, or a trade good none of your recipes use.

`/craftwise bags` sums it up in chat: what can go and what a vendor pays for it, what is spare, what to refine. Open the bank once and it is counted too (as of your last visit). The "how many you need" is an estimate: crafts to the cap at the recipe's colour (orange 1 per point, yellow 1.5, green 3).

## Ore and herb map

If you have Mining or Herbalism, the world map and minimap show the veins and herbs you can gather, plus the next tier (in red, while your skill is too low). Grey nodes that no longer give skill are hidden. The nodes come from QuestieDB for Forever, so QuestieDB must be installed.

## Getting started

Open the window of each of your professions once (Mining, Engineering and so on). Craftwise will remember the recipes, their colors and reagents. Your alts' recipes are saved too if you log in on them and open their professions.

## Commands

- `/craftwise bags`: what in your bags and bank can go, what is spare, what to refine
- `/craftwise badges`: badges on bag and bank slots on/off
- `/craftwise list`: which professions and how many recipes are remembered
- `/craftwise reset`: forget everything
- `/craftwise map`: world map nodes on/off
- `/craftwise minimap`: minimap nodes on/off
- `/craftwise grey`: show grey nodes too

## License

MIT
