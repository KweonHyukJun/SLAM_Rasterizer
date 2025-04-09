#!/bin/bash


Hz_values=("800M" "1G")
clk_time_values=("1.25" "1.0")


# Hz_values=("600M" "800M" "1G")
# clk_time_values=("1.67" "1.25" "1.0")

# Path to the Verilog file to modify
verilog_src="priority_encoder_with_buffer"
verilog_file="./src/shared_submodules/${verilog_src}.sv"
# verilog_file="./src/pixel_group/Rasterizer_unit/Rasterizer_unit.sv"

for j in "${!Hz_values[@]}"; do
    Hz="${Hz_values[$j]}"
    clk_time="${clk_time_values[$j]}"

    echo "Running synthesis for Hz=$Hz with clk_time=${clk_time}ns, precision=$precision" 

    # Export variables for Makefile and Tcl script
    export clk_time="${clk_time}"
    export Hz="${Hz}"

    # Call Makefile with appropriate RUN_DIR
    # make SYN_RUN_DIR=./output_fp${precision}_${Hz} Hz=${Hz} clk_time=${clk_time} ../synthesis_output/${verilog_src}_pixel${pixel}_fp${precision}_${Hz}/syn

    export top_level="${verilog_src}"

    make SYN_RUN_DIR=../synthesis_output/${verilog_src}_fp${precision}_${Hz} ../synthesis_output/${verilog_src}_fp${precision}_${Hz}/syn

    echo "Synthesis completed for Hz=$Hz, precision=$precision"
    
done

echo "All operations are done."
