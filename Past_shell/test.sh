#!/bin/bash

# Arrays of values for mantissa and precision bit pairs
mantissa_bit_values=("15")
precision_values=("24")


# Path to the Verilog file to modify
verilog_file="./src/skip_and_alpha.v"
precision="${precision_values}"
mantissa_bit="${mantissa_bit_values}"

# Use sed to modify the precision and mantissa_bit parameters in the Verilog file
sed -i "s/parameter precision = [0-9]*/parameter precision = $precision/" "$verilog_file"
sed -i "s/parameter mantissa_bit = [0-9]*/parameter mantissa_bit = $mantissa_bit/" "$verilog_file"

echo "All operations are done."
