#!/usr/bin/env python3
"""
Generate `lib/data/world_geometry.dart` for WORLD DOMINION.

For every nation in `world_data.py` this script:

1. rasterises the Natural Earth 1:50m country polygon at map resolution,
2. extracts *all* landmass outlines (mainland + islands) as simplified rings,
3. partitions the nation into `regions` capturable provinces via a
   weighted k-means pass over its own land pixels,
4. extracts a simplified outline for every province.

Everything is emitted on the same equirectangular projection as the painted
backdrop (lon -180..180, lat 90..-90, 2:1), so overlays never drift.

Region partitioning uses a pure-numpy raster + skimage contour approach; no
shapely is required (shapely segfaults in this sandbox).
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw
from skimage import measure

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
DART_OUT = os.path.join(REPO, "lib", "data", "world_geometry.dart")

import world_data as WD  # noqa: E402

# Raster resolution for the region partition pass. 1440x720 == 0.25 deg cells,
# which is plenty for province-sized shapes and keeps runtime in seconds.
RW, RH = 1440, 720
CELL = 360.0 / RW  # degrees per cell

COUNTRY_TOL = 0.16   # simplification tolerance (deg) for nation outlines
REGION_TOL = 0.30    # coarser: provinces are display-only geometry
MIN_REGION_AREA = 3  # drop province fragments smaller than this many cells
MIN_NATION_AREA = 12


def load(name):
    with open(os.path.join(HERE, name + ".geojson")) as fh:
        return json.load(fh)


def iter_polys(geom):
    t = geom.get("type")
    if t == "Polygon":
        yield geom["coordinates"]
    elif t == "MultiPolygon":
        yield from geom["coordinates"]
    elif t == "GeometryCollection":
        for sub in geom.get("geometries", []):
            yield from iter_polys(sub)


def lonlat_to_xy(lon, lat):
    """Degrees -> raster cell (float)."""
    x = (lon + 180.0) / 360.0 * RW
    y = (90.0 - lat) / 180.0 * RH
    return x, y


def ring_area_deg(ring):
    s = 0.0
    n = len(ring)
    for i in range(n):
        x1, y1 = ring[i][0], ring[i][1]
        x2, y2 = ring[(i + 1) % n][0], ring[(i + 1) % n][1]
        s += x1 * y2 - x2 * y1
    return abs(s) * 0.5


def ring_centroid(ring):
    a = cx = cy = 0.0
    n = len(ring)
    for i in range(n):
        x1, y1 = ring[i][0], ring[i][1]
        x2, y2 = ring[(i + 1) % n][0], ring[(i + 1) % n][1]
        cross = x1 * y2 - x2 * y1
        a += cross
        cx += (x1 + x2) * cross
        cy += (y1 + y2) * cross
    if abs(a) < 1e-12:
        xs = [p[0] for p in ring]
        ys = [p[1] for p in ring]
        return sum(xs) / n, sum(ys) / n
    a *= 0.5
    return cx / (6 * a), cy / (6 * a)


def perp(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    if dx == 0 and dy == 0:
        return math.hypot(p[0] - a[0], p[1] - a[1])
    return abs(dx * (a[1] - p[1]) - (a[0] - p[0]) * dy) / math.hypot(dx, dy)


def dp(points, tol):
    n = len(points)
    if n < 3:
        return list(points)
    keep = [False] * n
    keep[0] = keep[-1] = True
    stack = [(0, n - 1)]
    while stack:
        i, j = stack.pop()
        if j <= i + 1:
            continue
        best, idx = 0.0, i
        for k in range(i + 1, j):
            d = perp(points[k], points[i], points[j])
            if d > best:
                best, idx = d, k
        if best > tol:
            keep[idx] = True
            stack.append((i, idx))
            stack.append((idx, j))
    return [p for p, k in zip(points, keep) if k]


def simplify_closed(ring, tol):
    pts = [tuple(p[:2]) for p in ring]
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts = pts[:-1]
    if len(pts) < 4:
        return None
    p0 = pts[0]
    fi = max(range(len(pts)),
             key=lambda i: (pts[i][0] - p0[0]) ** 2 + (pts[i][1] - p0[1]) ** 2)
    if fi < 2 or fi > len(pts) - 2:
        out = dp(pts + [pts[0]], tol)
    else:
        a = dp(pts[:fi + 1], tol)
        b = dp(pts[fi:] + [pts[0]], tol)
        out = a[:-1] + b[:-1]
    out = [p for i, p in enumerate(out) if i == 0 or p != out[i - 1]]
    if len(out) < 3:
        return None
    out.append(out[0])
    return out


def rasterize(geom):
    """Return a boolean RWxRH mask for a (multi)polygon geometry."""
    img = Image.new("1", (RW, RH), 0)
    d = ImageDraw.Draw(img)
    for poly in iter_polys(geom):
        if not poly:
            continue
        ext = [lonlat_to_xy(p[0], p[1]) for p in poly[0]]
        if len(ext) >= 3:
            d.polygon(ext, fill=1)
        # Punch holes back out.
        for hole in poly[1:]:
            hp = [lonlat_to_xy(p[0], p[1]) for p in hole]
            if len(hp) >= 3:
                d.polygon(hp, fill=0)
    return np.array(img, dtype=bool)


def mask_to_rings(mask, tol, min_area=MIN_REGION_AREA):
    """Extract simplified lon/lat rings from a boolean raster mask."""
    pad = np.zeros((mask.shape[0] + 2, mask.shape[1] + 2), dtype=float)
    pad[1:-1, 1:-1] = mask.astype(float)
    contours = measure.find_contours(pad, 0.5)
    rings = []
    for c in contours:
        if len(c) < 6:
            continue
        # c is (row, col) in padded space -> undo the pad, then to lon/lat.
        pts = []
        for r, col in c:
            x = col - 1.0
            y = r - 1.0
            lon = x / RW * 360.0 - 180.0
            lat = 90.0 - y / RH * 180.0
            pts.append((lon, lat))
        # Drop holes: contour orientation + area sign tells us, but for the
        # province layer we keep everything closed and let the painter fill.
        if ring_area_deg(pts) < min_area * (CELL * CELL) * 0.5:
            continue
        s = simplify_closed(pts, tol)
        if s:
            rings.append(s)
    rings.sort(key=ring_area_deg, reverse=True)
    return rings


def cluster_pixels(ys, xs, k, rng):
    """Weighted k-means on pixel coordinates. Returns label per pixel."""
    n = len(xs)
    if n == 0:
        return np.zeros(0, dtype=int)
    if k <= 1 or n <= k:
        return np.zeros(n, dtype=int)
    # k-means++ style seeding for stable, well-spread provinces.
    centers = np.empty((k, 2), dtype=float)
    i0 = rng.integers(n)
    centers[0] = (ys[i0], xs[i0])
    d2 = ((ys - centers[0, 0]) ** 2 + (xs - centers[0, 1]) ** 2).astype(float)
    for c in range(1, k):
        total = d2.sum()
        if total <= 0:
            centers[c] = (ys[rng.integers(n)], xs[rng.integers(n)])
        else:
            probs = d2 / total
            pick = int(rng.choice(n, p=probs))
            centers[c] = (ys[pick], xs[pick])
        nd = (ys - centers[c, 0]) ** 2 + (xs - centers[c, 1]) ** 2
        d2 = np.minimum(d2, nd)
    labels = np.zeros(n, dtype=int)
    for _ in range(24):
        dist = np.stack([
            (ys - centers[c, 0]) ** 2 + (xs - centers[c, 1]) ** 2
            for c in range(k)
        ], axis=1)
        new_labels = np.argmin(dist, axis=1)
        if np.array_equal(new_labels, labels):
            break
        labels = new_labels
        for c in range(k):
            sel = labels == c
            if sel.any():
                centers[c] = (ys[sel].mean(), xs[sel].mean())
    return labels


def sector_key(dy, dx):
    """Compass sector from a province centroid offset (screen space)."""
    ang = math.degrees(math.atan2(dy, dx))  # 0 = east, 90 = south (y grows down)
    if -22.5 <= ang < 22.5:
        return "e"
    if 22.5 <= ang < 67.5:
        return "se"
    if 67.5 <= ang < 112.5:
        return "s"
    if 112.5 <= ang < 157.5:
        return "sw"
    if 157.5 <= ang <= 180 or -180 <= ang < -157.5:
        return "w"
    if -157.5 <= ang < -112.5:
        return "nw"
    if -112.5 <= ang < -67.5:
        return "n"
    return "ne"


def build():
    adm0 = load("ne_50m_admin_0_countries")
    by_code = {}
    for f in adm0["features"]:
        c = f["properties"].get("ADM0_A3")
        if c:
            by_code[c] = f

    rng = np.random.default_rng(20270101)
    nations = []
    regions = []

    for spec in WD.NATIONS:
        feat = by_code.get(spec["code"])
        if feat is None:
            raise SystemExit("missing feature for " + spec["code"])
        mask = rasterize(feat["geometry"])
        area = int(mask.sum())
        if area < MIN_NATION_AREA:
            raise SystemExit("nation too small: " + spec["id"])

        # --- nation outline (all landmasses) -------------------------------
        rings = mask_to_rings(mask, COUNTRY_TOL, min_area=MIN_NATION_AREA * 0.6)
        if not rings:
            raise SystemExit("no rings for " + spec["id"])
        npts = sum(len(r) for r in rings)

        # --- capturable regions -------------------------------------------
        ys, xs = np.nonzero(mask)
        k = max(1, min(int(spec["regions"]), len(xs)))
        labels = cluster_pixels(ys.astype(float), xs.astype(float), k, rng)

        cy = float(ys.mean())
        cx = float(xs.mean())
        used_sectors = {}
        # Order provinces deterministically: nearest to centre first so the
        # "capital" region is stable across regenerations.
        order = sorted(
            range(k),
            key=lambda c: ((ys[labels == c].mean() - cy) ** 2 +
                           (xs[labels == c].mean() - cx) ** 2)
            if (labels == c).any() else 1e18,
        )
        for rank, c in enumerate(order):
            sel = labels == c
            if not sel.any():
                continue
            pys, pxs = ys[sel], xs[sel]
            if len(pxs) < MIN_REGION_AREA:
                continue
            pcy = float(pys.mean())
            pcx = float(pxs.mean())
            key = sector_key(pcy - cy, pcx - cx)
            if rank == 0:
                key = "c"
            # Disambiguate repeated sectors.
            base = key
            n = 2
            while key in used_sectors:
                key = f"{base}{n}"
                n += 1
            used_sectors[key] = True

            sub = np.zeros_like(mask)
            sub[pys, pxs] = True
            sub_rings = mask_to_rings(sub, REGION_TOL,
                                      min_area=MIN_REGION_AREA * 0.5)
            if not sub_rings:
                continue
            lon = pcx / RW * 360.0 - 180.0
            lat = 90.0 - pcy / RH * 180.0
            regions.append(dict(
                id=f"{spec['id']}.{key}",
                country=spec["id"],
                key=key,
                anchor=[round(lon, 2), round(lat, 2)],
                capital=(rank == 0),
                weight=int(len(pxs)),
                rings=[[[round(p[0], 2), round(p[1], 2)] for p in r]
                       for r in sub_rings],
            ))

        print(f"  {spec['id']:>3}  land={area:>5}  rings={len(rings):>2} "
              f"pts={npts:>5}  regions={sum(1 for r in regions if r['country'] == spec['id'])}")

        nations.append(dict(
            id=spec["id"],
            anchor=spec["anchor"],
            rings=[[[round(p[0], 2), round(p[1], 2)] for p in r] for r in rings],
        ))

    return nations, regions


def write_dart(nations, regions):
    L = []
    w = L.append
    w("// GENERATED FILE - do not edit by hand.")
    w("// Regenerate with:  cd tool/mapgen && python3 make_world.py")
    w("//")
    w("// Outlines and capturable regions are derived from the Natural Earth 1:50m")
    w("// public-domain dataset and share the equirectangular projection of the")
    w("// painted backdrop, so overlays never drift from the coastline.")
    w("import 'dart:ui';")
    w("")
    w("class MapShape {")
    w("  const MapShape({required this.id, required this.rings, this.labelAnchor});")
    w("  final String id;")
    w("  final List<List<List<double>>> rings;")
    w("  final List<double>? labelAnchor;")
    w("  Offset get anchor {")
    w("    if (labelAnchor != null) return Offset(labelAnchor![0], labelAnchor![1]);")
    w("    if (rings.isEmpty || rings.first.isEmpty) return Offset.zero;")
    w("    final ring = rings.first;")
    w("    var x = 0.0; var y = 0.0;")
    w("    for (final p in ring) { x += p[0]; y += p[1]; }")
    w("    return Offset(x / ring.length, y / ring.length);")
    w("  }")
    w("}")
    w("")
    w("class MapRegion {")
    w("  const MapRegion({")
    w("    required this.id,")
    w("    required this.countryId,")
    w("    required this.sector,")
    w("    required this.anchor,")
    w("    required this.capital,")
    w("    required this.rings,")
    w("  });")
    w("  final String id;")
    w("  final String countryId;")
    w("  final String sector;")
    w("  final List<double> anchor;")
    w("  final bool capital;")
    w("  final List<List<List<double>>> rings;")
    w("}")
    w("")
    w("/// Equirectangular projection shared by every map surface in the game.")
    w("class WorldProjection {")
    w("  const WorldProjection._();")
    w("  static const double lonMin = -180;")
    w("  static const double lonMax = 180;")
    w("  static const double latMax = 90;")
    w("  static const double latMin = -90;")
    w("  static const double lonSpan = lonMax - lonMin;")
    w("  static const double latSpan = latMax - latMin;")
    w("  static const double aspect = lonSpan / latSpan;")
    w("  static Offset toUnit(double lon, double lat) =>")
    w("      Offset((lon - lonMin) / lonSpan, (latMax - lat) / latSpan);")
    w("  static Offset toPixel(double lon, double lat, Size size) {")
    w("    final u = toUnit(lon, lat);")
    w("    return Offset(u.dx * size.width, u.dy * size.height);")
    w("  }")
    w("}")
    w("")

    def emit_rings(rings, indent):
        for ring in rings:
            w(f"{indent}[")
            chunk = [f"[{p[0]}, {p[1]}]" for p in ring]
            for i in range(0, len(chunk), 5):
                w(f"{indent}  " + ", ".join(chunk[i:i + 5]) + ",")
            w(f"{indent}],")

    w("/// The playable nations.")
    w("const List<MapShape> kWorldShapes = [")
    for n in nations:
        w("  MapShape(")
        w(f"    id: '{n['id']}',")
        w(f"    labelAnchor: [{n['anchor'][0]}, {n['anchor'][1]}],")
        w("    rings: [")
        emit_rings(n["rings"], "      ")
        w("    ],")
        w("  ),")
    w("];")
    w("")
    w("/// Every capturable province in the world, grouped by owning nation.")
    w("const List<MapRegion> kWorldRegions = [")
    for r in regions:
        w("  MapRegion(")
        w(f"    id: '{r['id']}',")
        w(f"    countryId: '{r['country']}',")
        w(f"    sector: '{r['key']}',")
        w(f"    anchor: [{r['anchor'][0]}, {r['anchor'][1]}],")
        w(f"    capital: {str(r['capital']).lower()},")
        w("    rings: [")
        emit_rings(r["rings"], "      ")
        w("    ],")
        w("  ),")
    w("];")
    w("")
    w("/// Backwards-compatible alias: the ten original nations.")
    w("final List<MapShape> kPlayableShapes = kWorldShapes;")
    w("")

    with open(DART_OUT, "w") as fh:
        fh.write("\n".join(L))
    print("wrote", DART_OUT, len("\n".join(L)) // 1024, "KB")


if __name__ == "__main__":
    ns, rs = build()
    print(f"nations={len(ns)} regions={len(rs)}")
    write_dart(ns, rs)
