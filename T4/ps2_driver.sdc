# ----------------------------------------------------------------------
# ps2_driver.sdc
# UNITS: the ASAP7 libraries use picoseconds (time_unit "1ps"), and the
# SDC values are read in library units. All times below are in ps.
# Master clock: 100 MHz = 10 ns = 10000 ps
# ----------------------------------------------------------------------

# Master clock
create_clock -name clk_in -period 10000 -waveform {0 5000} [get_ports clock_in]
set_clock_uncertainty 100 [get_clocks clk_in]
set_clock_transition  10  [get_clocks clk_in]

# clock_ps2 (max 1 MHz) is NOT used as a clock inside the design.
# It is sampled as a normal data input through a 2-FF synchronizer,
# so it is not declared with create_clock.

# Asynchronous inputs: reset_in, clock_ps2 and data_ps2 have no fixed phase
# relation with clock_in. They enter synchronizers (or the async reset pin),
# so timing is not analyzed on these paths.
set_false_path -from [get_ports {reset_in clock_ps2 data_ps2}]

# Input slew on the non-clock inputs (ps)
set_input_transition 20 [get_ports {reset_in clock_ps2 data_ps2}]

# Outputs are registered inside the block. Assume 2 ns (2000 ps) of external
# logic/setup time at the receiving block.
set_output_delay -clock clk_in 2000 [get_ports {data_p[*] data_p_en}]

# Output load (ASAP7 capacitance unit is fF). Uncomment if your flow needs it.
# set_load 1.0 [get_ports {data_p[*] data_p_en}]
