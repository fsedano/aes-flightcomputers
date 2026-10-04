# A320 HELLO — the demo MCDU subsystem as its own ARINC 739 LRU.
#
# The HELLO subsystem logic lives in hello.star; this script loads it and
# attaches it to the engine. `a739` is a predeclared module provided by the
# gateway, so no engine import is needed.

load("hello.star", hello = "LRU")

def on_bringup(fc_id):
    print("[hello] bringup", fc_id)
    a739.attach(
        lrus = [hello],
        sal_candidates = ["277"],
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
