#!/usr/bin/env python3
"""
Derive nation outlines for WORLD DOMINION from Natural Earth 1:50m country
polygons (public domain), simplify them, and emit `lib/data/world_geometry.dart`.

The emitted rings are [lon, lat] pairs in degrees on the SAME equirectangular
projection as the painted map backdrop, so the interactive overlay lines up
exactly with the coastline drawn into the image.

Also writes `overlay_test.png`: the simplified rings drawn over the map so the
alignment can be checked by eye.
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
DART_OUT = os.path.join(REPO, "lib", "data", "world_geometry.dart")
TEST_OUT = os.path.join(REPO, "tool", "mapgen", "overlay_reference.png")
MAP_PNG = os.path.join(REPO, "assets", "map", "world_map_base.png")

TOL = 0.16            # simplification tolerance in degrees (~1px at 2048 wide)
MIN_AREA_FRAC = 0.04  # drop rings smaller than this fraction of the main ring
MAX_DIST_KM = 5500.0  # drop rings further than this from the main ring

# id, Natural Earth ADM0_A3, label anchor [lon, lat]
NATIONS = [
    ("us", "USA", [-99.0, 39.5]),
    ("cn", "CHN", [103.0, 35.0]),
    ("ru", "RUS", [96.0, 61.0]),
    ("ir", "IRN", [53.5, 32.5]),
    ("uk", "GBR", [-2.5, 54.4]),
    ("fr", "FRA", [2.3, 46.6]),
    ("de", "DEU", [10.2, 51.2]),
    ("in", "IND", [78.5, 22.5]),
    ("jp", "JPN", [138.0, 37.0]),
    ("br", "BRA", [-51.0, -12.0]),
]


def load(name):
    with open(os.path.join(HERE, name + ".geojson")) as fh:
        return json.load(fh)


def polygons_of(geom):
    """Yield each polygon as a list of rings (exterior first, then holes)."""
    t = geom.get("type")
    if t == "Polygon":
        yield geom["coordinates"]
    elif t == "MultiPolygon":
        yield from geom["coordinates"]
    elif t == "GeometryCollection":
        for sub in geom.get("geometries", []):
            yield from polygons_of(sub)


def ring_area(ring):
    s = 0.0
    for i in range(len(ring) - 1):
        x1, y1 = ring[i][0], ring[i][1]
        x2, y2 = ring[i + 1][0], ring[i + 1][1]
        s += x1 * y2 - x2 * y1
    return abs(s) * 0.5


def ring_centroid(ring):
    a = cx = cy = 0.0
    for i in range(len(ring) - 1):
        x1, y1 = ring[i][0], ring[i][1]
        x2, y2 = ring[i + 1][0], ring[i + 1][1]
        cross = x1 * y2 - x2 * y1
        a += cross
        cx += (x1 + x2) * cross
        cy += (y1 + y2) * cross
    if abs(a) < 1e-12:
        xs = [p[0] for p in ring]
        ys = [p[1] for p in ring]
        return sum(xs) / len(xs), sum(ys) / len(ys)
    a *= 0.5
    return cx / (6 * a), cy / (6 * a)


def gc_km(a, b):
    lon1, lat1 = math.radians(a[0]), math.radians(a[1])
    lon2, lat2 = math.radians(b[0]), math.radians(b[1])
    d = (math.sin(lat1) * math.sin(lat2)
         + math.cos(lat1) * math.cos(lat2) * math.cos(lon2 - lon1))
    return math.degrees(math.acos(max(-1.0, min(1.0, d)))) * 111.195


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


def build():
    data = load("ne_50m_admin_0_countries")
    by_code = {}
    for feat in data["features"]:
        code = feat["properties"].get("ADM0_A3")
        if code:
            by_code[code] = feat

    result = []
    for nid, code, anchor in NATIONS:
        feat = by_code.get(code)
        if feat is None:
            raise SystemExit("missing feature for " + code)
        rings = []
        for poly in polygons_of(feat["geometry"]):
            if not poly:
                continue
            pts = [tuple(p[:2]) for p in poly[0]]
            if len(pts) < 4:
                continue
            rings.append(pts)
        # keep the biggest ring, then decide which others belong with it
        rings.sort(key=ring_area, reverse=True)
        main = rings[0]
        main_area = ring_area(main)
        main_c = ring_centroid(main)
        kept = [main]
        for r in rings[1:]:
            if ring_area(r) < main_area * MIN_AREA_FRAC:
                continue
            if gc_km(main_c, ring_centroid(r)) > MAX_DIST_KM:
                continue
            kept.append(r)

        simplified = []
        for r in kept:
            s = simplify_closed(r, TOL)
            if s:
                simplified.append(s)

        total = sum(len(r) for r in simplified)
        print(f"  {nid:>3}  rings={len(simplified):>2}  points={total}")
        result.append((nid, anchor, simplified))
    return result


def write_dart(nations):
    lines = []
    w = lines.append
    w("import 'dart:ui';")
    w("")
    w("/// Nation outlines for WORLD DOMINION.")
    w("///")
    w("/// Derived from the **Natural Earth 1:50m** public-domain country dataset")
    w("/// and simplified for gameplay use. This file is generated - see")
    w("/// `mapwork/make_geometry.py`.")
    w("///")
    w("/// Each ring is a closed list of `[lon, lat]` pairs in degrees, on the same")
    w("/// equirectangular projection as the painted world-map backdrop, so the live")
    w("/// political/military overlay lines up exactly with the coastline that is")
    w("/// drawn into that image.")
    w("class MapShape {")
    w("  const MapShape({")
    w("    required this.id,")
    w("    required this.rings,")
    w("    this.labelAnchor,")
    w("  });")
    w("")
    w("  final String id;")
    w("")
    w("  /// Separate landmasses and island groups belonging to this nation.")
    w("  /// The first ring is always the largest one.")
    w("  final List<List<List<double>>> rings;")
    w("")
    w("  /// Preferred label position in lon/lat degrees.")
    w("  final List<double>? labelAnchor;")
    w("")
    w("  /// Label position, falling back to the centroid of the largest ring.")
    w("  Offset get anchor {")
    w("    if (labelAnchor != null) return Offset(labelAnchor![0], labelAnchor![1]);")
    w("    if (rings.isEmpty || rings.first.isEmpty) return Offset.zero;")
    w("    final ring = rings.first;")
    w("    var x = 0.0;")
    w("    var y = 0.0;")
    w("    for (final p in ring) {")
    w("      x += p[0];")
    w("      y += p[1];")
    w("    }")
    w("    return Offset(x / ring.length, y / ring.length);")
    w("  }")
    w("}")
    w("")
    w("/// Equirectangular projection shared by every map surface in the game.")
    w("///")
    w("/// Matches the aspect and extent of the painted backdrop exactly:")
    w("/// longitude -180..180, latitude 90..-90, aspect ratio 2:1.")
    w("class WorldProjection {")
    w("  const WorldProjection._();")
    w("")
    w("  static const double lonMin = -180;")
    w("  static const double lonMax = 180;")
    w("  static const double latMax = 90;")
    w("  static const double latMin = -90;")
    w("")
    w("  static const double lonSpan = lonMax - lonMin; // 360")
    w("  static const double latSpan = latMax - latMin; // 180")
    w("")
    w("  /// Natural aspect ratio (width / height) of the full projection.")
    w("  static const double aspect = lonSpan / latSpan; // 2.0")
    w("")
    w("  /// Projects lon/lat degrees into a unit square (0..1 on both axes),")
    w("  /// with north at the top.")
    w("  static Offset toUnit(double lon, double lat) {")
    w("    final u = (lon - lonMin) / lonSpan;")
    w("    final v = (latMax - lat) / latSpan;")
    w("    return Offset(u, v);")
    w("  }")
    w("")
    w("  /// Projects into pixel space for a canvas of [size].")
    w("  static Offset toPixel(double lon, double lat, Size size) {")
    w("    final u = toUnit(lon, lat);")
    w("    return Offset(u.dx * size.width, u.dy * size.height);")
    w("  }")
    w("}")
    w("")
    w("/// The playable nations of the demo.")
    w("const List<MapShape> kPlayableShapes = [")
    for nid, anchor, rings in nations:
        w("  MapShape(")
        w(f"    id: '{nid}',")
        w(f"    labelAnchor: [{anchor[0]}, {anchor[1]}],")
        w("    rings: [")
        for ring in rings:
            w("      [")
            chunk = []
            for p in ring:
                chunk.append(f"[{round(p[0], 2)}, {round(p[1], 2)}]")
            # wrap ~4 points per line
            for i in range(0, len(chunk), 4):
                body = ", ".join(chunk[i:i + 4])
                w(f"        {body},")
            w("      ],")
        w("    ],")
        w("  ),")
    w("];")
    w("")
    with open(DART_OUT, "w") as fh:
        fh.write("\n".join(lines))
    print("wrote", DART_OUT, len("\n".join(lines)) // 1024, "KB")


def write_overlay_test(nations):
    if not os.path.exists(MAP_PNG):
        return
    base = Image.open(MAP_PNG).convert("RGB")
    W, H = base.size
    d = ImageDraw.Draw(base)
    for nid, anchor, rings in nations:
        for ring in rings:
            pts = [((p[0] + 180) / 360 * W, (90 - p[1]) / 180 * H) for p in ring]
            d.line(pts, fill=(255, 80, 80), width=2)
        ax = (anchor[0] + 180) / 360 * W
        ay = (90 - anchor[1]) / 180 * H
        d.ellipse([ax - 4, ay - 4, ax + 4, ay + 4], fill=(255, 220, 0))
    base.save(TEST_OUT)
    print("wrote", TEST_OUT)


if __name__ == "__main__":
    ns = build()
    write_dart(ns)
    write_overlay_test(ns)
