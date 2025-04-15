#!/bin/bash

# Arrays of values for mantissa and precision bit pairs

mantissa_bit_values=("7")
precision_values=("16")
# mantissa_bit_values=("7" "15" "23")
# precision_values=("16" "24" "32")

# Arrays of values for Hz and clk_time
# Hz_values=("600M" "800M" "1G")
# clk_time_values=("1.67" "1.25" "1.0")
Hz_values=("800M")
clk_time_values=("1.25")




# Path to the Verilog file to modify
verilog_src="Backward_system_Top_for_synthesis_single_input"
verilog_file="./src/Backward/Top/${verilog_src}.sv"
# verilog_file="./src/pixel_group/Rasterizer_unit/Rasterizer_unit.sv"

# Outer loop: Iterate over mantissa and precision pairs


echo "Current gaussian_inputs value in file:"
grep "parameter gaussian_inputs" "$verilog_file"


for i in "${!precision_values[@]}"; do
    precision="${precision_values[$i]}"
    mantissa_bit="${mantissa_bit_values[$i]}"

    # echo "Updating Verilog module with precision=$precision"

    # # Modify the Verilog parameters using sed
    sed -i "s/parameter precision = [0-9]*/parameter precision = $precision/" "$verilog_file"
    sed -i "s/parameter mantissa_bit = [0-9]*/parameter mantissa_bit = $mantissa_bit/" "$verilog_file"

    # Inner loop: Iterate over Hz and clk_time configurations

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

        make SYN_RUN_DIR=../synthesis_output/${verilog_src}_final_model_fp${precision}_${Hz} ../synthesis_output/${verilog_src}_final_model_fp${precision}_${Hz}/syn

        echo "Synthesis completed for Hz=$Hz, precision=$precision"
    done
done



echo "All operations are done."
