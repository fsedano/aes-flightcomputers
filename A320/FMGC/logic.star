# FMGC skeleton — MCDU-facing buses only (AMM 22-86-00). No FM logic;
# emits the two A739 housekeeping words so the buses carry live traffic.

SAL = 0o306

state = {"n": 0}

def on_bringup(fc_id):
    print("[fmgc] bringup", fc_id)
    register_periodic(1000, _ident)
    register_periodic(200, _link)

def _ident():
    # A739A 3.7.1: label 172 carries the subsystem SAL at ~1 s.
    arinc429.labels.fmgc_own_link.lru_id_172.value = SAL
    arinc429.labels.fmgc_opp_link.lru_id_172.value = SAL

def _link():
    state["n"] = (state["n"] + 1) % 0x7FFFF
    arinc429.labels.fmgc_own_link.a739_link_220.value = state["n"]
    arinc429.labels.fmgc_opp_link.a739_link_220.value = state["n"]
