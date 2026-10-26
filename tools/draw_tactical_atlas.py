"""Author the existing 16px building/command sprites. Square units are imported separately. Optional tooling: Python + Pillow, no runtime dependency.

The checked-in PNGs can also be edited directly. White/gray pixels on the separate
team layer are tinted at render time; cyan glass and metal belong to the body.
"""
from pathlib import Path
from PIL import Image, ImageDraw

CELL, FRAMES, ROWS = 16, 4, 13
OUT = Path(__file__).resolve().parents[1] / "assets" / "pixel"
BODY = Image.new("RGBA", (CELL * FRAMES, CELL * ROWS))
TEAM = Image.new("RGBA", BODY.size)
INK, DARK, METAL, EDGE = "#0d1520", "#233342", "#526979", "#a6c6ce"
CYAN, GLASS, WHITE, AMBER = "#47d8ff", "#2377ab", "#e0fbff", "#f4a740"
CLEAR = (0, 0, 0, 0)


def tile(row, frame):
    body, team = Image.new("RGBA", (CELL, CELL)), Image.new("RGBA", (CELL, CELL))
    return body, team, ImageDraw.Draw(body), ImageDraw.Draw(team)


def building(d, t, kind, state, frame):
    d.rectangle((1, 5, 14, 14), INK)
    d.rectangle((2, 6, 13, 13), METAL)
    d.rectangle((3, 7, 12, 12), DARK)
    d.line((2, 6, 13, 6), EDGE)
    for x in (1, 12):
        d.rectangle((x, 8, x + 2, 14), INK)
        t.rectangle((x + 1, 8, x + 1, 12), "#c0c0c0")
        d.line((x, 13, x + 2, 13), EDGE)
    t.rectangle((4, 13, 11, 13), "#c5c5c5")
    for x in (4, 7, 10):
        d.point((x, 14), EDGE)
        t.point((x + 1, 13), "#707070")
    if state == "construction":
        d.rectangle((5, 3, 10, 12), METAL)
        for y in (3, 7, 11): t.line((3, y, 12, y), "#a0a0a0")
        d.line((5, 3, 10, 11), EDGE)
        return
    if kind == "research":
        d.rectangle((5, 1, 10, 11), INK)
        d.polygon([(7, 1), (9, 3), (9, 9), (7, 11), (6, 9), (6, 3)], GLASS)
        d.line((7, 2, 7, 9), CYAN if state in ("active", "complete") else "#6397ad")
        d.line((8, 3, 8, 8), WHITE if state in ("active", "complete") else "#49778e")
        t.rectangle((5, 11, 10, 12), "#ffffff")
        for x in (4, 11):
            d.rectangle((x, 5, x, 10), METAL)
            d.point((x, 6), CYAN if state == "active" else AMBER if state == "waiting" else DARK)
        if state == "active":
            y = 3 + frame * 2
            d.line((6, y, 9, y), WHITE)
            d.point((3 + frame * 3, 12), CYAN)
        if state == "waiting":
            d.line((3, 4, 4, 3), AMBER)
            d.line((4, 3, 3, 2), AMBER)
            d.point((3, 6), AMBER)
        if state == "complete":
            d.line((4, 4, 6, 6, 11, 1), "#afff9b", 1)
    elif kind == "core":
        t.rectangle((4, 3, 11, 11), "#888888")
        t.rectangle((5, 4, 10, 10), "#ffffff")
        d.rectangle((6, 5, 9, 9), "#fff5bf")
        t.rectangle((6, 5, 9, 9), CLEAR)
        d.line((4, 2, 11, 2), EDGE)
    elif kind == "outpost":
        t.rectangle((5, 6, 10, 11), "#dddddd")
        d.rectangle((7, 7, 8, 9), WHITE)
        t.rectangle((7, 7, 8, 9), CLEAR)
        d.line((7, 1, 7, 6), EDGE)
        t.rectangle((7, 1, 8, 2), "#ffffff")
    elif kind == "interceptor":
        d.rectangle((7, 2, 8, 11), EDGE)
        t.line((4, 2, 11, 2), "#ffffff")
        t.line((4, 2, 4, 6), "#dddddd")
        t.line((11, 2, 11, 6), "#dddddd")


for row in range(ROWS):
    for frame in range(FRAMES):
        body, team, d, t = tile(row, frame)
        if row < 5: building(d, t, "research", ["idle", "active", "waiting", "complete", "construction"][row], frame)
        elif row < 8: building(d, t, ["core", "outpost", "interceptor"][row - 5], "idle", frame)
        elif row == 8:
            t.line((3, 4, 8, 4, 8, 12, 13, 12), "#bbbbbb", 1)
            for x, y in ((3, 4), (8, 4), (13, 12)): t.rectangle((x - 1, y - 1, x + 1, y + 1), "#ffffff")
        elif row == 9:
            d.line((3, 13, 12, 4), CYAN, 3)
            d.line((10, 2, 10, 6, 14, 6), EDGE, 2)
        elif row == 10:
            d.line((3, 3, 12, 12), "#fa686a", 2)
            d.line((12, 3, 3, 12), "#fa686a", 2)
        elif row == 11:
            d.line((4, 4, 11, 4, 8, 11), CYAN, 1)
            for x, y in ((4, 4), (11, 4), (8, 11)): d.rectangle((x - 1, y - 1, x + 1, y + 1), WHITE)
        else:
            d.rectangle((4, 3, 6, 12), EDGE)
            d.rectangle((9, 3, 11, 12), EDGE)
        BODY.paste(body, (frame * CELL, row * CELL))
        TEAM.paste(team, (frame * CELL, row * CELL))

OUT.mkdir(parents=True, exist_ok=True)
BODY.save(OUT / "tactical_body.png")
TEAM.save(OUT / "tactical_team.png")
