set RTL_PATH		"../sources/"
set LIB_PATH 		"../lib/"
set LEF_PATH		"../lef/scaled/"
set TLEF_PATH		"../techlef/"
set QRC_PATH 		"../qrc/"
set DESIGN 		"sha256"

set LIB_LIST {  asap7sc7p5t_AO_LVT_TT_nldm_211120.lib   asap7sc7p5t_INVBUF_LVT_TT_nldm_220122.lib   asap7sc7p5t_OA_LVT_TT_nldm_211120.lib   asap7sc7p5t_SEQ_LVT_TT_nldm_220123.lib   asap7sc7p5t_SIMPLE_LVT_TT_nldm_211120.lib }

set LEF_LIST { asap7_tech_4x_201209.lef asap7sc7p5t_28_L_4x_220121a.lef asap7sc7p5t_28_R_4x_220121a.lef asap7sc7p5t_28_SL_4x_220121a.lef}

set QRC_FILE "qrcTechFile_typ03_scaled4xV06"

# Biblioteca de células (ajuste para a que a disciplina usa)
set_db init_lib_search_path /caminho/para/libs
read_libs <sua_biblioteca>.lib

# Lê e elabora o RTL
read_hdl -sv ps2_driver.sv
elaborate ps2_driver

# Aplica as restrições (precisa vir DEPOIS do elaborate, porque get_ports precisa do design)
read_sdc ps2_driver.sdc

# Síntese
syn_generic
syn_map
syn_opt

# Relatórios
report_timing > timing.rpt
report_area   > area.rpt
report_power  > power.rpt

# Saídas
write_hdl > ps2_driver_netlist.v
write_sdc > ps2_driver_out.sdc
write_sdf > ps2_driver.sdf
