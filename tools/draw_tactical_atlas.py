"""Author the original 16px sprites. Optional tooling: Python + Pillow, no runtime dependency.

The checked-in PNGs can also be edited directly. White/gray pixels on the separate
team layer are tinted at render time; cyan glass and metal belong to the body.
"""
from pathlib import Path
from PIL import Image, ImageDraw

CELL, FRAMES, ROWS = 16, 4, 21
OUT = Path(__file__).resolve().parents[1] / "assets" / "pixel"
BODY = Image.new("RGBA", (CELL * FRAMES, CELL * ROWS))
TEAM = Image.new("RGBA", BODY.size)
INK, DARK, METAL, EDGE = "#0d1520", "#233342", "#526979", "#a6c6ce"
CYAN, GLASS, WHITE, AMBER = "#47d8ff", "#2377ab", "#e0fbff", "#f4a740"
CLEAR = (0, 0, 0, 0)


def tile(row, frame):
    body, team = Image.new("RGBA", (CELL, CELL)), Image.new("RGBA", (CELL, CELL))
    return body, team, ImageDraw.Draw(body), ImageDraw.Draw(team)


def worker(d, t, state, frame):
    bob = (frame % 2) if state == "move" else 0
    d.rectangle((4, 6 + bob, 11, 13), INK)
    t.rectangle((5, 7 + bob, 10, 11), "#c5c5c5")
    t.rectangle((4, 4 + bob, 11, 7 + bob), "#ffffff")  # hard hat, wide brim
    t.line((4, 6 + bob, 11, 6 + bob), "#bbbbbb")
    d.rectangle((3, 7 + bob, 12, 8 + bob), METAL)
    d.rectangle((5, 8 + bob, 10, 9 + bob), INK)
    d.rectangle((6, 8 + bob, 9, 8 + bob), CYAN)  # visor
    d.point((6, 5 + bob), WHITE)
    t.rectangle((3, 7 + bob, 12, 9 + bob), CLEAR)  # metal/visor must stay un-tinted
    t.point((6, 5 + bob), CLEAR)
    d.rectangle((5, 12, 6, 14 - (frame % 2 if state == "move" else 0)), METAL)
    d.rectangle((9, 12, 10, 13 + (frame % 2 if state == "move" else 1)), EDGE)
    d.rectangle((2, 9, 3, 11), DARK)  # backpack
    if state in ("mine", "build"):
        if frame % 2 == 0:
            d.line((11, 9, 14, 4), METAL, 1)
            d.line((11, 4, 15, 5), EDGE, 1)
        else:
            d.line((10, 10, 14, 9), METAL, 1)
            d.line((14, 7, 14, 11), EDGE, 1)
            d.point((15, 8), WHITE if state == "mine" else CYAN)
        if state == "build":
            d.rectangle((1, 10, 4, 12), METAL)
            d.point((2, 10), CYAN)
    if state == "blocked": d.point((7, 3), AMBER)


def warrior(d, t, state, frame):
    bob = (frame % 2) if state == "move" else 0
    d.rectangle((2, 4 + bob, 13, 11), INK)
    d.rectangle((3, 5 + bob, 12, 10), METAL)
    t.rectangle((3, 5 + bob, 4, 10), "#b0b0b0")
    t.rectangle((11, 5 + bob, 12, 10), "#b0b0b0")
    d.rectangle((5, 3 + bob, 10, 8 + bob), EDGE)  # armored helmet
    d.rectangle((6, 6 + bob, 9, 7 + bob), INK)
    d.line((6, 6 + bob, 9, 6 + bob), CYAN)
    d.rectangle((4, 10, 6, 14 - (frame % 2 if state == "move" else 0)), METAL)
    d.rectangle((9, 10, 11, 13 + (frame % 2 if state == "move" else 1)), METAL)
    t.polygon([(5, 8), (10, 8), (10, 12), (7, 14), (5, 12)], "#eeeeee")  # shield
    d.line((7, 9, 7, 12), DARK)
    d.line((6, 10, 9, 10), DARK)
    t.line((7, 9, 7, 12), CLEAR)
    t.line((6, 10, 9, 10), CLEAR)
    if state == "attack":
        reach = 1 + frame % 2
        d.line((12, 9, 14, 4 - reach), WHITE, 1)
        d.line((12, 7, 15, 8), METAL, 1)
        d.point((15, 3), CYAN)
    else:
        d.line((13, 9, 13, 3), EDGE, 1)
        d.line((12, 8, 14, 8), DARK, 1)


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
        if row < 5: worker(d, t, ["idle", "move", "mine", "build", "blocked"][row], frame)
        elif row < 8: warrior(d, t, ["idle", "move", "attack"][row - 5], frame)
        elif row < 13: building(d, t, "research", ["idle", "active", "waiting", "complete", "construction"][row - 8], frame)
        elif row < 16: building(d, t, ["core", "outpost", "interceptor"][row - 13], "idle", frame)
        elif row == 16:
            t.line((3, 4, 8, 4, 8, 12, 13, 12), "#bbbbbb", 1)
            for x, y in ((3, 4), (8, 4), (13, 12)): t.rectangle((x - 1, y - 1, x + 1, y + 1), "#ffffff")
        elif row == 17:
            d.line((3, 13, 12, 4), CYAN, 3)
            d.line((10, 2, 10, 6, 14, 6), EDGE, 2)
        elif row == 18:
            d.line((3, 3, 12, 12), "#fa686a", 2)
            d.line((12, 3, 3, 12), "#fa686a", 2)
        elif row == 19:
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
