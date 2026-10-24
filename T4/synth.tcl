set RTL_PATH		"../sources/"
set LIB_PATH 		"../lib/"
set LEF_PATH		"../lef/scaled/"
set TLEF_PATH		"../techlef/"
set QRC_PATH 		"../qrc/"
set DESIGN 		"ps2_driver"

set LIB_LIST {  asap7sc7p5t_AO_LVT_TT_nldm_211120.lib   asap7sc7p5t_INVBUF_LVT_TT_nldm_220122.lib   asap7sc7p5t_OA_LVT_TT_nldm_211120.lib   asap7sc7p5t_SEQ_LVT_TT_nldm_220123.lib   asap7sc7p5t_SIMPLE_LVT_TT_nldm_211120.lib }

set TLEF_FILE "asap7_tech_4x_201209.lef"
set LEF_LIST { asap7sc7p5t_28_L_4x_220121a.lef asap7sc7p5t_28_R_4x_220121a.lef asap7sc7p5t_28_SL_4x_220121a.lef}

set QRC_FILE "qrcTechFile_typ03_scaled4xV06"

# Biblioteca de células ASAP7
set_db init_lib_search_path $LIB_PATH
set_db init_hdl_search_path $RTL_PATH
read_libs $LIB_LIST

# LEFs (o tech LEF precisa vir antes dos LEFs das células) e arquivo QRC
set lefs [list $TLEF_PATH$TLEF_FILE]
foreach lef $LEF_LIST { lappend lefs $LEF_PATH$lef }
read_physical -lef $lefs
set_db qrc_tech_file $QRC_PATH$QRC_FILE

# Lê e elabora o RTL
read_hdl -sv $DESIGN.sv
elaborate $DESIGN

# Aplica as restrições (precisa vir DEPOIS do elaborate, porque get_ports precisa do design)
read_sdc $RTL_PATH$DESIGN.sdc

# Síntese
syn_generic
syn_map
syn_opt

# Relatórios
report_timing > timing.rpt
report_area   > area.rpt
report_power  > power.rpt

# Saídas
write_hdl > ${DESIGN}_netlist.v
write_sdc > ${DESIGN}_out.sdc
write_sdf > $DESIGN.sdf
