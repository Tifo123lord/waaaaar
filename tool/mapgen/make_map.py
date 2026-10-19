#!/usr/bin/env python3
"""
Render a beautiful, geographically accurate dark 'command-room' world map.

Source data: Natural Earth 1:50m (public domain) - real coastlines, lakes, rivers.
Output: 2048x1024 equirectangular PNG (lon -180..180, lat 90..-90, aspect 2:1).

Deliberately contains NO text, NO political borders and NO labels: those are
drawn live in Flutter on top of this image so the map stays dynamic.
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
ASSET_OUT = os.path.join(REPO, "assets", "map", "world_map_base.png")

OUT_W, OUT_H = 2048, 1024
SS = 2                      # supersample factor used only for mask drawing
SW, SH = OUT_W * SS, OUT_H * SS

LON_MIN, LON_MAX = -180.0, 180.0
LAT_MAX, LAT_MIN = 90.0, -90.0

# ------------------------------------------------------------------ palette --
OCEAN_TOP = (0x11, 0x1D, 0x27)
OCEAN_BOTTOM = (0x05, 0x09, 0x0E)
VIGNETTE = (0x02, 0x04, 0x07)
SHELF = (0x15, 0x44, 0x46)
BATHY = (0x11, 0x37, 0x3C)
GRAT = (0x36, 0x50, 0x60)

LAND_BASE = (0x22, 0x2D, 0x37)
LAND_POLAR = (0x30, 0x3E, 0x4C)
LAND_WARM = (0x23, 0x2B, 0x2D)
ICE = (0x63, 0x77, 0x8B)

COAST_GLOW = (0x2C, 0x6B, 0x5F)
COAST_LINE = (0x6C, 0xBE, 0xA6)
COAST_DEEP = (0x09, 0x11, 0x17)

LAKE_FILL = (0x0B, 0x14, 0x1B)
LAKE_LINE = (0x42, 0x7A, 0x6E)
RIVER = (0x3E, 0x78, 0x6E)


# ------------------------------------------------------------- geojson i/o --
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


def lines_of(geom):
    t = geom.get("type")
    if t == "LineString":
        yield geom["coordinates"]
    elif t == "MultiLineString":
        for ls in geom["coordinates"]:
            yield ls
    elif t == "GeometryCollection":
        for sub in geom.get("geometries", []):
            yield from lines_of(sub)


def to_px(ring, w, h):
    pts = []
    for p in ring:
        lon = p[0]
        lat = max(-89.999, min(89.999, p[1]))
        pts.append((
            (lon - LON_MIN) / (LON_MAX - LON_MIN) * w,
            (LAT_MAX - lat) / (LAT_MAX - LAT_MIN) * h,
        ))
    return pts


def mask_from(geojson, w, h, filt=None):
    img = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(img)
    for feat in geojson["features"]:
        if filt is not None and not filt(feat):
            continue
        for poly in polygons_of(feat["geometry"]):
            if not poly:
                continue
            pts = to_px(poly[0], w, h)
            if len(pts) >= 3:
                draw.polygon(pts, fill=255)
            for hole in poly[1:]:
                hp = to_px(hole, w, h)
                if len(hp) >= 3:
                    draw.polygon(hp, fill=0)
    return img


def lines_mask(geojson, w, h, width):
    img = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(img)
    for feat in geojson["features"]:
        for ls in lines_of(feat["geometry"]):
            pts = to_px(ls, w, h)
            if len(pts) >= 2:
                draw.line(pts, fill=255, width=width, joint="curve")
    return img


# ----------------------------------------------------------------- helpers --
def alpha_of(img, blur=0.0):
    if img.size != (OUT_W, OUT_H):
        img = img.resize((OUT_W, OUT_H), Image.LANCZOS)
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(img, dtype=np.float32) / 255.0


def blur_alpha(a, r):
    im = Image.fromarray(np.clip(a * 255.0, 0, 255).astype(np.uint8), "L")
    im = im.filter(ImageFilter.GaussianBlur(r))
    return np.asarray(im, dtype=np.float32) / 255.0


def blend(base, color, alpha):
    """Standard 'over' blend. color may be an RGB tuple or an (H,W,3) array."""
    c = np.asarray(color, dtype=np.float32)
    return base + (c - base) * alpha[..., None]


# ------------------------------------------------------------------ render --
def render():
    land = load("ne_50m_land")
    lakes = load("ne_50m_lakes")
    rivers = load("ne_50m_rivers_lake_centerlines")

    land_m = mask_from(land, SW, SH)
    lake_m = mask_from(lakes, SW, SH)
    river_m = lines_mask(rivers, SW, SH, 1 * SS)

    land_a = alpha_of(land_m)
    lake_a = alpha_of(lake_m)
    river_a = alpha_of(river_m, blur=0.6)

    # --- 1. ocean -----------------------------------------------------------
    ys = np.linspace(0.0, 1.0, OUT_H, dtype=np.float32).reshape(-1, 1)
    top = np.array(OCEAN_TOP, np.float32)
    bot = np.array(OCEAN_BOTTOM, np.float32)
    col = top[None, :] * (1.0 - ys) + bot[None, :] * ys         # (H,3)
    ocean = np.broadcast_to(col[:, None, :], (OUT_H, OUT_W, 3)).copy()
    col = None

    # --- 2. bathymetry: soft shelf + tighter near-shore band ----------------
    shelf = np.clip(blur_alpha(land_a, 16.0) - land_a, 0.0, 1.0)
    ocean = blend(ocean, SHELF, shelf * 0.42)
    near = np.clip(blur_alpha(land_a, 5.0) - land_a, 0.0, 1.0)
    ocean = blend(ocean, BATHY, near * 0.55)

    # --- 3. graticule -------------------------------------------------------
    grat = Image.new("L", (OUT_W, OUT_H), 0)
    gd = ImageDraw.Draw(grat)
    for lon in range(-180, 181, 30):
        x = (lon - LON_MIN) / 360.0 * OUT_W
        gd.line([(x, 0), (x, OUT_H)], fill=70, width=1)
    for lat in range(-80, 81, 20):
        y = (LAT_MAX - lat) / 180.0 * OUT_H
        gd.line([(0, y), (OUT_W, y)], fill=70, width=1)
    ocean = blend(ocean, GRAT, alpha_of(grat, blur=0.8) * 0.30)

    axis = Image.new("L", (OUT_W, OUT_H), 0)
    ad = ImageDraw.Draw(axis)
    ad.line([(0, OUT_H / 2), (OUT_W, OUT_H / 2)], fill=255, width=1)
    ad.line([(OUT_W / 2, 0), (OUT_W / 2, OUT_H)], fill=255, width=1)
    ocean = blend(ocean, GRAT, alpha_of(axis, blur=0.8) * 0.55)

    # --- 4. land colour: latitude climate + fine grain ----------------------
    lats = np.linspace(90.0, -90.0, OUT_H, dtype=np.float32)
    base = np.array(LAND_BASE, np.float32)
    polar = np.array(LAND_POLAR, np.float32)
    warm = np.array(LAND_WARM, np.float32)
    ice = np.array(ICE, np.float32)
    rows = np.zeros((OUT_H, 3), np.float32)
    for i, lat in enumerate(lats):
        a = abs(float(lat))
        if a > 48.0:
            t = min(1.0, (a - 48.0) / 28.0)
            c = base + (polar - base) * t
        elif a < 20.0:
            c = base + (warm - base) * ((1.0 - a / 20.0) * 0.85)
        else:
            c = base.copy()
        it = max(0.0, min(1.0, (a - 66.0) / 14.0)) * 0.55
        rows[i] = c + (ice - c) * it
    land_col = np.broadcast_to(rows[:, None, :], (OUT_H, OUT_W, 3)).copy()

    rng = np.random.default_rng(11)
    nz = rng.integers(0, 255, size=(OUT_H // 3 + 1, OUT_W // 3 + 1), dtype=np.uint8)
    nz = np.asarray(Image.fromarray(nz, "L").resize((OUT_W, OUT_H), Image.BILINEAR),
                    np.float32)
    nz = (nz - 128.0) / 128.0 * 7.0
    land_col = np.clip(land_col + nz[..., None], 0.0, 255.0)

    # --- 5. composite land --------------------------------------------------
    img = blend(ocean, land_col, land_a)
    del ocean, land_col

    # --- 6. depth shadow just inside the coast ------------------------------
    inner = np.clip(land_a - blur_alpha(land_a, 2.6), 0.0, 1.0)
    img = blend(img, COAST_DEEP, inner * 0.60)

    # --- 7. coastal glow + crisp coastline ----------------------------------
    glow = np.clip(blur_alpha(land_a, 3.2) - land_a, 0.0, 1.0)
    img = blend(img, COAST_GLOW, glow * 0.65)
    coast = np.clip(alpha_of(land_m.filter(ImageFilter.MaxFilter(3))) - land_a, 0.0, 1.0)
    img = blend(img, COAST_LINE, coast * 0.85)

    # --- 8. lakes -----------------------------------------------------------
    img = blend(img, LAKE_FILL, lake_a * 0.92)
    lake_edge = np.clip(lake_a - blur_alpha(lake_a, 1.2), 0.0, 1.0)
    img = blend(img, LAKE_LINE, lake_edge * 0.55)

    # --- 9. rivers ----------------------------------------------------------
    img = blend(img, RIVER, river_a * 0.38)

    # --- 10. cinematic vignette over everything -----------------------------
    yy, xx = np.mgrid[0:OUT_H, 0:OUT_W]
    xx = xx.astype(np.float32)
    yy = yy.astype(np.float32)
    cx, cy = OUT_W / 2.0, OUT_H / 2.0
    rr = np.sqrt(((xx - cx) / (OUT_W * 0.62)) ** 2 + ((yy - cy) / (OUT_H * 0.68)) ** 2)
    vig = np.clip((rr - 0.60) / 0.80, 0.0, 1.0)
    img = blend(img, VIGNETTE, vig * 0.55)
    del xx, yy, rr, vig

    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")

    # --- verification -------------------------------------------------------
    a = np.asarray(out, np.int32)
    def sample(lon, lat):
        x = int((lon + 180) / 360 * OUT_W)
        y = int((90 - lat) / 180 * OUT_H)
        return tuple(a[y, x])
    print("  land  (Africa 20,0):", sample(20, 0), " expect ~ (31,41,50)")
    print("  land  (Siberia 100,60):", sample(100, 60), " expect ~ (43,56,68)")
    print("  land  (Antarctica 0,-80):", sample(0, -80), " expect ~ (110,130,145)")
    print("  ocean (Pacific -140,0):", sample(-140, 0), " expect ~ (7,13,18)")
    print("  ocean (Atlantic -30,20):", sample(-30, 20))
    print("  land fraction:", round(float((land_a > 0.5).mean()), 4))
    return out


if __name__ == "__main__":
    img = render()
    os.makedirs(os.path.dirname(ASSET_OUT), exist_ok=True)
    img.save(ASSET_OUT, optimize=True)
    print("wrote", ASSET_OUT, img.size, os.path.getsize(ASSET_OUT) // 1024, "KB")
