# STATS — gateway status page with a live flight-sim control: mirrors the
# sim's "paused" value (pushed through the subscription via sim_key /
# on_sim_update / set_page) and toggles it with a line-select key that calls
# send_to_sim(). The display is not updated optimistically — it flips when
# the simulator echoes the new value back, so the page always shows the
# sim's real state.
#
# Plumbing this needs outside this file:
#   - definition.json lists "paused" in sim_params (subscription interest)
#   - the FC instance's "sim" port is bound to a flight-sim instance
#   - the sim maps "paused" (X-Plane: dist/flightsim/x-plane-toliss/datarefs.json
#     reads sim/time/paused and writes via the pause_on/pause_off commands,
#     because that dataref is read-only)
#
# `a739` is a predeclared module provided by the gateway.

_state = {"paused": None}  # None until the first sim update arrives

def _page():
    p = _state["paused"]
    if p == None:
        val, col = "----", a739.color.AMBER
    elif p:
        val, col = "ON", a739.color.AMBER
    else:
        val, col = "OFF", a739.color.GREEN
    return [
        a739.line(1, "X-PLANE STATUS", a739.color.GREEN),
        a739.line(3, "LINK    : UP", a739.color.CYAN),
        a739.line(4, "ENGINE  : AES-GW2", a739.color.CYAN),
        a739.line(6, "PAUSED  : %s" % val, col),
        a739.line(a739.lsk_line(a739.key.L4), "<TOGGLE PAUSE", a739.color.YELLOW, select = a739.key.L4),
    ]

def _on_sim_update(value, h):
    p = bool(value)
    if p == _state["paused"]:
        return
    print("[stats] sim paused -> %s" % p)
    _state["paused"] = p
    h.set_page(_page())

def _on_select(text, h):
    if text == "<TOGGLE PAUSE":
        send_to_sim("paused", 0 if _state["paused"] else 1)

def _on_key(key_code, h):
    print("Got key %s" % key_code)

LRU = a739.lru(
    name = "STATS",
    pages = {"main": _page()},
    initial = "main",
    on_select = _on_select,
    on_sim_update = _on_sim_update,
    on_key = _on_key,
    sim_key = "paused",
)
