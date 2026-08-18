# Release Notes

## Version: 4.1.2

<!-- Write release notes below this line. They will be extracted by release.ps1 -->

Compatibility update for WoW Midnight patch 12.1.0.

### Fixes

* Repair button no longer throws `attempt to call a nil value` on every durability change. 12.1.0 deleted the global `SetDesaturation(texture, enable)` helper and left no deprecated fallback, so all four call sites in `autorepair.lua` were calling nil. They now call `Texture:SetDesaturated` directly. `UPDATE_INVENTORY_DURABILITY` fires on any durability change anywhere in the world, so this threw in combat as well as at a vendor.
* Shift-click stack split works again. 12.1.0 moved `ChatEdit_GetActiveWindow` to `ChatFrameUtil.GetActiveWindow`.

### Changes

* Interface version bumped to 120100.
* Screenshots and the CurseForge description are no longer packaged into the addon zip.
