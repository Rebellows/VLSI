# ----------------------------------------------------------------------
# ps2_driver.sdc
# UNITS: ASAP7 libraries use picoseconds, so all times below are in ps
# (the lab uses "create_clock -period 1000" for 1 ns).
# Master clock: 100 MHz = 10 ns = 10000 ps
# ----------------------------------------------------------------------

# Master clock
create_clock -name clk_in -period 10000 -waveform {0 5000} [get_ports clock_in]
set_clock_uncertainty 100 [get_clocks clk_in]
set_clock_transition  10  [get_clocks clk_in]

# clock_ps2 (max 1 MHz) is NOT used as a clock inside the design.
# It is sampled as a normal data input through a 2-FF synchronizer,
# so it is not declared with create_clock.

# Input and output delays, same approach as lab 2 (30% of the clock period,
# the lab uses 300 ps on a 1000 ps clock). This avoids unconstrained paths
# from the inputs (reset_in, clock_ps2, data_ps2) and to the outputs.
set_input_delay  -clock clk_in 3000 [get_ports {reset_in clock_ps2 data_ps2}]
set_output_delay -clock clk_in 3000 [get_ports {data_p[*] data_p_en}]

# Input slew (ps)
set_input_transition 20 [get_ports {reset_in clock_ps2 data_ps2}]

# Output load (ASAP7 capacitance unit is fF). Uncomment if your flow needs it.
# set_load 1.0 [get_ports {data_p[*] data_p_en}]
