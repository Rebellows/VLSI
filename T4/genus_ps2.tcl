# --- Paths and Variables ---
set RTL_PATH        "../sources/"
set LIB_PATH        "../lib/"
set LEF_PATH        "../lef/scaled/"
set TLEF_PATH       "../techlef/"
set QRC_PATH        "../qrc/"
set DESIGN          "ps2_driver"

set LIB_LIST { asap7sc7p5t_AO_LVT_TT_nldm_211120.lib asap7sc7p5t_INVBUF_LVT_TT_nldm_220122.lib asap7sc7p5t_OA_LVT_TT_nldm_211120.lib asap7sc7p5t_SEQ_LVT_TT_nldm_220123.lib asap7sc7p5t_SIMPLE_LVT_TT_nldm_211120.lib }

set LEF_LIST { asap7_tech_4x_201209.lef asap7sc7p5t_28_L_4x_220121a.lef asap7sc7p5t_28_R_4x_220121a.lef asap7sc7p5t_28_SL_4x_220121a.lef }

set QRC_FILE "qrcTechFile_typ03_scaled4xV06"
set RTL_LIST {ps2_driver.sv}

# 1. Set search paths first (before loading any files)
set_db init_lib_search_path "$LIB_PATH $LEF_PATH $TLEF_PATH"
set_db init_hdl_search_path $RTL_PATH

# 2. Set physical LEF library BEFORE loading timing libraries (.lib)
set_db lef_library "$LEF_LIST"

# 3. Set target timing libraries (.lib)
set_db / .library "$LIB_LIST"

# 4. Set QRC technology file for parasitic extraction
set_db qrc_tech_file "$QRC_PATH/$QRC_FILE"

# 5. Read RTL and elaborate design
read_hdl -sv ${RTL_LIST}
elaborate $DESIGN

# --- Constraints & Synthesis ---
read_sdc ${RTL_PATH}${DESIGN}.sdc
set_db lp_insert_clock_gating true # desativar aqui para teste 1

syn_generic
syn_map
syn_opt

# --- Outputs & Reports ---
write_hdl > $DESIGN.netlist.v
write_sdc > ${DESIGN}_out.sdc

report clocks > ./$DESIGN.clocks.rep
report timing > ./$DESIGN.timing.rep
report area   > ./$DESIGN.area.rep
report gates  > ./$DESIGN.gates.rep
report power  > ./$DESIGN.power.rep

report_area
report_timing -fields "timing_point cell delay arrival"
report_power -unit mW -format %.4f
