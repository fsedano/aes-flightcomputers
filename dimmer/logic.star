# Demo: sweep a 400 Hz dimmer between 0 and 100 % once every few seconds,
# letting the card ramp each step. Bind LAMPS to a dimmer card's dim.0.
#
#   dimmer.set(port, level, on=True, ramp_ms=0)
#     level    0.0..1.0 of the card's advertised base voltage
#     on       False stops the carrier at once (pin low)
#     ramp_ms  full-scale transition time the card ramps with; 0 = immediate

_state = {"level": 0.0, "up": True}

def on_bringup(name):
    print("[bringup]", name)
    register_periodic(500, tick)

def on_linecard_data(port, data):
    pass

def on_data_from_sim(sim_id, key, value):
    pass

def tick():
    dimmer.set("LAMPS", _state["level"], on=True, ramp_ms=400)
    step = 0.1 if _state["up"] else -0.1
    _state["level"] = _state["level"] + step
    if _state["level"] >= 1.0:
        _state["level"] = 1.0
        _state["up"] = False
    elif _state["level"] <= 0.0:
        _state["level"] = 0.0
        _state["up"] = True
