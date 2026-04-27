# DjinnisVendorer

DjinnisVendorer is an NPC merchant improvement addon for World of Warcraft. It builds on the original Vendorer by Sonaza and is maintained against current retail (WoW Midnight, Interface 120005).

## Description

Sometimes vendors sell so many items it's impossible to find the one you actually want. DjinnisVendorer widens the merchant frame so more items fit on screen at once, adds a vertical list view for browsing merchants with long inventories, and gives you a flexible search box for narrowing things down.

### Filtering

* **Basic filtering** Search by item name, rarity, type, slot or required currency.
* **Tooltip text** Optionally search the full tooltip text. This is resource intensive and can be disabled if it causes frame drops.
* **By item ID** Prefix a number with `id`. For example `id6948`.
* **By required level** Prefix a number with `r`. For example `r92`.
* **By item level** Prefix a number with `i`. For example `i200`.
* **By price** Enter a price value formatted like `12g34s56c`.
* **Ranges of values** Prefix any of the above with `<`, `<=`, `>` or `>=`. For example `>=r90` finds items that require level 90 or higher; `>=250g <=500g` finds items costing between 250 and 500 gold.
* **Magic words (predefined filters)** `usable`, `unusable`, `equippable`, `purchasable`, `unequippable`, `known`, `unknown`, `available`, `canafford`, `transmogable`, `unknowntransmog`.

You can also search for phrases by putting words in quotes. Results then only include items containing those words in that order.

Prefixing a query with `+` attempts exact matching and discards everything else. Useful for finding specific item types.

Any filter can be negated by prefixing it with `!` (an exclamation mark) or `-` (a dash).

Search text can optionally persist across sessions or just for the current session. Configure this under Settings.

### Vertical list view

As an alternative to the merchant grid, DjinnisVendorer offers a scrollable vertical list view that shows every item the merchant sells in one column, with item name, cost columns, and an inventory max-stack hint. The list view also replaces the buyback tab when enabled, so the same browsing experience applies to both. Toggle it from the Settings menu.

Modifier clicks behave the same as on the standard merchant grid: shift-click to chat-link, ctrl-click to preview, alt-click to compare.

### Bulk purchase

DjinnisVendorer improves the bulk purchase dialog. You can buy multiple stacks in one click and the dialog shows the total cost of the purchase. If you run into purchase rate limits you can throttle the rate from Settings.

### Sell and repair

Buttons to sell junk and unusable soulbound items appear next to the merchant. Junk selling can run automatically whenever you visit a vendor. Settings also enables (with care) destroying unsellable junk or unusable items. **If toggled on, be careful of what you're destroying.** You can ignore individual items so they are never sold or destroyed. No items are auto-destroyed by the auto-junk-sell flow.

The smart repair feature spends your maximum guild-repair allowance first when visiting a repair vendor. The guild-repair behaviour can be disabled if you'd rather pay from your own purse.

If a merchant doesn't actually buy items the addon notices and adds them to an auto-sell ignore list. You can clear that ignore by holding ctrl when clicking the Sell Junk button.

## Slash commands

* `/djinnisvendorer` (or `/djv`) prints usage.
* `/djv ignore [item]` opens the ignore list, or adds/removes a specific item.
* `/djv junk [item]` opens the junk-sell list, or adds/removes a specific item.
* `/djv autosell` toggles automatic junk selling.
* `/djv autorepair` toggles automatic repair.
* `/djv smartrepair` toggles smart repair.
* `/djv eqolwarn` re-enables the EnhanceQoL Merchant conflict warning if it was previously suppressed.

## Optional dependency

DjinnisVendorer can mark items whose appearance you haven't yet collected. This requires the optional dependency [Can I Mog It](https://www.curseforge.com/wow/addons/can-i-mog-it). The marker can be disabled in Settings.

## Conflicts

This addon modifies the merchant frame and **is likely to conflict** with other addons that do the same. The known overlap is EnhanceQoL's Merchant submodule, which DjinnisVendorer detects and offers to disable on first contact.

If you don't use other merchant-frame addons, or theirs only do minor changes, the risk of conflict is small.

## Dependencies

DjinnisVendorer uses Ace3, included in the `/libs` directory.

## License

DjinnisVendorer is licensed under the MIT license. See `LICENSE` for the full terms.
