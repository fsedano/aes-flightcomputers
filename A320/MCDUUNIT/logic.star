# MCDU unit skeleton — the display unit itself as a computer node.
# One transmitter, multi-dropped to every subsystem; five receivers.
# No display logic: emits the A739 housekeeping words the real unit sends.

state = {"n": 0}

def on_bringup(fc_id):
    print("[mcdu] bringup", fc_id)
    register_periodic(1000, _ident)
    register_periodic(500, _dw1)
    register_periodic(200, _polls)

def _ident():
    # '39' identifier + Maintenance Word #1 ride the same ~1 s cadence.
    arinc429.labels.mcdu_out.mcdu_id_377.value = 39
    arinc429.labels.mcdu_out.maint_w1_350.value = 0

def _dw1():
    arinc429.labels.mcdu_out.mcdu_dw1_270.discrete.mcdu_fail = False

def _polls():
    # SAL-addressed protocol words to each subsystem, all on the one bus.
    state["n"] = (state["n"] + 1) % 0x7FFFF
    n = state["n"]
    arinc429.labels.mcdu_out.sal_306_fmgc.value = n
    arinc429.labels.mcdu_out.sal_302_cfdiu.value = n
    arinc429.labels.mcdu_out.sal_304_acars.value = n
    arinc429.labels.mcdu_out.sal_305_dmu.value = n
