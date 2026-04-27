# Release Notes

## Version: 4.1.0

<!-- Write release notes below this line. They will be extracted by release.ps1 -->

This release brings DjinnisVendorer onto current retail (WoW Midnight, Interface 120005) without depending on Blizzard's deprecation fallbacks, and extends the vertical list view to the buyback tab.

### Compatibility

* Migrated every API call to its current namespaced form: `C_Item.*`, `C_Container.*`, `C_CurrencyInfo.GetCoinTextureString`, `C_MerchantFrame.GetItemInfo`. The addon no longer relies on the legacy globals or on Blizzard's `loadDeprecationFallbacks` CVar.
* Container info and merchant info now read from the new table-return shape directly rather than via a positional adapter.
* Replaced the legacy `EasyMenu` / `UIDropDownMenu` paths in the Settings menu and the Quick Filters menu with native `MenuUtil.CreateContextMenu` callbacks.
* TOC interface bumped to `120005`.

### Vertical list view on the buyback tab

* The list view now also covers the buyback tab when enabled, so you get the same scrollable browsing experience for items you've sold.
* Click a row to buy back; modifier clicks (shift-link, ctrl-preview, alt-compare) behave the same as on the merchant tab.
* The merchant frame keeps its wider list-view layout on both tabs and rows stretch to fill the pane, so item names render in the middle column.

### List view fixes

* Stack column now shows inventory max stack (e.g. 200 for potions) rather than the merchant's per-purchase quantity.
* Modifier clicks inside the list view route through `HandleModifiedItemClick`, restoring ctrl-preview, shift-link and alt-compare on list rows.
* Currency rows show the "you have N" line via `SetCurrencyByID`, matching the merchant token buttons.

### Bottom-left chrome layout

* Repair-button row is now anchored to a single shared baseline. Blizzard's 12.0 default ships the buttons at slightly inconsistent Y offsets (RepairAll ~4px below RepairItem, SellAllJunk ~7px above), which made the row look staircase-shaped.
* The repair-button row sits inside the left decorative inset; the "Last sold" buyback preview slot moves into the right inset, so both decorative trays are filled and nothing collides mid-strip.
* All bottom-left buttons now anchor absolutely to MerchantFrame, sidestepping the circular-dependency SetPoint errors triggered by Blizzard's UpdateRepairButtons swapping anchor direction between calls.
* The smart-repair button skips past hidden anchor candidates (e.g. MerchantSellAllJunkButton on merchants that don't sell junk) so it always sits flush against the rightmost visible button.

### Other fixes

* Buyback tab no longer shows orphaned prev/next page buttons or empty merchant-grid slots when list view is on.

### Internal

* Removed `compat.lua` and the 44 redundant `CloseMenus()` calls left over from the legacy menu system.
* Dropped the `_G.GetMerchantItemInfo` monkey-patch in `vendorfilter.lua`; filter index redirection now flows solely through the `C_MerchantFrame.GetItemInfo` override.
