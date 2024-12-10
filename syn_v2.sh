#!/bin/bash

# Arrays of values for mantissa and precision bit pairs

mantissa_bit_values=("7")
precision_values=("16")
# mantissa_bit_values=("7" "15" "23")
# precision_values=("16" "24" "32")

# Arrays of values for Hz and clk_time
# Hz_values=("600M" "800M" "1G")
# clk_time_values=("1.67" "1.25" "1.0")
Hz_values=("600M")
clk_time_values=("1.67")

# Pixels_values=("16")
gaussians_values=("2")

num_pixels_values=("1")

# gaussians_values=("8")

# Path to the Verilog file to modify
verilog_src="splatting_unit"
verilog_file="./src/Forward/pixel_group/Forward_Rasterizer_unit/submodules/${verilog_src}.sv"
# verilog_file="./src/pixel_group/Rasterizer_unit/Rasterizer_unit.sv"

# Outer loop: Iterate over mantissa and precision pairs

for k in "${!num_pixels_values[@]}"; do

    num_pixels_value="${num_pixels_values[$k]}"

    # sed -i "s/parameter num_pixels = [0-9]*/parameter num_pixels = $num_pixels_value/" "$verilog_file"
    # echo "Current num_pixels value in file:"
    # grep "parameter num_pixels" "$verilog_file"


    for i in "${!precision_values[@]}"; do
        precision="${precision_values[$i]}"
        mantissa_bit="${mantissa_bit_values[$i]}"

        echo "Updating Verilog module with precision=$precision"

        # Modify the Verilog parameters using sed
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

            make SYN_RUN_DIR=../synthesis_output/${verilog_src}_num_pixels${num_pixels_value}_fp${precision}_${Hz} ../synthesis_output/${verilog_src}_num_pixels${num_pixels_value}_fp${precision}_${Hz}/syn

            echo "Synthesis completed for Hz=$Hz, precision=$precision"
        done
    done
done

# Outer loop: Iterate over mantissa and precision pairs
# for i in "${!precision_values[@]}"; do
#     precision="${precision_values[$i]}"
#     mantissa_bit="${mantissa_bit_values[$i]}"

#     echo "Updating Verilog module with precision=$precision and mantissa_bit=$mantissa_bit"

#     # Modify the Verilog parameters using sed
#     sed -i "s/parameter precision = [0-9]*/parameter precision = $precision/" "$verilog_file"
#     sed -i "s/parameter mantissa_bit = [0-9]*/parameter mantissa_bit = $mantissa_bit/" "$verilog_file"

#     # Inner loop: Iterate over Hz and clk_time configurations
#     for j in "${!Hz_values[@]}"; do
#         Hz="${Hz_values[$j]}"
#         clk_time="${clk_time_values[$j]}"

#         echo "Running synthesis for Hz=$Hz with clk_time=${clk_time}ns, precision=$precision, mantissa_bit=$mantissa_bit"

#         # Export variables for Makefile and Tcl script
#         export clk_time="${clk_time}"
#         export Hz="${Hz}"

#         # Call Makefile with appropriate RUN_DIR
#         make SYN_RUN_DIR=./output_fp${precision}_${Hz} Hz=${Hz} clk_time=${clk_time} ./output_fp${precision}_${Hz}/syn

#         echo "Synthesis completed for Hz=$Hz, precision=$precision, mantissa_bit=$mantissa_bit"
#     done
# done

echo "All operations are done."
