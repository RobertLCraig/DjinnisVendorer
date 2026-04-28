# Release Notes

## Version: 4.1.1

<!-- Write release notes below this line. They will be extracted by release.ps1 -->

Hotfix for stack purchasing on WoW Midnight (12.0).

### Fixes

* Stack-split popup now opens again when shift-clicking a merchant item, in both the default grid view and the vertical list view. The popup was silently failing to appear because `Addon:GetItemTooltipInfo` errored out partway through its tooltip scan when 12.0 returned a "secret string" `GetText()` on certain lines (string ops like `==` and `strmatch` throw on those values). The per-line scan is now wrapped in `pcall`, so a throwing line skips itself and the rest of the scan still produces usable data.
