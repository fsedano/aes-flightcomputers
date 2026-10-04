# mirror.star — sim-neutral FMGC mirror: paints a flight-sim's MCDU screen onto
# this real A320 MCDU over ARINC 739.
#
# The sim layer (X-Plane sim.star, the ProSim bridge, ...) decodes whatever its
# native MCDU format is and pushes a SIM-NEUTRAL canonical screen on the sim key
# `mcdu1.screen`. This LRU knows nothing about X-Plane datarefs or ProSim XML —
# all format quirks live on the simulator side, per dev_notes/mcdu_integration.md.
#
# Canonical screen (JSON string, see dev_notes/mcdu_generalization_plan.md):
#   {"rows": [ {"row": <1..14>,
#               "runs": [ {"col": <1..24>, "text": "...",
#                          "color": "w|g|c|y|m|a|r", "font": "L|s"}, ... ]},
#             ... ]}
# Rows are display lines 1..14 (title, 6×(label,content), scratchpad); empty
# rows may be omitted.
#
# ARINC-sink render policy: one display row is one ARINC record. The row's
# color/font runs are emitted as separate CNTRL+DATA segments at their real
# 1-based columns. Bench validation on the real A320 MCDU showed column-
# positioned CNTRL groups are ACKed and render correctly (so long as no segment
# runs past column 24); flattening a row to one dominant color was an earlier
# workaround, not a hardware limit. Dense single-color rows are still sent as a
# single spaced segment to keep records small and avoid SYNs from excessive
# repeated CNTRL groups.
#
# This LRU sits in the FMGC slot (master SAL 173) so it owns the dedicated
# function keys (DIR/INIT/F-PLN/...) the MCDU forwards on the onside port — the
# hook point for driving the sim from the hardware keyboard (see Phase 2).

# `a739` is a predeclared module provided by the gateway.

_C = a739.color

_COLOR = {
    "w": _C.WHITE,
    "g": _C.GREEN,
    "c": _C.CYAN,
    "y": _C.YELLOW,
    "m": _C.MAGENTA,
    "a": _C.AMBER,
    "r": _C.RED,
}

# Per-record word caps observed on the bench MCDU. A row sent as exact
# column-positioned runs is safe up to ~20 words; the heavier base-plus-overlay
# fallback (a full-row clear followed by colored overlays) has SYNed above ~15.
_MAX_EXACT_RECORD_WORDS = 20
_MAX_OVERLAY_RECORD_WORDS = 15
# When this many rows change at once (page transition), repaint the whole page
# instead of streaming per-row updates.
_FULL_REPAINT_ROWS = 4
# ToLiss special glyphs carried verbatim in run text (the sim layer maps its
# native byte codes onto these A739A wire codes). Used only for overlay
# priority so prompts/boxes win the limited record budget.
_BOX = chr(0x1D)
_DOWN_ARROW = chr(0x1E)
_RIGHT_ARROW = chr(0x1F)
_UP_ARROW = chr(0x5E)
_LEFT_ARROW = chr(0x5F)

_state = {
    "last": None,
    "forward_keys": True,
    "line_sigs": {},
    "have_page": False,
}

def set_key_forwarding(enabled):
    _state["forward_keys"] = enabled

# --- keypresses: real MCDU -> sim ------------------------------------------
#
# Every key the MCDU forwards to this subsystem (LSKs, alphanumerics, the
# dedicated function keys on the onside port, CLR, slew) is translated to a
# SIM-NEUTRAL key name and sent on `mcdu1.key`. The sim layer maps that name to
# its native action (X-Plane: activate a ToLiss command; ProSim: pulse a switch
# dataref). Scratchpad row 14 is owned by the sim's full-screen mirror; the
# engine's local scratchpad echo is disabled for this LRU so the two writers
# cannot race.

_KEY = a739.key

# a739 function/slew key code -> canonical name.
_FN_NAME = {
    _KEY.DIR: "DIR",
    _KEY.PROG: "PROG",
    _KEY.PERF: "PERF",
    _KEY.INIT: "INIT",
    _KEY.DATA: "DATA",
    _KEY.FPLN: "FPLN",
    _KEY.RADNAV: "RADNAV",
    _KEY.FUELPRED: "FUELPRED",
    _KEY.SECFPLN: "SECFPLN",
    _KEY.ATC: "ATC",
    _KEY.AIRPORT: "AIRPORT",
    _KEY.CLR: "CLR",
    _KEY.PLUSMINUS: "PLUSMINUS",
    _KEY.OVFY: "OVFY",
    _KEY.PREV_PAGE: "SLEWLEFT",
    _KEY.NEXT_PAGE: "SLEWRIGHT",
    _KEY.UP: "SLEWUP",
    _KEY.DOWN: "SLEWDOWN",
    0x60: "MENU",  # FN_KEY_LO = MCDU MENU (no a739.key constant)
}

