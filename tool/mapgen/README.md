# Map generation

The world map shipped with the game (`assets/map/world_map_base.png`) and the
nation outlines in `lib/data/world_geometry.dart` are both **generated** from
the [Natural Earth](https://www.naturalearthdata.com/) 1:50m public-domain
dataset. Nothing here is hand-authored, so the painted coastline and the live
political overlay can never drift apart: they share one projection.

## Regenerating

```bash
cd tool/mapgen

# 1. Fetch the source data (public domain, ~7 MB).
BASE=https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson
for f in ne_50m_land ne_50m_admin_0_countries ne_50m_lakes \
         ne_50m_rivers_lake_centerlines; do
  curl -sSL -o "$f.geojson" "$BASE/$f.geojson"
done

# 2. Paint the backdrop  ->  assets/map/world_map_base.png   (2048x1024, 2:1)
python3 make_map.py

# 3. Emit the outlines   ->  lib/data/world_geometry.dart
#                           tool/mapgen/overlay_reference.png (visual check)
python3 make_geometry.py
```

Requires `pillow` and `numpy`.

## Projection contract

Everything uses a plain **equirectangular** projection:

| | value |
|---|---|
| longitude | -180 .. 180 |
| latitude | 90 .. -90 |
| aspect | 2:1 |

`WorldProjection` in `world_geometry.dart` implements exactly this, and
`MapFit` in `world_map_view.dart` places the 2:1 image into the available
viewport. Keep these in sync if you ever change the extent.

## Output size

`make_geometry.py` currently keeps the largest ring per nation, plus any other
ring at least 4% of its area and within 5500 km of it. That deliberately drops
overseas territories (French Guiana, Alaska, Svalbard, ...) so playable nations
stay compact and legible on a phone. Loosen `MIN_AREA_FRAC` / `MAX_DIST_KM`
in the script if you want the full sovereign extent.
