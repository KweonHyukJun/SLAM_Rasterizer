#!/bin/bash

# Arrays of values for mantissa and precision bit pairs
# mantissa_bit_values=("23" "15" "8")
# precision_values=("32" "24" "16")

mantissa_bit_values=("23" "15" "8")
precision_values=("32" "24" "16")

# Arrays of values for Hz and clk_time
Hz_values=("200M" "400M" "800M" "1G")
clk_time_values=("5" "2.5" "1.25" "1")

# Path to the Verilog file to modify
verilog_file="./src/skip_and_alpha.v"

# Outer loop: Iterate over mantissa and precision pairs
for i in "${!precision_values[@]}"; do
    precision="${precision_values[$i]}"
    mantissa_bit="${mantissa_bit_values[$i]}"

    echo "Updating Verilog module with precision=$precision and mantissa_bit=$mantissa_bit"

    # Use sed to modify the precision and mantissa_bit parameters in the Verilog file
    sed -i "s/parameter precision = [0-9]*/parameter precision = $precision/" "$verilog_file"
    sed -i "s/parameter mantissa_bit = [0-9]*/parameter mantissa_bit = $mantissa_bit/" "$verilog_file"

    # Inner loop: Iterate over Hz and clk_time configurations
    for j in "${!Hz_values[@]}"; do
        Hz="${Hz_values[$j]}"
        clk_time="${clk_time_values[$j]}"

        echo "clk_time is ${clk_time}"

        # Export variables for use in TCL or Makefile if needed
        export clk_time="${clk_time}"
        export Hz="${Hz}"

        # Print information
        echo "Running synthesis for Hz=$Hz with clk_time=${clk_time}ns, precision=$precision, mantissa_bit=$mantissa_bit"

        # Run the synthesis process using the Makefile
        make RUN_DIR=./output_fp${precision}_${Hz} ./output_fp${precision}_${Hz}/syn

        echo "Synthesis completed for Hz=$Hz, precision=$precision, mantissa_bit=$mantissa_bit"
    done
done

echo "All operations are done."