def _key_name(code):
    """a739 key code -> canonical key name, or None if we don't map it yet."""
    if code >= 0x70 and code <= 0x75:
        return "LSK%dL" % (code - 0x70 + 1)
    if code >= 0x78 and code <= 0x7D:
        return "LSK%dR" % (code - 0x78 + 1)
    if code in _FN_NAME:
        return _FN_NAME[code]
    if (code >= 0x41 and code <= 0x5A) or (code >= 0x30 and code <= 0x39):
        return chr(code)  # A-Z, 0-9
    if code == 0x2E:
        return "DOT"
    if code == 0x2F:
        return "SLASH"
    if code == 0x20:
        return "SP"
    return None

def _on_key(key_code, h):
    name = _key_name(key_code)
    if name == None:
        print("[mirror] unmapped MCDU key 0x%x" % key_code)
        return
    if not _state["forward_keys"]:
        return
    send_to_sim("mcdu1.key", name)

def _blank_row(row_no):
    return [a739.line(row_no, " " * 24, _C.WHITE)]

def _style_key(run):
    return "%s:%s:%d" % (
        run.get("color", "w"),
        run.get("font", "L"),
        run.get("attr", 0),
    )

def _color_attr_key(run):
    return "%s:%d" % (
        run.get("color", "w"),
        run.get("attr", 0),
    )

def _spaced_text(runs):
    cells = [" "] * 24
    for run in runs:
        col = run.get("col", 1)
        text = run.get("text", "")
        for i in range(len(text)):
            c = col - 1 + i
            if c >= 0 and c < 24:
                cells[c] = text[i]
    return "".join(cells)

def _dominant_font(runs):
    # Preserve Airbus label rows as small, but prefer large when any large
    # visible data is present on an otherwise single-color row.
    for run in runs:
        if run.get("font", "L") == "L" and run.get("text", "").replace(" ", "") != "":
            return "L"
    return "s"

def _dominant_style(runs):
    counts = {}
    styles = {}
    best = None
    best_count = -1
    for run in runs:
        key = _style_key(run)
        visible = len(run.get("text", "").replace(" ", ""))
        if key not in styles:
            styles[key] = run
        counts[key] = counts.get(key, 0) + visible
        if counts[key] > best_count:
            best = styles[key]
            best_count = counts[key]
    if best == None:
        best = runs[0]
    return {
        "key": _style_key(best),
        "color": best.get("color", "w"),
        "font": best.get("font", "L"),
        "attr": best.get("attr", 0),
    }

def _line_from_style(row_no, text, style):
    return a739.line(row_no, text,
                     _COLOR.get(style["color"], _C.WHITE),
                     small = style["font"] == "s",
                     attr = style["attr"])

def _pad_len(n):
    if n % 3 == 1:
        return n + 1
    return n

