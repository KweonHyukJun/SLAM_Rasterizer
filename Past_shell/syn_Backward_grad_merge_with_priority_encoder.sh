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

# Pixels_values=("16")
# Bank_values=("16")
# gaussians_values=("4")
# gaussians_values=("8")


# Path to the Verilog file to modify
verilog_src="Gradient_merge_unit_by_majority_with_add_with_changed_encoder"
verilog_file="./src/Backward/pixel_group/Gradient_merge_unit/${verilog_src}.sv"
# verilog_file="./src/pixel_group/Rasterizer_unit/Rasterizer_unit.sv"

# Outer loop: Iterate over mantissa and precision pairs

# for l in "${!Bank_values[@]}"; do
#     Bank_value="${Bank_values[$l]}"

#     sed -i "s/parameter Banks = [0-9]*/parameter Banks = $Bank_value/" "$verilog_file"
#     echo "Current Banks value in file:"
#     grep "parameter Banks" "$verilog_file"


#     for k in "${!Pixels_values[@]}"; do

#         Pixels_value="${Pixels_values[$k]}"

#         sed -i "s/parameter num_pixels = [0-9]*/parameter num_pixels = $Pixels_value/" "$verilog_file"
#         echo "Current num_pixels value in file:"
#         grep "parameter num_pixels" "$verilog_file"


#         for i in "${!precision_values[@]}"; do
#             precision="${precision_values[$i]}"
#             mantissa_bit="${mantissa_bit_values[$i]}"

#             # echo "Updating Verilog module with precision=$precision"

#             # Modify the Verilog parameters using sed
#             sed -i "s/parameter precision = [0-9]*/parameter precision = $precision/" "$verilog_file"
#             sed -i "s/parameter mantissa_bit = [0-9]*/parameter mantissa_bit = $mantissa_bit/" "$verilog_file"

#             # Inner loop: Iterate over Hz and clk_time configurations

#             for j in "${!Hz_values[@]}"; do
#                 Hz="${Hz_values[$j]}"
#                 clk_time="${clk_time_values[$j]}"

#                 echo "Running synthesis for Hz=$Hz with clk_time=${clk_time}ns, precision=$precision" 

#                 # Export variables for Makefile and Tcl script
#                 export clk_time="${clk_time}"
#                 export Hz="${Hz}"

#                 # Call Makefile with appropriate RUN_DIR
#                 # make SYN_RUN_DIR=./output_fp${precision}_${Hz} Hz=${Hz} clk_time=${clk_time} ../synthesis_output/${verilog_src}_pixel${pixel}_fp${precision}_${Hz}/syn

#                 export top_level="${verilog_src}"

#                 make SYN_RUN_DIR=../synthesis_output/${verilog_src}_pixel${Pixels_value}_bank${Bank_value}_fp${precision}_${Hz} ../synthesis_output/${verilog_src}_pixel${Pixels_value}_bank${Bank_value}_fp${precision}_${Hz}/syn

#                 echo "Synthesis completed for Hz=$Hz, precision=$precision"
#             done
#         done
#     done
# done

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

        export top_level="${verilog_src}"
        
        # Call Makefile with appropriate RUN_DIR
        make SYN_RUN_DIR=../synthesis_output/${verilog_src}_with_no_clock_uncertainty_fp${precision}_${Hz} ../synthesis_output/${verilog_src}_with_no_clock_uncertainty_fp${precision}_${Hz}/syn

        echo "Synthesis completed for Hz=$Hz, precision=$precision, mantissa_bit=$mantissa_bit"
    done
done

echo "All operations are done."
