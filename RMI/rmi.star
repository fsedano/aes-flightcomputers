# Starlark for RMI instrument.
#
# Demonstrates the arinc429.labels.<equipment>.<label> API in both directions:
#   - on TX, mutate arinc429.labels.c_irs.<name>.value / .discrete.* — the
#     auto-TX scheduler pushes the word on the bound output port.
#   - on RX, on_linecard_data receives the same persistent
#     label_value object whose .value / .discrete.* / .ssm decode the
#     wire word per the equipment file (c_irs_unit.json).

# Local copy of the last heading reported by the connected sim, in degrees.
state = {"heading_deg": 0.0, "att_inv": False}


def on_bringup(fc_name):
    print("Bringup:", fc_name)
    register_periodic(1000, send_outputs)

def send_outputs():
    state["att_inv"] = not state["att_inv"]
    arinc429.labels.c_irs.irs_disc.discrete.att_inv = state["att_inv"]
    # print("tx irs_disc: att_inv=%s" % state["att_inv"])


def on_data_from_sim(sim_id, key, value):
    if key != "heading":
        return
    state["heading_deg"] = float(value)
    arinc429.labels.c_irs.hdg_m_bcd.value = float(value)

def on_linecard_data(port, data):
    label_octal = data["label"]
    packet = data["packet"]
    lbl = data["value"]

    # `lbl` is the same persistent label_value as arinc429.labels.c_irs.<name>
    # when the FC has an equipment_file and the incoming label is
    # known; otherwise it is the legacy decoded dict. Re-asserting
    # .packet here forwards the verbatim received word back out on
    # any bound TX port.
    if type(lbl) != "arinc_label":
        # Fallback for unknown arinc429.labels.
#        print("rx unknown", label_octal, "packet=0x%x" % packet)
        return

    lbl.packet = packet

    if lbl.name == "hdg_m_bcd":
        # BCD heading decoded straight to a float.
        delta = lbl.value - state["heading_deg"]
        #print("rx heading: %f deg (sim says %f, delta=%f)" % (
        #            lbl.value, state["heading_deg"], delta))
        # Forward the decoded value back to the connected sim, if any.
        send_to_sim("rmi_heading", lbl.value)


    elif lbl.name == "irs_disc":
        # IRS Discrete Word 1: each pad_bit is exposed as a named bool.
        d = lbl.discrete
        # print("rx irs_disc: nav_mode=%s align_mode=%s att_inv=%s set_hdg=%s ssm=%d" % (
        #     d.nav_mode, d.align_mode, d.att_inv, d.set_hdg, lbl.ssm))
        # if d.align_mode:
        #     print("  IRS still aligning - heading not yet valid")
