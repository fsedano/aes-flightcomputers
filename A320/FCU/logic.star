def on_bringup(fc_id):
    print("[bringup]", fc_id)
    register_periodic(1000, update_tt)


def update_tt():
    # pass
    # arinc429.labels.FCUE2.fcu_dw1_274.discrete.spd_match_switching = True
    # arinc429.labels.FCUE2.altitude_204.value = 111
    # arinc429.labels.FCUE2.maneuvring_speed_ref_051.value = 200
    # arinc429.labels.FCUE2.v2_speed_073.value = 140
    # arinc429.labels.FCUE2.approach_speed_fm_077.value = 141
    # arinc429.labels.FCUE2.preset_spd_103.value = 142
    # arinc429.labels.FCUE2.runway_hdg_mem_105.value = 20
    # arinc429.labels.FCUE2.preset_mach_106.value = 0.5
    arinc429.labels.FCUE2.preset_spd_107.value = 143
    # arinc429.labels.FCUE2.fcu_word5_145.discrete.mach_sel = True
    # arinc429.labels.FCUE2.fcu_word5_145.discrete.spd_thrust_submode = True
    # arinc429.labels.FCUE2.fcu_word5_145.discrete.auto_spd_control = True
    arinc429.labels.FCUE2.fcu_word5_145.discrete.auto_spd_control = True
    # arinc429.labels.FCUE2.fcu_word5_145.discrete.manual_spd_control = True
    # arinc429.labels.FCUE2.fcu_word5_145.discrete.fpa_sel_submode = True
    arinc429.labels.FCUE2.fcu_word5_145.discrete.spd_window_display = True
    arinc429.labels.FCUE2.fcu_word5_145.discrete.top_of_spd_synchro = True
    # arinc429.labels.FCUE2.altitude_204.value = 12000
    # arinc429.labels.FCUE2.mach_205.value = 0.4
    arinc429.labels.FCUE2.cas_206.value = 210
    arinc429.labels.FCUE2.fcu_ats_dw_270.discrete.ats_spd_mach_mode = False
    arinc429.labels.FCUE2.fcu_ats_dw_270.discrete.fcu_mach_selection = False
    # arinc429.labels.FCUE2.ats_fma_dw_271.discrete.clb_display = True
    # arinc429.labels.FCUE2.fadec_dw_272.discrete.core_speed_at_or_above_idle = True
    # arinc429.labels.FCUE2.discrete_word_3_273.discrete.hdg_preset = True
    # arinc429.labels.FCUE2.discrete_word_3_273.discrete.alt_acq_arm = True
    # arinc429.labels.FCUE2.discrete_word_3_273.discrete.alt_acq_mode_arm_possible = True
    # arinc429.labels.FCUE2.fcu_dw1_274.discrete.spd_match_switching = True
    # arinc429.labels.FCUE2.discrete_word_6_276.discrete.fadec_own_supplied = True
    # arinc429.labels.FCUE2.discrete_word_6_276.discrete.irs_3_valid = True
    # arinc429.labels.FCUE2.discrete_word_6_276.discrete.adc_own_acq = True
    # arinc429.labels.FCUE2.approach_spd_target_304.value = 144
    # arinc429.labels.FCUE2.synchro_spd_value_305.value = 145
    # arinc429.labels.FCUE2.low_target_spd_margin_306.value = 140
    # arinc429.labels.FCUE2.hi_target_spd_margin_307.value = 220
    # arinc429.labels.FCUE2.track_317.value = 100
    # arinc429.labels.FCUE2.accuracy_input_144.value = 10
    
    
    