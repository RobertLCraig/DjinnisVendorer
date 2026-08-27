# HANDOVER: DjinnisVendorer

> A World of Warcraft Retail addon that improves NPC merchant frames: a wider window, a vertical
> list view, and a large filter language for finding one item among hundreds. **It is a fork of
> Vendorer by Sonaza**, maintained against current retail. Read this, then `docs/board/`, before
> changing anything.

**Stage:** active
**Category:** addon
**Status:** v4.1.2, `Interface: 120100`. Tree clean, nothing unpushed, remote
`github.com/RobertLCraig/DjinnisVendorer`. Last commit `2026-08-18`, "Release v4.1.2".
**Installed and running in the game.** This is one of the four addons Rob narrowed active scope to.
**It has three live cards on the workspace board and two of them are defects.**
`WoWAddons#0010` - it calls a Blizzard function 12.1.0 deleted and throws in the open world.
`WoWAddons#0013` - the vertical list cuts the quantity off and hides which currency a price is in.
`WoWAddons#0002` - `CURSEFORGE.md`, a question for Rob about publishing.
_Last updated: 2026-08-26 (board and handover created; no addon code was touched)_

## Goal & success criteria
**No PRD exists. This section is an interim home and a real gap.** What follows is lifted from
`README.md` and is not a spec Rob signed off.

Goal, in `README.md`'s words: sometimes vendors sell so many items it is impossible to find the one
you actually want. So the merchant frame is widened, a vertical list view is added, and a filter
language is put in front of the contents.

The filter language is the substance of this addon and the part most likely to be broken by
accident. `README.md` is its specification: name, rarity, type, slot and currency; `id6948`, `r92`,
`i200` and `12g34s56c` prefixes; `<`, `<=`, `>`, `>=` ranges; quoted phrases; `+` for exact match;
`!` or `-` to negate; and the magic words `usable`, `unusable`, `equippable`, `purchasable`,
`unequippable`, `known`, `unknown`, `available`, `canafford`, `transmogable`, `unknowntransmog`.

**The non-goals are unknown and need Rob.**

## Canonical data shape
`DjinnisVendorerDB`, one account-wide SavedVariables table declared in the `.toc`, holding the
saved item lists and settings. **Its shape lives in `settings.lua` and
`DjinnisVendorerItemListsFrame.lua` and nowhere else**; there is no `DATA-MODEL.md`, and that is a
gap rather than a decision.

`knownitems.lua` is data rather than code and is worth knowing about before editing it.

## Architecture / stack
Lua **and XML** against the Blizzard Retail API - this addon is older than the others here and
declares its frames in `.xml` rather than building them in Lua, so a UI change often means editing
both halves. Bundled libraries under `libs/`. `## OptionalDeps: Ace3, CanIMogIt` are compatibility
declarations. 13 Lua files plus their XML. No build step beyond `release.ps1` and no test suite:
**every check that matters happens in a live game client, which no agent can run.**

## Key files / structure
- `core.lua` - load, the merchant frame hooks and the widening.
- `vendorfilter.lua` - **the filter language.** `README.md` is its specification; read both together.
- `DjinnisVendorerListView.lua` / `.xml` - the vertical list view. **This is where `WoWAddons#0013`
  lives**: quantity is cut off and the currency of a price is not shown.
- `DjinnisVendorerItemListsFrame.lua` / `.xml` - the saved item lists.
- `DjinnisVendorerStackSplitFrame.lua` / `.xml` - stack splitting.
- `autorepair.lua` - repair on vendor open.
- `knownitems.lua` - data.
- `DjinnisVendorerFrames.xml` - the frame definitions the Lua expects to exist.
- `libs/`, `media/` - bundled libraries and art. **Tracked on purpose**, as `WoWAddons#0003` settled.
- `deploy.ps1`, `release.ps1`, `pkgmeta.yaml` - this addon owns its own, with their own exclusions.
- `LICENSE` - **it is a fork.** Check it before publishing anything anywhere.
- `CHANGELOG.md`, `RELEASE_NOTES.md`, `CURSEFORGE.md`, `Docs/` - history and drafts, not a plan.

## Decisions locked
- **It is a fork of Sonaza's Vendorer and says so** in the `.toc` author field, `Sonaza + Djinni`.
  That is not cosmetic: it governs what may be published and under what licence.
- **`README.md` is the filter language's specification.** A change to `vendorfilter.lua` that is not
  reflected there has broken the only description of the feature that exists.
- **`libs/` is tracked.** See `WoWAddons#0003`.

## Current state
Active, deployed, and **carrying a known throwing defect**: `WoWAddons#0010`, a Blizzard function
deleted in 12.1.0 that is still called, which throws in the open world. That is a diffable fault -
the API surface under `C:\Dev\WoWAddons\wow-ui-source` will show it - unlike the secret-values class
of fault, which it will not.

## What's next (in order)
**The workspace board owns this, not `docs/board/` here yet.** `WoWAddons#0010` and
`WoWAddons#0013` are both defects in this addon's code and both sit on the parent board. Moving them
here is a reasonable next step and is not something to do halfway: a card is a file and moving it is
`git mv`, but these two would be crossing repositories and would get new numbers.

## Blockers / open questions
- **`WoWAddons#0002`, `CURSEFORGE.md`:** a publishing question for Rob, still open in
  `human-review/`.
- **Where do this addon's defects live?** Two are on the workspace board today. Now that this repo
  has a board of its own, the next person should agree with Rob which board owns them, rather than
  quietly duplicating them.
- **The fork's licence constrains publishing.** Read `LICENSE` before answering `WoWAddons#0002`.

## How to pick up
1. Read this file, then `docs/board/README.md`, then `WoWAddons#0010` and `WoWAddons#0013` on
   `C:\Dev\WoWAddons\docs\board\`.
2. Read `C:\Dev\WoWAddons\docs\DECISIONS.md` for the two 12.1 traps before touching event
   registration or anything keyed on a unit.
3. Deploy from the workspace and never edit the game folder:
   `C:\Dev\WoWAddons\bin\deploy.ps1 -WhatIf -Only DjinnisVendorer`, then the same without
   `-WhatIf`. The dry run is the plan.
4. Check any API against `C:\Dev\WoWAddons\wow-ui-source\`, never from memory. Anything defined only
   under `Blizzard_Deprecated*/` is CVar-gated and is not safe to rely on.

## Sibling docs
- `README.md` in the repository root: the goal statement, and the filter language specification.
- `LICENSE`, because this is a fork.
- Workspace: `C:\Dev\WoWAddons\docs\HANDOVER.md` and `docs\DECISIONS.md`.
- **Gaps:** no `PRD.md`, no `DATA-MODEL.md`, no `DECISIONS.md`.

## Branch status
One branch, `master`. Clean, level with `origin/master`.

## Session log
- **2026-08-26** Board and handover created, so this stops showing on `board:map` as an
  unidentifiable nested folder. No addon code was touched, and no card was moved off the workspace
  board.
