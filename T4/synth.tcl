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
