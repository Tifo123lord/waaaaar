# WORLD DOMINION — Development Status

**Version:** DEMO 0.1.0 · **Package:** `com.worlddominion.strategy` · **Platform:** Android first, Web build verified
**Stack:** Flutter 3.35.4 / Dart 3.9.2 · Material 3 (fully custom design system) · Riverpod · GoRouter · SharedPreferences

---

## 1. What was built

This is the **first playable slice** of WORLD DOMINION — a small, coherent, genuinely
playable grand strategy demo, not a static mockup. Every number on screen is produced by
one running simulation; nothing is hardcoded per-screen.

### Feature status

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | Main menu | ✅ Complete | Dark vector map backdrop, New/Continue/Settings/About, version label, save-slot summary card. Continue is disabled until a valid save exists. |
| 2 | Country selection | ✅ Complete | Interactive tap-the-map selection **and** searchable list; dossier preview with stats, strengths, weaknesses, starting forces, reachable theatres. 10 nations. |
| 3 | National dashboard | ✅ Complete | Live date, treasury, ± monthly net, army, population, stability meter, industry, wars, construction queue, event feed, quick actions. |
| 4 | Working game clock | ✅ Complete | Pause / Normal / Fast + single-day step. One in-game day per tick. Timer-driven, **not** frame-driven. |
| 5 | Economy | ✅ Complete | Real loop: income, expenses (civil, military, construction), 4 building types with cost/duration/effect, budget slider, affordability guards. |
| 6 | Military | ✅ Complete | Infantry + Armor recruitment with unique IDs, cost, strength, upkeep, home region, experience. Manpower ceiling, order-of-battle roster, disband with confirmation, peacetime attrition recovery. |
| 7 | Playable battle | ✅ Complete | Pre-battle odds assessment (strength, supply, expected losses), confirm-then-launch, multi-round tick-driven resolution, pulsing front marker on the map, full battle report dialog, peace negotiation. |
| 8 | Diplomacy | ✅ Complete | Relations, Improve Relations (cost), Non-Aggression Pact, Alliance, renounce — all AI-evaluated and stored in state, and they genuinely change later gameplay (a pact blocks attack; an alliance blocks attack). |
| 9 | AI countries | ✅ Complete | 10-day pulse: income/expenses, construction, recruitment by doctrine, diplomatic outreach, tension events, and a bounded demo war (max one at a time, day ≥ 45, only vs. clearly weaker + unfriendly). |
| 10 | Events | ✅ Complete | 7 event kinds (economy, construction, diplomacy, recruitment, battle, intelligence, system) with in-game timestamps, relative-time labels, and kind filters. Generated only by real actions. |
| 11 | Save / load | ✅ Complete | Versioned JSON (format v1) in SharedPreferences, header-only cheap summary read, full validation on load (rails on treasury/population/stability, unknown nations re-filled from the dataset), delete with confirmation. |
| 12 | Persian + English | ✅ Complete | `Locale('fa')` with real RTL `Directionality` and bidi shaping; bundled **Vazirmatn** (fa) and **Inter** (en); Persian-Arabic digits and localized month names via `intl`. Never string-reversed. |
| 13 | Settings / About | ✅ Complete | Language, animation toggle, default map mode, sound/music (no audio assets — see limitations), save deletion; About discloses the fictional-data status. |

### Architecture

```
lib/
  main.dart                     locale data init + ProviderScope
  app/         app.dart · router.dart · theme.dart · localization.dart · settings.dart
  core/        constants.dart · balance.dart · game_clock.dart · format.dart
               campaign_controller.dart (Riverpod + simulation clock)
  data/        country_data.dart · world_geometry.dart · save_repository.dart
  models/      country · game_state · military_unit · diplomatic_agreement · battle · game_event
  simulation/  economy_engine · battle_engine · diplomacy_engine · ai_engine
               game_simulation (command layer) · workspace (tick scratchpad)
  features/    main_menu · country_selection · world_map · campaign · dashboard
               economy · military · battle · diplomacy · events · save
  widgets/     common.dart (Panel, StatTile, Meter, Tag, KeyValueRow, confirmAction, CountryFlag…)
```

**Key design decisions**

- `GameState` is immutable and carries a `revision` counter. One tick produces **one**
  new state → one rebuild for the whole app. A `SimulationWorkspace` holds intermediate
  collections so a tick can mutate freely and publish atomically.
- All gameplay mutation goes through `GameSimulation` commands (`ActionResult` in,
  new state out). UI never mutates state directly, so validation and application can
  never drift apart.
- The economy has exactly **one** formula in `EconomyEngine.breakdown()` — the dashboard,
  the economy screen and the daily tick all read it.
- Military funding is derived: stored once (doctrine default) plus an optional player
  override, exposed via `GameState.budgetOf()`. No duplicate copies to desynchronise.
- The map is a `CustomPainter` over authored lon/lat polygons with `InteractiveViewer`
  for pan/zoom and real polygon hit-testing on tap.

### Testing & validation performed

- `flutter analyze` → **No issues found!**
- `flutter test` → **9/9 passing**
  - app boots to the main menu
  - economy produces positive income / real budget
  - clock advances days and changes the world
  - recruitment deducts cost and adds a unit
  - construction queues, is paid for, and completes
  - recruitment is refused without funds
  - battle resolves and changes military strength
  - diplomacy stores agreements that affect later play (pact verified to block attack)
  - 200-day AI soak: no NaN/infinite money, stability within 0–100, AI observably acts
- `flutter build web --release` → **succeeded**

---

## 2. Known limitations (deliberate Demo 0.1.0 scope)

- **No APK built in this session.** The Android toolchain is present, but the build was
  not executed before the work window closed. No APK exists yet — see §3.
- **No audio.** The sound/music toggles persist intent only; the demo ships no audio
  assets. Stated in the Settings screen so it is not a misleading control.
- **Schematic map, not cartography.** Outlines are hand-authored simplified polygons
  chosen for legibility on a phone. Ten playable nations; other landmasses are muted
  context shapes. Documented in About.
- **Battle is abstract and single-front.** One battle per nation at a time; no naval,
  air, or operational-level modelling. Attacking never guarantees victory.
- **Nation figures are fictionalized demo values** balanced for gameplay (advanced to a
  fictional 2027 start), explicitly disclosed in About and in the dataset doc comment.
- **Not implemented (as scoped out):** multiplayer, online accounts, espionage,
  technology trees, province-level borders, naval warfare, historical simulation.
- Province/region granularity: territorial transfer moves the *nation's* home region
  rather than individual provinces, which is intentional at this scale.

---

## 3. Building the Android APK

Run inside the project (package name is already wired to `com.worlddominion.strategy`):

```bash
cd /home/user/flutter_app
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

Package-name consistency was already synchronised across
`android/app/build.gradle.kts` (namespace + applicationId),
`android/app/src/main/kotlin/com/worlddominion/strategy/MainActivity.kt`, and the
manifest label (`World Dominion`), so the build should not hit
`ClassNotFoundException`. Use the signing tool for a signed release build.

---

## 4. Priority order for the next session

1. Build and verify the signed release APK on a device/emulator.
2. Playtest pass on a real phone: map gesture feel, small-screen layout at 360dp,
   RTL layout audit of every screen with Persian active.
3. Deeper battle: multi-front wars, front lines that move, supply lines that can be cut.
4. Save slots (multiple campaigns) and an autosave on exit.
5. Technology/research tree (the dashboard already has a research slot reserved).
6. Province-level map granularity and a proper geographic dataset with attribution.
