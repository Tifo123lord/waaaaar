# WORLD DOMINION

A grand strategy simulation for Android and the web, built with Flutter.
You take command of one of ten major powers and steer it through economy,
diplomacy and war.

## Status

**DEMO 0.2.0** · package `com.worlddominion.strategy`
Flutter 3.35.4 / Dart 3.9.2 · Material 3 (custom design system) ·
Riverpod · GoRouter · SharedPreferences

## What changed in 0.2.0 — the world map

The map used to be ten hand-authored schematic polygons floating on a flat
ocean. It is now a genuine map:

- **One painted backdrop.** `assets/map/world_map_base.png` is a 2048×1024
  equirectangular world map generated from the
  [Natural Earth](https://www.naturalearthdata.com/) 1:50m public-domain
  dataset — real coastlines, bathymetric shelf, lakes, rivers, a latitude
  climate tint, a thin glowing coastline and a cinematic vignette. It is the
  single image the whole world map is built on.
- **Accurate nation outlines.** `lib/data/world_geometry.dart` is generated
  from the *same* dataset, so the live political overlay traces the painted
  coastline exactly instead of approximately. Japan gets its real archipelago,
  the UK gets Great Britain plus Northern Ireland, and so on.
- **Live data on top of a static image.** The image carries geography only —
  no text, no borders, no colours baked in. Political and military status are
  painted live over it, so the map still changes as the campaign runs.
- **Proper viewport handling.** `MapScaleMode.cover` scales the 2:1 map to fill
  a portrait phone without distortion (pan to see the rest); `contain` fits the
  whole world for the title-screen backdrop.
- **Cheaper rendering.** The surface is split into a static painter (backdrop +
  tinting) and an animated one (selection halo, battle markers, labels), so the
  pulsing animation never repaints the expensive base layer.

Regenerate everything with `tool/mapgen/` — see `tool/mapgen/README.md`.

## Feature status

| # | Feature | Status |
|---|---------|--------|
| 1 | Main menu — painted world backdrop, New/Continue/Settings/About, save-slot summary | ✅ |
| 2 | Country selection — tap-the-map *and* searchable list, full dossier preview | ✅ |
| 3 | National dashboard — date, treasury, net, army, stability, industry, wars, events | ✅ |
| 4 | Game clock — Pause / Normal / Fast plus single-day step | ✅ |
| 5 | Economy — income and expense breakdown, 4 building types, budget slider | ✅ |
| 6 | Military — infantry and armor recruitment, roster, disband, attrition recovery | ✅ |
| 7 | Battle — odds assessment, tick-driven resolution, report, peace negotiation | ✅ |
| 8 | Diplomacy — relations, non-aggression pacts, alliances, renouncement | ✅ |
| 9 | AI nations — economy, construction, recruitment, outreach, bounded wars | ✅ |
| 10 | Events — 7 kinds with in-game timestamps and filters | ✅ |
| 11 | Save / load — versioned JSON in SharedPreferences with validation | ✅ |
| 12 | Persian + English — real RTL, bundled Vazirmatn and Inter, Persian digits | ✅ |
| 13 | Settings / About — language, motion, map mode, save deletion | ✅ |

## Architecture

```
lib/
  main.dart                     locale data init + ProviderScope
  app/         app · router · theme · localization · settings
  core/        constants · balance · game_clock · format
               campaign_controller (Riverpod + simulation clock)
  data/        country_data · world_geometry (generated) · save_repository
  models/      country · game_state · military_unit · diplomatic_agreement
               battle · game_event
  simulation/  economy_engine · battle_engine · diplomacy_engine · ai_engine
               game_simulation (command layer) · workspace (tick scratchpad)
  features/    main_menu · country_selection · world_map · campaign · dashboard
               economy · military · battle · diplomacy · events · save
  widgets/     common (Panel, StatTile, Meter, Tag, KeyValueRow, CountryFlag…)

assets/map/    world_map_base.png      painted backdrop (generated)
tool/mapgen/   make_map.py             paints the backdrop
               make_geometry.py        emits world_geometry.dart + overlay check
```

**Key design decisions**

- `GameState` is immutable and carries a `revision` counter. One tick produces
  **one** new state → one rebuild for the whole app.
- All gameplay mutation goes through `GameSimulation` commands, so validation
  and application can never drift apart.
- The economy has exactly **one** formula, in `EconomyEngine.breakdown()`, read
  by the dashboard, the economy screen and the daily tick alike.
- The painted map and the political overlay share one projection
  (`WorldProjection`), so they cannot fall out of alignment.

## Testing

```bash
flutter analyze   # no issues
flutter test      # 10/10 passing
```

`test/world_map_render_test.dart` renders the real painters off-screen to
`build/map_preview_*.png` and asserts the projection contract, overlay
alignment, hit-testing and cover/contain aspect handling.

## Building

```bash
# Web
flutter build web --release

# Android (package name already wired to com.worlddominion.strategy)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

## Data disclosure

Country statistics are **fictionalized demo values** authored for gameplay
balance, advanced to a fictional 2027 start date. They are not presented as
real national data.

Map coastlines, lakes, rivers and national outlines come from the Natural Earth
1:50m dataset, which is in the **public domain**. Outlines are simplified for
legibility on a phone.

Typography: Inter (SIL OFL 1.1) and Vazirmatn (SIL OFL 1.1).

## Not implemented

Multiplayer, online accounts, espionage, technology trees, naval and air
warfare, and province-level borders.
