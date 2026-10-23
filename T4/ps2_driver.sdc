# ----------------------------------------------------------------------
# ps2_driver.sdc
# Master clock: 100 MHz (period 10 ns), as required by the assignment
# ----------------------------------------------------------------------

# Master clock
create_clock -name clk_in -period 10.0 -waveform {0 5} [get_ports clock_in]
set_clock_uncertainty 0.2 [get_clocks clk_in]
set_clock_transition  0.1 [get_clocks clk_in]

# clock_ps2 (max 1 MHz) is NOT used as a clock inside the design.
# It is sampled as a normal data input through a 2-FF synchronizer,
# so it is not declared with create_clock.

# Asynchronous inputs: reset_in, clock_ps2 and data_ps2 have no fixed phase
# relation with clock_in. They enter synchronizers (or the async reset pin),
# so timing is not analyzed on these paths.
set_false_path -from [get_ports {reset_in clock_ps2 data_ps2}]

# Input slew on the non-clock inputs
set_input_transition 0.2 [get_ports {reset_in clock_ps2 data_ps2}]

# Outputs are registered inside the block. Assume 2 ns of external
# logic/setup time at the receiving block.
set_output_delay -clock clk_in 2.0 [get_ports {data_p[*] data_p_en}]

# Output load. Adjust to the library units, or uncomment if your flow needs it.
# set_load 0.05 [get_ports {data_p[*] data_p_en}]

# Optional, library dependent:
# set_driving_cell -lib_cell <BUFFER_CELL_NAME> [get_ports {reset_in clock_ps2 data_ps2}]
