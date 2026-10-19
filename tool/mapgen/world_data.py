#!/usr/bin/env python3
"""
Authored world table for WORLD DOMINION.

The playable roster is no longer limited to ten nations. Every entry below is a
sovereign nation in the Natural Earth 1:50m country dataset; the generator
(`make_world.py`) derives its outline and its capturable regions from that
public-domain data.

Fields
------
id            internal country id used everywhere in the game
code          Natural Earth ADM0_A3 code
anchor        [lon, lat] preferred map-label position
regions       target number of capturable regions (3..8)
group         rough theatre grouping, used to author starting relations
"""

NATIONS = [
    # --- North America -------------------------------------------------------
    dict(id="us", code="USA", anchor=[-99.0, 39.5], regions=8, group="west"),
    dict(id="ca", code="CAN", anchor=[-100.0, 58.0], regions=8, group="west"),
    dict(id="mx", code="MEX", anchor=[-102.0, 23.5], regions=5, group="west"),
    # --- South America ------------------------------------------------------
    dict(id="br", code="BRA", anchor=[-51.0, -12.0], regions=8, group="west"),
    dict(id="ar", code="ARG", anchor=[-64.0, -37.0], regions=5, group="west"),
    # --- Europe -------------------------------------------------------------
    dict(id="uk", code="GBR", anchor=[-2.5, 54.4], regions=4, group="west"),
    dict(id="fr", code="FRA", anchor=[2.3, 46.6], regions=6, group="west"),
    dict(id="de", code="DEU", anchor=[10.2, 51.2], regions=5, group="west"),
    dict(id="it", code="ITA", anchor=[12.5, 42.8], regions=5, group="west"),
    dict(id="es", code="ESP", anchor=[-3.7, 40.2], regions=5, group="west"),
    dict(id="nl", code="NLD", anchor=[5.4, 52.2], regions=3, group="west"),
    dict(id="se", code="SWE", anchor=[16.0, 62.0], regions=4, group="west"),
    dict(id="no", code="NOR", anchor=[9.5, 62.5], regions=4, group="west"),
    dict(id="pl", code="POL", anchor=[19.4, 52.1], regions=4, group="east"),
    dict(id="ua", code="UKR", anchor=[31.2, 49.0], regions=5, group="east"),
    dict(id="ru", code="RUS", anchor=[96.0, 61.0], regions=8, group="east"),
    dict(id="gr", code="GRC", anchor=[22.0, 39.3], regions=4, group="west"),
    # --- Middle East / Central Asia -----------------------------------------
    dict(id="tr", code="TUR", anchor=[35.2, 39.0], regions=5, group="east"),
    dict(id="ir", code="IRN", anchor=[53.5, 32.5], regions=6, group="east"),
    dict(id="sa", code="SAU", anchor=[45.0, 24.0], regions=4, group="east"),
    dict(id="ae", code="ARE", anchor=[54.3, 24.0], regions=3, group="east"),
    dict(id="il", code="ISR", anchor=[35.0, 31.4], regions=3, group="west"),
    dict(id="kz", code="KAZ", anchor=[67.0, 48.5], regions=5, group="east"),
    # --- Africa -------------------------------------------------------------
    dict(id="eg", code="EGY", anchor=[30.0, 26.5], regions=4, group="east"),
    dict(id="ng", code="NGA", anchor=[8.0, 9.5], regions=5, group="east"),
    dict(id="et", code="ETH", anchor=[39.5, 9.0], regions=5, group="east"),
    dict(id="za", code="ZAF", anchor=[24.5, -29.0], regions=6, group="east"),
    # --- South & East Asia --------------------------------------------------
    dict(id="in", code="IND", anchor=[78.5, 22.5], regions=8, group="east"),
    dict(id="pk", code="PAK", anchor=[69.5, 30.0], regions=5, group="east"),
    dict(id="cn", code="CHN", anchor=[103.0, 35.0], regions=8, group="east"),
    dict(id="jp", code="JPN", anchor=[138.0, 37.0], regions=5, group="east"),
    dict(id="kr", code="KOR", anchor=[127.8, 36.5], regions=3, group="east"),
    dict(id="th", code="THA", anchor=[101.0, 15.5], regions=5, group="east"),
    dict(id="vn", code="VNM", anchor=[106.0, 16.0], regions=4, group="east"),
    # --- Oceania ------------------------------------------------------------
    dict(id="id", code="IDN", anchor=[117.0, -2.5], regions=8, group="east"),
    dict(id="au", code="AUS", anchor=[134.0, -25.0], regions=8, group="west"),
]

# Explicit land borders (undirected). Used for the front-line / adjacency model
# and to seed a plausible theatre graph. Anything not listed here is treated as
# reachable only by sea / air projection.
LAND_BORDERS = [
    ("us", "ca"), ("us", "mx"),
    ("mx", "ca"),
    ("br", "ar"),
    ("fr", "de"), ("fr", "it"), ("fr", "es"), ("fr", "nl"),
    ("de", "nl"), ("de", "pl"), ("de", "it"),
    ("pl", "ua"), ("pl", "ru"),
    ("ua", "ru"), ("ua", "tr"),
    ("ru", "kz"), ("ru", "cn"),
    ("se", "no"), ("no", "ru"),
    ("gr", "tr"), ("gr", "it"),
    ("tr", "ir"), ("tr", "sa"), ("tr", "kz"),
    ("ir", "pk"), ("ir", "sa"), ("ir", "ae"), ("ir", "kz"),
    ("sa", "ae"), ("sa", "eg"), ("sa", "il"),
    ("il", "eg"),
    ("eg", "et"),
    ("et", "ng"),
    ("ng", "et"),
    ("za", "ng"),
    ("in", "pk"), ("in", "cn"), ("in", "th"),
    ("pk", "cn"), ("pk", "af"),
    ("cn", "kz"), ("cn", "vn"), ("cn", "th"), ("cn", "kr"),
    ("kr", "jp"),
    ("th", "vn"), ("th", "id"),
    ("id", "au"), ("id", "vn"),
]

# Sector labels for generated regions, keyed by compass bearing from the
# nation's centre of mass. Localised at runtime as `region.sector.<key>`.
SECTORS = ["c", "n", "ne", "e", "se", "s", "sw", "w", "nw"]
