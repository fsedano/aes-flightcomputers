# CFDIU skeleton — MCDU-facing buses only (AMM: BUS1 to MCDU1, BUS2 to MCDU2).

SAL = 0o302

state = {"n": 0}

def on_bringup(fc_id):
    print("[cfdiu] bringup", fc_id)
    register_periodic(1000, _ident)
    register_periodic(200, _link)

def _ident():
    arinc429.labels.cfdiu_bus1.lru_id_172.value = SAL
    arinc429.labels.cfdiu_bus2.lru_id_172.value = SAL

def _link():
    state["n"] = (state["n"] + 1) % 0x7FFFF
    arinc429.labels.cfdiu_bus1.a739_link_220.value = state["n"]
    arinc429.labels.cfdiu_bus2.a739_link_220.value = state["n"]