def _record_words(lines, first_clear = False):
    # Must match the a739 engine's record packing: STX + EOT/ETX, then one
    # CNTRL plus ceil(padded-len/3) DATA words per line segment. The bench MCDU
    # accepts exact positioned rows up to 20 words, but full-row base-plus-overlay
    # records have SYNed above roughly 15 words. The engine may pad the first
    # col-1 segment to clear the row, so include that expansion when deciding
    # whether a multi-color row is safe to send.
    total = 2
    for i in range(len(lines)):
        ln = lines[i]
        n = len(ln["text"])
        col = ln.get("col", 1)
        if first_clear and i == 0 and col == 1 and n < 24:
            n = 24
        total = total + 1 + ((_pad_len(n) + 2) // 3)
        # The engine splits a 3k+1 segment ending exactly at column 24 into
        # two segments instead of padding (a trailing pad would SYN at column
        # 25; a left-shifted pad overwrote the preceding segment's last cell):
        # same data words, one extra CNTRL word.
        if col > 1 and n > 1 and n % 3 == 1 and col + n - 1 == 24:
            total = total + 1
    return total

def _overlay_priority(run):
    # NOTE: run here is an a739.line dict, so "color" is the NUMERIC ARINC code
    # (_C.*), not the canonical "m"/"a" letter.
    text = run.get("text", "")
    if text.find(_BOX) >= 0:
        return 100
    # Meaningful FMC colors must win the limited overlay budget over plain
    # white/green fill: dropping an overlay repaints those cells in the base
    # color, so a significant glyph (an amber warning, a magenta constraint) must
    # never be the one sacrificed. A single magenta '*' beats a long green run.
    color = run.get("color", _C.WHITE)
    if color == _C.AMBER:
        return 90
    if color == _C.MAGENTA:
        return 88
    if color == _C.RED:
        return 86
    if color == _C.CYAN or color == _C.YELLOW:
        return 80
    if text.find("[") >= 0 or text.find("]") >= 0:
        return 70
    if (text.find(_LEFT_ARROW) >= 0 or text.find(_RIGHT_ARROW) >= 0 or
        text.find(_UP_ARROW) >= 0 or text.find(_DOWN_ARROW) >= 0):
        return 60
    return len(text.replace(" ", ""))

def _with_overlays_under_cap(base_line, overlays):
    out = [base_line]
    if _record_words(out, first_clear = True) > _MAX_OVERLAY_RECORD_WORDS:
        return out
    pending = []
    for i in range(len(overlays)):
        pending.append({"idx": i, "prio": _overlay_priority(overlays[i]), "line": overlays[i]})
    selected = []
    # Starlark has no custom-key sort. Pick the highest-priority remaining
    # overlay each pass, adding it only if the row still fits the observed limit.
    for _ in range(len(overlays)):
        if len(pending) == 0:
            continue
        best_i = 0
        best = pending[0]
        for i in range(1, len(pending)):
            item = pending[i]
            if item["prio"] > best["prio"] or (item["prio"] == best["prio"] and item["idx"] < best["idx"]):
                best_i = i
                best = item
        pending.pop(best_i)
        candidate = out + [best["line"]]
        if _record_words(candidate, first_clear = True) <= _MAX_OVERLAY_RECORD_WORDS:
            selected.append(best)
            out = candidate

    # Preserve original draw order for selected overlays.
    ordered = []
    for i in range(len(overlays)):
        for item in selected:
            if item["idx"] == i:
                ordered.append(item["line"])
                break
    return [base_line] + ordered

def _exact_row_lines(row_no, runs):
    out = []
    for i in range(len(runs)):
        run = runs[i]
        text = run.get("text", "")
        if text == "":
            continue
        col = run.get("col", 1)
        if col < 1:
            col = 1
        if col > 24:
            col = 24
        if i == 0 and col > 1:
            text = (" " * (col - 1)) + text
            col = 1
        color = _COLOR.get(run.get("color", "w"), _C.WHITE)
        small = run.get("font", "L") == "s"
        out.append(a739.line(row_no, text, color, col = col,
                             small = small, attr = run.get("attr", 0)))
    return out

def _merged_runs(runs, force_font = None):
    # force_font != None coalesces adjacent runs that differ ONLY in font into a
    # single run drawn in that font. The sim splits a row's large (cont) and
    # small (scont) glyphs into separate streams, so a constraint row arrives as
    # many color+font runs; merging on color alone collapses the font churn and
    # keeps every COLOR exact (only font granularity is given up — see the
    # color-exact fallback in _row_to_lines).
    merged = []
    for run in runs:
        text = run.get("text", "")
        if text == "":
            continue
        col = run.get("col", 1)
        end = col + len(text) - 1
        font = force_font if force_font != None else run.get("font", "L")
        if force_font != None:
            key = "%s:%d" % (run.get("color", "w"), run.get("attr", 0))
        else:
            key = _style_key(run)
        if len(merged) > 0:
            last = merged[-1]
            if key == last["key"] and col > last["end"]:
                last["text"] = last["text"] + (" " * (col - last["end"] - 1)) + text
                last["end"] = end
                continue
        merged.append({
            "key": key,
            "col": col,
            "end": end,
            "text": text,
            "color": run.get("color", "w"),
            "font": font,
            "attr": run.get("attr", 0),
        })
    return merged

def _row_to_lines(row):
    """Canonical row dict -> one or more a739.line segments for one ARINC row."""
    row_no = row.get("row", 1)
    runs = row.get("runs", [])
    if len(runs) == 0:
        return _blank_row(row_no)

    # If the row is one visible color/attribute, send it as one spaced segment.
    # This keeps dense white/cyan label/value rows small and avoids SYNs from
    # excessive repeated CNTRL groups, while still preserving the important
    # mixed-color rows such as amber boxes plus cyan values.
    ca = _color_attr_key(runs[0])
    one_color = True
    for run in runs:
        if _color_attr_key(run) != ca:
            one_color = False
            break
    if one_color:
        color = _COLOR.get(runs[0].get("color", "w"), _C.WHITE)
        font = _dominant_font(runs)
        attr = runs[0].get("attr", 0)
        return [a739.line(row_no, _spaced_text(runs), color,
                          small = font == "s", attr = attr)]

    merged_runs = _merged_runs(runs)
    exact = _exact_row_lines(row_no, merged_runs)
    if len(exact) > 0 and _record_words(exact, first_clear = True) <= _MAX_EXACT_RECORD_WORDS:
        return exact

    # Color-exact fallback. The font-aware exact render above blew the per-record
    # word budget (one extra CNTRL word per small/large transition). Re-merge on
    # color alone and draw the whole row in its dominant font: same-color runs
    # coalesce, the segment count drops, and EVERY color stays exact — so a dense
    # constraint row (green predictions + a magenta '*') still renders the star
    # magenta instead of falling to the lossy base-plus-overlay path, which drops
    # low-priority colors and repaints them in the base color (the F-PLN "magenta
    # star shows green" bug). Only font granularity is sacrificed, and only on
    # rows too dense to send otherwise.
    cmerged = _merged_runs(runs, force_font = _dominant_font(runs))
    cexact = _exact_row_lines(row_no, cmerged)
    if len(cexact) > 0 and _record_words(cexact, first_clear = True) <= _MAX_EXACT_RECORD_WORDS:
        return cexact

    base = _dominant_style(runs)
    base_line = _line_from_style(row_no, _spaced_text(runs), base)
    overlays = []
    for run in merged_runs:
        if run["key"] == base["key"]:
            continue
        color = _COLOR.get(run["color"], _C.WHITE)
        small = run["font"] == "s"
        overlays.append(a739.line(row_no, run["text"], color, col = run["col"],
                                  small = small, attr = run["attr"]))
    return _with_overlays_under_cap(base_line, overlays)

def _row_sig(row):
    runs = row.get("runs", [])
    parts = []
    for run in runs:
        parts.append("%d:%s:%s:%s:%d" % (
            run.get("col", 1),
            run.get("text", ""),
            run.get("color", "w"),
            run.get("font", "L"),
            run.get("attr", 0),
        ))
    return "|".join(parts)

def _rows_by_number(rows):
    out = {}
    for row in rows:
        out[row.get("row", 1)] = row
    return out

def _screen_from_value(value):
    obj = json_decode(value)
    rows = obj.get("rows", [])
    by_no = _rows_by_number(rows)
    sigs = {}
    out = []
    for line_no in range(1, 15):
        row = by_no.get(line_no)
        if row == None:
            sigs[line_no] = ""
            out.extend(_blank_row(line_no))
        else:
            sigs[line_no] = _row_sig(row)
            out.extend(_row_to_lines(row))
    return {"by_no": by_no, "sigs": sigs, "lines": out}

def _changed_row_count(sigs):
    n = 0
    for line_no in range(1, 15):
        if sigs.get(line_no, "") != _state["line_sigs"].get(line_no, ""):
            n = n + 1
    return n

def _apply_screen(value, h):
    screen = _screen_from_value(value)
    sigs = screen["sigs"]
    # First page, or a large page-transition, repaints the whole screen; small
    # deltas stream only the changed rows.
    if not _state["have_page"] or _changed_row_count(sigs) >= _FULL_REPAINT_ROWS:
        _state["line_sigs"] = sigs
        _state["have_page"] = True
        h.set_page(screen["lines"])
        return

    by_no = screen["by_no"]
    changed = []
    for line_no in range(1, 15):
        row = by_no.get(line_no)
        sig = sigs.get(line_no, "")
        if sig != _state["line_sigs"].get(line_no):
            _state["line_sigs"][line_no] = sig
            if row == None:
                changed.extend(_blank_row(line_no))
            else:
                changed.extend(_row_to_lines(row))
    h.update_lines(changed)

def _on_sim_update(value, h):
    # ProSim/X-Plane only emit on change, and we de-dupe identical payloads so an
    # unchanged screen never re-triggers an ARINC transfer.
    if value == _state["last"]:
        return
    _state["last"] = value
    _apply_screen(value, h)

LRU = a739.lru(
    name = "FMGC",
    sim_key = "mcdu1.screen",
    on_sim_update = _on_sim_update,
    on_key = _on_key,
    local_scratchpad = False,
    # White row-14 text is painted through the DC1 echo path — the only path
    # that draws the overfly triangle (0x6E) on the real unit (docs/overfly.md).
    dc1_scratchpad = True,
)
