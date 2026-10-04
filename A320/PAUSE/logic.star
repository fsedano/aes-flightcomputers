# A320 PAUSE — the STATS MCDU subsystem (flight-sim pause) as its own ARINC 739
# LRU.
#
# The STATS subsystem logic lives in status.star; this script loads it and
# attaches it to the engine. `a739` is a predeclared module provided by the
# gateway.
#
# STATS mirrors the sim's "paused" value (sim_params lists "paused"; the FC's
# "sim" port is bound to a flight-sim instance) and toggles it with a
# line-select key via send_to_sim().

load("status.star", status = "LRU")

def on_bringup(fc_id):
    print("[pause/stats] bringup", fc_id)
    a739.attach(
        lrus = [status],
        sal_candidates = ["306"],
        tx_ports = ["MCDU TX"],
        root_menu = True,
        heartbeat_ms = 200,
        tick_ms = 50,
        max_records_per_msg = None,
        chunk_max_words = 200,
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
    a739.on_sim_data(key, value)
