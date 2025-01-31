# TCL script for Design Compiler

# Enable multicore functionality (caution: using this option may slow down optimization for smaller designs)
#set_host_options -max_cores 4
# Do not change this line

# set top_level "Rasterizer_unit"
set top_level $env(top_level)

# Load common variables, artisan standard cells

source -verbose "../../SLAM_Rasterizer/syn/common.syn.tcl"

# Set top level name

set dir_name "${top_level}"


# Read verilog files

# read_sverilog "../../SLAM_Rasterizer/src/Forward/pixel_group/${top_level}.sv"
# read_sverilog "../../SLAM_Rasterizer/src/Backward/pixel_group/Gradient_merge_unit/${top_level}.sv"
read_sverilog "../../SLAM_Rasterizer/src/Backward/pixel_group/${top_level}.sv"


# read_sverilog "../../SLAM_Rasterizer/src/Forward/pixel_group/Forward_Rasterizer_unit/Forward_Rasterizer_unit.sv"
# read_sverilog "../../SLAM_Rasterizer/src/Forward/pixel_group/Forward_Rasterizer_unit/submodule/Forward_skip_unit.sv"
# read_sverilog "../../SLAM_Rasterizer/src/shared_submodules/fixed_arbiter.sv"
# read_sverilog "../../SLAM_Rasterizer/src/Forward/pixel_group/Forward_Rasterizer_unit/submodule/splatting_unit.sv"

# read_sverilog "../../SLAM_Rasterizer/src/Forward/pixel_group/Forward_Rasterizer_unit/Forward_Rasterizer_unit_single_input.sv"
# read_sverilog "../../SLAM_Rasterizer/src/Forward/pixel_group/Forward_Rasterizer_unit/submodule/Forward_skip_unit_single_input.sv"
# # read_sverilog "../../SLAM_Rasterizer/src/shared_submodules/fixed_arbiter.sv"
# read_sverilog "../../SLAM_Rasterizer/src/Forward/pixel_group/Forward_Rasterizer_unit/submodule/splatting_unit.sv"

read_sverilog "../../SLAM_Rasterizer/src/Backward/pixel_group/Backward_Rasterizer_unit/Backward_Rasterizer_unit.sv"
read_sverilog "../../SLAM_Rasterizer/src/Backward/pixel_group/Backward_Rasterizer_unit/submodule/Backward_skip_unit.sv"
read_sverilog "../../SLAM_Rasterizer/src/shared_submodules/fixed_arbiter.sv"
read_sverilog "../../SLAM_Rasterizer/src/Backward/pixel_group/Backward_Rasterizer_unit/submodule/gradient_unit.sv"

# read_sverilog "../../SLAM_Rasterizer/src/Backward/pixel_group/Gradient_merge_unit/submodule/majority_adder.sv"
# read_sverilog "../../SLAM_Rasterizer/src/Backward/pixel_group/Gradient_merge_unit/submodule/majority_voter.sv"
# read_sverilog "../../SLAM_Rasterizer/src/shared_submodules/serializer.sv"
# read_sverilog "../../SLAM_Rasterizer/src/shared_submodules/push_pop_FIFO.sv"
# read_sverilog "../../SLAM_Rasterizer/src/shared_submodules/priority_encoder.sv"


list_designs
current_design $top_level

# Clock period
# set clk_period 1.25
set clk_period [expr double($::env(clk_time))]

# clk_period (ns) 1 = 1G, 1.25 = 800M, 2.5 = 400M, 5 = 200M

set clk_uncertainty 0.1
set clk_transition 0.1

# Create real clock if clock port is found
if {[sizeof_collection [get_ports clk]] > 0} {
  set clk_name "clk"
  set clk_port "clk"
  #If no waveform is specified, 50% duty cycle is assumed
  create_clock -name $clk_name -period $clk_period [get_ports $clk_port] 
  set_drive 0 [get_clocks $clk_name] 
}

set_operating_conditions "TT0P9V25C" -library "um28nchslogl30hdh140f_tt0p9v25c" 
set_wire_load_selection_group "um28nchslogl30hdh140f" -library "um28nchslogl30hdh140f_tt0p9v25c" 

set min_input_delay 0.1
set max_input_delay 0.5
set typical_input_transition 0.1
set min_output_delay 0.1
set max_output_delay 0.5
set typical_output_load 0.010 

# Link the design
link

# Set maximum fanout of gates
set_max_fanout 16 $top_level 

# Configure the clock network
set_fix_hold [all_clocks] 
set_dont_touch_network $clk_port 

# Set delays and transitions
#set_driving_cell -lib_cell INVD32BWP12T50M1P [all_inputs]
set_input_transition $typical_input_transition [all_inputs]
set_input_delay $min_input_delay -min [all_inputs] -clock $clk_name 
set_input_delay $max_input_delay -max [all_inputs] -clock $clk_name 
remove_input_delay -clock $clk_name [find port $clk_port]
set_output_delay $min_output_delay -min [all_outputs] -clock $clk_name 
set_output_delay $max_output_delay -max [all_outputs] -clock $clk_name 

set_clock_uncertainty $clk_uncertainty [get_clocks $clk_name]
#Propagated clock used for gated clocks only
#set_propagated_clock [get_clocks $clk_name]
set_clock_transition $clk_transition [get_clocks $clk_name]

# Set max delay for async reset path
#set_max_delay [expr $clk_period/2] -from reset

# Set loading of outputs 
set_load $typical_output_load [all_outputs] 

# # set merge to same register false
# set compile_enable_register_merging false


# Verify the design
check_design

# Enable pipelined-logic retiming
set_optimize_registers -designs $top_level

# Synthesize the design with adaptive retiming
compile_ultra -retime -no_autoungroup

# Rename modules, signals according to the naming rules Used for tool exchange
source -verbose "./naming_rules.syn.tcl"

# Generate structural verilog netlist
write -hierarchy -format verilog -output "${top_level}.syn.v"

# Generate Standard Delay Format (SDF) file
write_sdf -context verilog "${top_level}.syn.sdf"

# Generate timing constraints file
write_sdc "${top_level}.syn.sdc"

# Generate report file
set maxpaths 20
set rpt_file "${top_level}.syn.rpt"

check_design > $rpt_file
report_area  >> ${rpt_file}
report_power -hier -analysis_effort medium >> ${rpt_file}
report_design >> ${rpt_file}
report_cell >> ${rpt_file}
report_port -verbose >> ${rpt_file}
report_compile_options >> ${rpt_file}
report_constraint -all_violators -verbose >> ${rpt_file}
report_timing -path full -delay max -max_paths $maxpaths -nworst 100 >> ${rpt_file}
report_qor >> ${rpt_file}

# Exit dc_shell
quit
