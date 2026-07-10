# Lantern Rollout — Foundation + Batch 1 Implementation Plan

**Goal:** Cut the app over to a single dark Lantern theme at the root, fix the deferred concept-icon outline color, build the two highest-leverage new shared components (`LanternRow`, `LanternActionTile`), and migrate the 8 cheapest/most-static live screens (Batch 1). Batches 2-7 get their own plan docs later, once this batch's real component/edge-case learnings are in.

**Architecture:** Root `ThemeData` becomes a single Lantern-night theme (no more day/bedtime split); per-screen `Theme(data: StorytimeTheme.bedtime)` wraps become redundant and are removed opportunistically as each screen is touched, not in one sweep. Batch 1 screens are all read-mostly/static (no forms, no adaptive grids, no audio state machines) — lowest risk, highest visual-consistency payoff per screen touched.

**Tech Stack:** Flutter, Riverpod, go_router (routing untouched this pass).

**Spec:** `docs/superpowers/specs/2026-07-10-lantern-app-wide-design.md`

**Out of scope:** Batches 2-7 (separate future plans), any copy/feature/navigation change, `StoryPlayerScreen`/`StoryGeneratingScreen` (Batch 5/7), deleting dead v1 screens.

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `app/lib/main.dart` | Root `ThemeData` → single Lantern night theme; drop `darkTheme`/`themeMode` |
| Modify | `app/lib/theme/app_theme.dart` | Add a single exported `LanternTheme.root` (or similarly named) `ThemeData` built the same way `StorytimeTheme.bedtime` is today; keep `StorytimeTheme.day`/`.bedtime` defined but unreferenced from `main.dart` |
| Modify | `app/lib/ui/concept_icons.dart` | Recolor all outline strokes from `#7A4A14`/`#2A2230` to `#241F3D` |
| Create | `app/lib/ui/widgets/lantern/lantern_row.dart` | `LanternRow` — generic list-row component (avatar/icon, title, subtitle, trailing) |
| Create | `app/lib/ui/widgets/lantern/lantern_action_tile.dart` | `LanternActionTile` — big non-selectable action tile (Home's two tiles) |
| Modify | `app/lib/ui/widgets/lantern/lantern.dart` | Export the two new widgets |
| Modify | `app/lib/ui/parent_access_screen.dart` (or wherever `ParentAccessScreen` lives) | Re-skin to Lantern tokens |
| Modify | `app/lib/ui/storytime_screens.dart` (contains `StorytimeAccountScreen`, `StorytimePrivacyScreen`, `StorytimeParentDashboard`, `StorytimeWelcomeScreen`, `StoryEndScreen` — confirm exact file/class locations before editing) | Re-skin each of the 6 screens; `StorytimeParentDashboard`'s `_DashboardEntry` and `StorytimeAccountScreen`'s Material widgets adopt `LanternRow` |
| Modify | `app/lib/ui/family_voices_screens.dart` (contains `VoiceCaptureIntroScreen`, `VoiceReadyScreen`) | Re-skin; centralize the hardcoded `0xFF4CAF50` green to `LanternTokens.hueMeadow` |
| Test | `app/test/ui/` (various, per existing file layout) | Update/add widget tests for re-skinned screens per existing per-screen test file conventions |

*(Exact file/class locations to be confirmed by reading the router and current files — the inventory found some class names live in shared files like `storytime_screens.dart` and `family_voices_screens.dart` rather than one-file-per-screen; don't assume a 1:1 file mapping without checking.)*

---

## Task 1: Root theme cutover

**Files:** `app/lib/main.dart`, `app/lib/theme/app_theme.dart`

- Read `app_theme.dart` in full to see exactly how `StorytimeTheme.bedtime` is constructed (base `ThemeData` + `extensions: [...]`), and mirror that construction for a new single root theme (can literally BE `StorytimeTheme.bedtime` renamed/aliased, or a new `LanternTheme.root` that wraps it — prefer the smallest diff; if `StorytimeTheme.bedtime` already IS what's needed, just point `main.dart` at it directly rather than creating a duplicate).
- In `main.dart`, find the `MaterialApp.router` construction, set `theme:` to the chosen root theme, remove `darkTheme:` and `themeMode:` if present.
- Do NOT delete `StorytimeTheme.day` — leave it defined, just unreferenced from the root.

**Acceptance:**
- App boots to a dark theme on `/welcome` and `/home` (currently cream) without other code changes yet (screens will look wrong/inconsistent until re-skinned in later tasks — that's expected and fine mid-migration).
- `flutter analyze` clean.

## Task 2: Concept icon outline recolor

**Files:** `app/lib/ui/concept_icons.dart`

- Find every occurrence of the two outline colors (`#7A4A14`, `#2A2230`) in the inline SVG strings and replace both with a single `#241F3D` (per spec §3). This is a find-and-replace on stroke colors only — do not touch fill colors, shapes, or the seamless-background rule.
- Sanity-check: grep the file afterward to confirm zero remaining occurrences of the two old hex values.

**Acceptance:** All 30 concept glyphs render with the new outline; `/dev/gallery`'s existing concept-icon showcase (if any) or the already-live Composer confirms visually correct on a dark ground.

## Task 3: `LanternRow` and `LanternActionTile`

**Files:** Create `lantern_row.dart`, `lantern_action_tile.dart`; modify the barrel `lantern.dart`

Read `st_row.dart` and `st_tile.dart` first (the components these replace) to copy their shape/spacing/responsive logic exactly — only change token sourcing (`StorytimeTokens` → `LanternTokens`).

- **`LanternRow`**: props roughly `{leading (Widget), title (String), subtitle (String?), trailing (Widget?), onTap (VoidCallback?)}` — used for the resume strip, dashboard nav entries, voice list rows, story list rows. Background `nightCard`, hairline `hush`, text `moon`/`moonDim`.
- **`LanternActionTile`**: props roughly `{icon/glyph (Widget), title (String), subtitle (String), accentGlow (bool)}` — the big Home tiles. `accentGlow: true` gets the lantern-glow treatment (matching the "Make a Story" tile being the primary action); `false` is a quieter `nightCard` tile (matching "Listen").

**Acceptance:** Both render correctly in `/dev/gallery`'s Lantern section with sample data; `flutter analyze` clean.

## Task 4: Batch 1 screens

**Files:** per the File Map above — confirm exact locations first.

For each of the 8 screens, replace `StorytimeTokens`/`AppColors` reads with the `LanternTokens` equivalents per spec §3, and swap any hand-rolled list-row/card markup for `LanternRow`/`LanternActionTile` where it fits (don't force-fit where the existing layout is genuinely different, e.g. `StoryEndScreen`'s stacked buttons stay buttons). Specifically:
- `StorytimeParentDashboard`'s `_DashboardEntry` → `LanternRow`.
- `StorytimeAccountScreen` (currently zero `St*` components, plain Material) → adopt `LanternRow` for its list items, `GlowButton`/a quieter Lantern button for actions; this is the biggest single-screen lift in the batch since it's starting from bare Material.
- `VoiceReadyScreen`/`VoiceCaptureIntroScreen`: also fix the stale `context.go('/make/character')` call (found in the earlier routing work) to `context.go('/compose')` directly while touched.
- Remove each screen's `Theme(data: StorytimeTheme.bedtime, ...)` wrap where present (`StoryEndScreen`) since it's now redundant under the new root theme.

**Acceptance per screen:** `flutter analyze` clean; any existing widget test for the screen still passes (update assertions that hard-check old color values, not behavior); visually consistent with the Composer's palette (spot-check via `/dev/gallery` or, once available, on-device).

## Task 5: Verification

- Full `flutter analyze` — no new issues beyond the existing pre-migration baseline.
- Full `flutter test` — no new failures beyond the known ~9-10 pre-existing flaky set (see memory: confirm via a before/after run, not a single run, per the flakiness already documented).
- On-device spot check of at least `/welcome`, `/home`, `/parent` if a connected device/simulator is available at execution time.

---

## Build order

1. Task 1 (root theme) and Task 2 (icon recolor) can run in parallel — independent files.
2. Task 3 (`LanternRow`/`LanternActionTile`) depends on nothing above but should land before Task 4 (Batch 1 screens consume these components).
3. Task 4 depends on Task 3 (component availability) but not on Task 1/2 being merged first (though Task 1 landing first means Batch 1 screens are being visually verified against the real root theme, not a preview).
4. Task 5 after all above.
