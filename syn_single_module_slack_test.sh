#!/bin/bash


# Hz_values=("600M" "800M" "1G" "1.25G" "2G")
# clk_time_values=("1.67" "1.25" "1" "0.8" "0.5")
# precision_values=("16" "32")
# mantissa_bit_values=("7" "23")

Hz_values=("800M")
clk_time_values=("1.25")
precision_values=("16")
mantissa_bit_values=("7")


# Path to the Verilog file to modify
verilog_src="Gradient_merge_unit_by_majority_with_add_with_changed_encoder"
verilog_file="./src/Backward/pixel_group/Gradient_merge_unit/${verilog_src}.sv"



for i in "${!Hz_values[@]}"; do
    Hz="${Hz_values[$i]}"
    clk_time="${clk_time_values[$i]}"

    for j in "${!precision_values[@]}"; do
        precision="${precision_values[$j]}"
        mantissa_bit="${mantissa_bit_values[$j]}"
        
        sed -i "s/parameter precision = [0-9]*/parameter precision = $precision/" "$verilog_file"
        sed -i "s/parameter mantissa_bit = [0-9]*/parameter mantissa_bit = $mantissa_bit/" "$verilog_file"

      # Export variables for Makefile and Tcl script
        export clk_time="${clk_time}"
        export Hz="${Hz}"

        export top_level="${verilog_src}"

        make SYN_RUN_DIR=../synthesis_output/${verilog_src}_fp${precision}_${Hz} ../synthesis_output/${verilog_src}_fp${precision}_${Hz}/syn

    done
done


echo "All operations are done."
