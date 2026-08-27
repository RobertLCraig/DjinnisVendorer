# Release Notes

## Version: 4.1.3

<!-- Write release notes below this line. They will be extracted by release.ps1 -->

Two fixes to the vertical list view, both about prices and quantities you could not read.

### Fixes

* The quantity column no longer cuts the number off. It was a fixed 28 pixels, so a four-digit maximum stack such as a dye's 1000 rendered as `x1...`. The column now starts at 40 pixels and can be dragged wider or narrower from a divider in a new header strip above the list. The width is saved, so it survives a `/reload` and closing the merchant.
* A currency price now says what the currency is. Hovering the icon or the amount shows the game's own tooltip for that token, naming it and stating how many you hold, the same tooltip Blizzard's merchant grid gives. Prices made of more than one currency get a tooltip for each. Previously the icon was `|T...|t` markup inside a `FontString`, which takes no mouse input, so there was nothing there to hover.

### Changes

* The currency part of a price is now drawn as real buttons rather than text markup. Clicking one still buys the item, exactly as clicking anywhere else on the row does.
