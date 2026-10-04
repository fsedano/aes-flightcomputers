# RMI (Radio Magnetic Indicator) driven from the simulator's heading.
#
# The sim publishes the agnostic key "heading" (mapped, on this aircraft, to
# sim/cockpit2/gauges/indicators/heading_electric_deg_mag_pilot — see the sim's
# Aircraft datarefs). We convert degrees -> radians and drive a resolver output
# on the analog card ("RMI heading", mode SYNCHRO_3_PHASE, value in radians).

DEG2RAD = 0.017453292519943295


def on_bringup(fc_id):
    print("bringup:", fc_id, "- waiting for sim heading")


def on_data_from_sim(sim_id, key, value):
    # Every sim update lands here. Print it so we can watch it live in the
    # Debug console while we bring the instrument up.
    print("sim", key, "=", value)
    if key != "heading":
        return
    # Synchro value is a shaft angle in radians.
    analog.synchro.set("RMI heading", float(value) * DEG2RAD)
