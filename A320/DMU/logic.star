# DMU / AIDS skeleton — optional fit; a single one-way bus multi-dropped
# to both MCDUs (AMM: "BUS to MCDU1&2").

SAL = 0o305

state = {"n": 0}

def on_bringup(fc_id):
    print("[dmu] bringup", fc_id)
    register_periodic(1000, _ident)
    register_periodic(200, _link)

def _ident():
    arinc429.labels.dmu_bus.lru_id_172.value = SAL

def _link():
    state["n"] = (state["n"] + 1) % 0x7FFFF
    arinc429.labels.dmu_bus.a739_link_220.value = state["n"]
