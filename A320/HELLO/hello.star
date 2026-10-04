# HELLO — demo LRU showing the full authoring surface: two pages, line-select
# navigation between them, colors, and the SCARLETT page drives the MCDU
# annunciator lamps through a739.annunciators() (DC4 word, §3.7.3.7). No
# protocol code: the engine handles the A739 handshake, record framing,
# padding and page-swap hygiene.
#
# This LRU lives in its own FC (A320/HELLO). logic.star loads it and attaches
# it to the engine:
#   load("hello.star", hello = "LRU")
#   a739.attach(lrus = [hello], ...)
# `a739` is a predeclared module provided by the gateway.
#
# A class bundles the annunciator state with the callbacks, so on_select /
# on_key carry it via self instead of module-level globals.


# Character-set browser: every code the real unit accepts as record data
# (0x1C-0x1F + 0x20-0x5F — bench-measured, see docs/overfly.md), 24 codes per
# page. Each block shows the hex codes (small white) over the large-font
# glyphs (green) and the small-font glyphs (cyan); blank cells are real
# character-generator gaps, not transmission losses. Exception: 0x24 '$' and
# 0x40 '@' are transmit-REJECTED by the unit (SYN in every packing, bench
# 2026-08-08); the engine blanks them to spaces so their cells here are
# engine substitutions, not char-gen gaps.
def _charset_pages():
    codes = [0x1C, 0x1D, 0x1E, 0x1F]
    for c in range(0x20, 0x60):
        codes.append(c)
    hexd = "0123456789ABCDEF"
    pages = {}
    n_pages = (len(codes) + 23) // 24
    for pg in range(n_pages):
        chunk = codes[pg * 24:(pg + 1) * 24]
        lines = [a739.line(1, "CHARSET %d/%d" % (pg + 1, n_pages), a739.color.GREEN)]
        for b in range(0, len(chunk), 8):
            row = 2 + (b // 8) * 3
            label = ""
            chars = ""
            for c in chunk[b:b + 8]:
                label += hexd[c // 16] + hexd[c % 16] + " "
                chars += chr(c) + "  "
            lines.append(a739.line(row, label[:24], a739.color.WHITE, small = True))
            lines.append(a739.line(row + 1, chars[:22], a739.color.GREEN))
            lines.append(a739.line(row + 2, chars[:22], a739.color.CYAN, small = True))
        lines.append(a739.line(13, "<RETURN", a739.color.YELLOW, select = a739.key.L6))
        nxt = (pg + 1) % n_pages + 1
        lines.append(a739.line(13, "PAGE %d>" % nxt, a739.color.YELLOW, col = 17, select = a739.key.R6))
        pages["cs%d" % (pg + 1)] = lines
    return pages


class Hello:
    MAIN = [
        a739.line(1, "LOOKS LIKE IT IS", a739.color.GREEN),
        a739.line(2, "ARINC 739 MODULE", a739.color.CYAN),
        a739.line(3, "BY FRAN!", a739.color.WHITE),
        a739.line(10, "THIS IS THE BEST", a739.color.RED),
        a739.line(a739.lsk_line(a739.key.L5), "<CHARSET", a739.color.CYAN, select = a739.key.L5),
        a739.line(a739.lsk_line(a739.key.R6), "               2ND PAGE>", a739.color.YELLOW, select = a739.key.R6),
    ]

    def __init__(self):
        self.ann = {"exec": False, "dspy": False, "msg": False, "ofst": False}

    def _onoff(self, b):
        return "ON " if b else "OFF"

    def _scarlett(self):
        return [
            a739.line(1, "DEMO TEST PAGE", a739.color.GREEN),
            a739.line(2, "ANSWER  : 42", a739.color.MAGENTA),
            a739.line(4, "ANNUNCIATOR LIGHTS", a739.color.WHITE),
            a739.line(a739.lsk_line(a739.key.L2), "<EXEC  " + self._onoff(self.ann["exec"]), a739.color.CYAN, select = a739.key.L2),
            a739.line(a739.lsk_line(a739.key.L3), "<DSPY  " + self._onoff(self.ann["dspy"]), a739.color.CYAN, select = a739.key.L3),
            a739.line(a739.lsk_line(a739.key.L4), "<MSG   " + self._onoff(self.ann["msg"]), a739.color.CYAN, select = a739.key.L4),
            a739.line(a739.lsk_line(a739.key.L5), "<OFST  " + self._onoff(self.ann["ofst"]), a739.color.CYAN, select = a739.key.L5),
            a739.line(a739.lsk_line(a739.key.L6), "<RETURN", a739.color.YELLOW, select = a739.key.L6),
        ]

    def _toggle(self, name, lru):
        self.ann[name] = not self.ann[name]
        # One lamp per call; the engine repeats the DC4 word until the MCDU ACKs.
        a739.annunciators(**{name: self.ann[name]})
        lru.set_page(self._scarlett())

    def on_key(self, k, lru):
        print("Got key %s" % k)

    def on_select(self, text, lru):
        print("Text is %s" % text)
        if text == "2ND PAGE>":
            lru.set_page(self._scarlett())
        elif text == "<CHARSET":
            lru.show("cs1")
        elif text.startswith("PAGE ") and text.endswith(">"):
            lru.show("cs" + text[5:-1])
        elif text == "<RETURN":
            lru.show("main")
        elif text.startswith("<EXEC"):
            self._toggle("exec", lru)
        elif text.startswith("<DSPY"):
            self._toggle("dspy", lru)
        elif text.startswith("<MSG"):
            self._toggle("msg", lru)
        elif text.startswith("<OFST"):
            self._toggle("ofst", lru)


_hello = Hello()

_PAGES = {"main": Hello.MAIN}
_PAGES.update(_charset_pages())

LRU = a739.lru(
    name = "HELLO",
    pages = _PAGES,
    initial = "main",
    on_select = _hello.on_select,
    on_key = _hello.on_key,
)
