# A320 MCDU — the FMGC head (ARINC 739 onside FM subsystem).
#
# Each MCDU subsystem is now its OWN flight computer on the shared ARINC 739
# bus: this FC drives ONLY the FMGC (sim screen mirror, master SAL 173). The
# demo HELLO LRU lives in the A320/HELLO FC and the pause STATS LRU in the
# A320/PAUSE FC. Every FC heartbeats its single SAL on its own MCDU input
# port, so the real MCDU lists all three on its root menu and routes keys/data
# to whichever the user selects — exactly as a real aircraft multiplexes
# independent LRUs onto one MCDU.
#
# Each FC owns its subsystem .star (mirror.star here, hello.star in A320/HELLO,
# status.star in A320/PAUSE). The ARINC 739 protocol engine is provided by the
# gateway as the predeclared `a739` module, so every FC drives it the same way.
#
# Sim independence + multi-MCDU: this FC is one MCDU head. It mirrors a
# sim-neutral screen (`mcdu1.screen`) and forwards the hardware keyboard back to
# the sim (`mcdu1.key`); the simulator layer (ToLiss, ProSim, ...) owns every
# native format quirk. A second F/O MCDU is its OWN FC instance (per-instance
# `mcdu1.screen -> mcdu2.screen` alias); the keypress path is still single-head
# (deferred Phase-3 work, see dev_notes/mcdu_generalization_plan.md §"Phase 3").

load("mirror.star", mirror = "LRU")

def on_bringup(fc_id):
    print("[mcdu/fmgc] bringup", fc_id)
    a739.attach(
        # One LRU = the FMGC. root_menu=True advertises its SAL on the MCDU's
        # own root menu (the engine draws no wrapper menu); master_sals binds
        # the dedicated function keys (DIR/PROG/INIT/...) to it — the MCDU
        # forwards those to the master-flagged subsystem on its high-speed
        # onside input port.
        lrus = [mirror],
        sal_candidates = ["173"],
        tx_ports = ["MCDU TX"],
        root_menu = True,
        master_sals = ["173"],
        heartbeat_ms = 200,
        tick_ms = 50,
        # Whole page in ONE RTS->CTS->burst->ACK transfer, like the real
        # aircraft (proven 2026-06-20, dev_notes/mcdu_perf_investigation.md §7):
        # no per-record cap; chunk_max_words 200 bounds a physical <=14-line page
        # to a single transfer with margin.
        max_records_per_msg = None,
        chunk_max_words = 200,
        # MCDU #1's address label (pins 30->23 strap). Normally learned from
        # each ENQ; seeded so a mid-session script reload stays usable before
        # the next ENQ arrives.
        mcdu_mal = "220",
        debug = False,
    )

def on_linecard_data(port, data):
    device_id = data["device"]
    channel = data["channel"]
    label_octal = data["label"]
    packet = data["packet"]
    lbl = data["value"]
    a739.on_packet(port, device_id, channel, label_octal, packet, lbl)

def on_data_from_sim(sim_id, key, value):
    if key == "mcdu1.screen":
        print("[mcdu/fmgc] sim screen update (%d bytes)" % len(value))
    a739.on_sim_data(key, value)
