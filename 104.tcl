analyze -format verilog 104.sv -define {TSMC28}
elaborate -update top
set_case_analysis 1 scan_ena
# timing
create_clock -period 0.75 [get_ports clk]
set_clock_transition 0.01 clk
set_clock_uncertainty -setup 0.01 clk
set_clock_uncertainty -hold 0.01 clk
create_clock -period 100 [get_ports scan_clk]
create_clock -period 1 [get_ports u_fclk0/lck]
create_clock -period 1 [get_ports u_fclk1/lck]
create_clock -period 1 [get_ports u_fclk2/lck]
create_clock -period 1 [get_ports u_fclk3/lck]
set_scan_element false u_uart*/mem*
# upf 
set upf_create_implicit_supply_sets false
create_power_domain TOP -include_scope
create_power_domain IO -elements [get_cells u_bio -hierarchical]
create_power_domain MEM -elements [get_cells u_mem* -hierarchical]
create_supply_net VCC -domain TOP
create_supply_net GND -domain TOP
set_domain_supply_net TOP -primary_power_net VCC -primary_ground_net GND
create_supply_net IOVCC -domain IO
create_supply_net IOGND -domain IO
set_domain_supply_net IO -primary_power_net IOVCC -primary_ground_net IOGND
create_supply_net MEMVCC -domain MEM
create_supply_net MEMGND -domain MEM
set_domain_supply_net MEM -primary_power_net MEMVCC -primary_ground_net MEMGND
create_supply_port GND -domain TOP -direction in
create_supply_port VCC -domain TOP -direction in
create_supply_port IOGND -domain IO -direction in
create_supply_port IOVCC -domain IO -direction in
create_supply_port MEMGND -domain MEM -direction in
create_supply_port MEMVCC -domain MEM -direction in
add_port_state GND -state {state1 0.000000}
add_port_state VCC -state {state1 0.900000}
add_port_state IOGND -state {state1 0.000000}
add_port_state IOVCC -state {state1 1.800000}
add_port_state MEMGND -state {state1 0.000000}
add_port_state MEMVCC -state {state1 0.900000}
connect_supply_net GND -ports GND
connect_supply_net VCC -ports VCC
connect_supply_net IOGND -ports IOGND
connect_supply_net IOVCC -ports IOVCC
connect_supply_net MEMGND -ports MEMGND
connect_supply_net MEMVCC -ports MEMVCC
set_voltage 0.90 -object_list { VCC }
set_voltage 0.00 -object_list { GND }
set_voltage 1.80 -object_list { IOVCC }
set_voltage 0.00 -object_list { IOGND }
set_voltage 0.90 -object_list { MEMVCC }
set_voltage 0.00 -object_list { MEMGND }
# logic synthesis
compile_ultra -gate_clock -scan -no_autoungroup -timing_high_effort_script
# dft 
create_port -direction in  scan_si
create_port -direction out scan_so
set_scan_configuration -clock_mixing mix_clocks
set_scan_configuration -add_lockup true
set_scan_configuration -internal_clocks multi
set_scan_configuration -chain_count 1
set_dft_signal -port scan_ena -type scanenable  -view existing_dft -active_state 1 
set_dft_signal -port scan_clk -type scanclock   -view existing_dft -timing {50 100} 
set_dft_signal -port scan_si  -type scandatain  -view existing_dft 
set_dft_signal -port scan_so  -type scandataout -view existing_dft 
set_scan_path 1 -view existing_dft -scan_data_in scan_si -scan_data_out scan_so -scan_master_clock scan_clk
create_test_protocol -infer_clock -infer_asynch
preview_dft
insert_dft
dft_drc
optimize_netlist -area

