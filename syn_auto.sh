#!/bin/bash

# Arrays of values for mantissa and precision bit pairs
mantissa_bit_values=("7" "15" "23")
precision_values=("16" "24" "32")
# mantissa_bit_values=("7")
# precision_values=("16")


# Arrays of values for Hz and clk_time
# Hz_values=("800M" "1G")
# clk_time_values=("1.25" "1.0")
Hz_values=("800M")
clk_time_values=("1.25")

# Path to the Verilog file to modify
verilog_file="./src/total_gradient.v"

# Outer loop: Iterate over mantissa and precision pairs
for i in "${!precision_values[@]}"; do
    precision="${precision_values[$i]}"
    mantissa_bit="${mantissa_bit_values[$i]}"

    echo "Updating Verilog module with precision=$precision and mantissa_bit=$mantissa_bit"

    # Modify the Verilog parameters using sed
    sed -i "s/parameter precision = [0-9]*/parameter precision = $precision/" "$verilog_file"
    sed -i "s/parameter mantissa_bit = [0-9]*/parameter mantissa_bit = $mantissa_bit/" "$verilog_file"

    # Inner loop: Iterate over Hz and clk_time configurations
    for j in "${!Hz_values[@]}"; do
        Hz="${Hz_values[$j]}"
        clk_time="${clk_time_values[$j]}"

        echo "Running synthesis for Hz=$Hz with clk_time=${clk_time}ns, precision=$precision, mantissa_bit=$mantissa_bit"

        # Export variables for Makefile and Tcl script
        export clk_time="${clk_time}"
        export Hz="${Hz}"

        # Call Makefile with appropriate RUN_DIR
        make RUN_DIR=./output_fp${precision}_${Hz} Hz=${Hz} clk_time=${clk_time} ./output_fp${precision}_${Hz}/syn

        echo "Synthesis completed for Hz=$Hz, precision=$precision, mantissa_bit=$mantissa_bit"
    done
done

echo "All operations are done."
