#!/bin/bash


Hz_values=("800M")
clk_time_values=("1.25")
precision_values=("16")
mantissa_bit_values=("7")

# Hz_values=("800M")
# clk_time_values=("1.25")
# precision_values=("16")
# mantissa_bit_values=("7")


# Path to the Verilog file to modify
verilog_src="Backward_Rasterizer_group_unit"
verilog_file="./src/Backward/pixel_group/${verilog_src}.sv"

# verilog_srcs=("Backward_skip_unit" "gradient_unit")
# verilog_file="./src/Backward/pixel_group/${verilog_src}.sv"
# verilog_file="./src/pixel_group/Rasterizer_unit/Rasterizer_unit.sv"

# for verilog_src in "${!verilog_srcs[@]}"; do

for i in "${!Hz_values[@]}"; do
    Hz="${Hz_values[$i]}"
    clk_time="${clk_time_values[$i]}"


  # Export variables for Makefile and Tcl script
    export clk_time="${clk_time}"
    export Hz="${Hz}"

    export top_level="${verilog_src}"

    make SYN_RUN_DIR=../synthesis_output/${verilog_src}_gaussian_input_4_fp${precision}_${Hz} ../synthesis_output/${verilog_src}_gaussian_input_4_fp${precision}_${Hz}/syn

done


echo "All operations are done."
