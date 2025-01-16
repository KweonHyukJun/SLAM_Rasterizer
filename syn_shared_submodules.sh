#!/bin/bash

# Arrays of values for mantissa and precision bit pairs

# mantissa_bit_values=("7")
# precision_values=("16")
# mantissa_bit_values=("7" "15" "23")
# precision_values=("16" "24" "32")



# Arrays of values for Hz and clk_time
# Hz_values=("600M" "800M" "1G")
# clk_time_values=("1.67" "1.25" "1.0")
Hz_values=("600M")
clk_time_values=("1.67")

FIFO_depth_values=("4" "8")
data_depth_values=("200" "800")

# Pixels_values=("16")
# gaussians_values=("2")

# num_pixels_values=("16")

# gaussians_values=("2" "4" "8" "16")

# Path to the Verilog file to modify
verilog_src="serializer"
verilog_file="./src/shared_submodules/${verilog_src}.sv"
# verilog_file="./src/pixel_group/Rasterizer_unit/Rasterizer_unit.sv"

# Outer loop: Iterate over mantissa and precision pairs

# for k in "${!gaussians_values[@]}"; do

#     gaussians_value="${gaussians_values[$k]}"

#     sed -i "s/parameter gaussian_inputs = [0-9]*/parameter gaussian_inputs = $gaussians_value/" "$verilog_file"
#     echo "Current gaussians value in file:"
    # grep "parameter gaussian_inputs" "$verilog_file"


# for i in "${!precision_values[@]}"; do
#     precision="${precision_values[$i]}"
#     mantissa_bit="${mantissa_bit_values[$i]}"

#     echo "Updating Verilog module with precision=$precision"

#     # Modify the Verilog parameters using sed
#     sed -i "s/parameter precision = [0-9]*/parameter precision = $precision/" "$verilog_file"
#     sed -i "s/parameter mantissa_bit = [0-9]*/parameter mantissa_bit = $mantissa_bit/" "$verilog_file"

#     # Inner loop: Iterate over Hz and clk_time configurations

#     for j in "${!Hz_values[@]}"; do
#         Hz="${Hz_values[$j]}"
#         clk_time="${clk_time_values[$j]}"

#         echo "Running synthesis for Hz=$Hz with clk_time=${clk_time}ns, precision=$precision" 

#         # Export variables for Makefile and Tcl script
#         export clk_time="${clk_time}"
#         export Hz="${Hz}"

#         # Call Makefile with appropriate RUN_DIR
#         # make SYN_RUN_DIR=./output_fp${precision}_${Hz} Hz=${Hz} clk_time=${clk_time} ../synthesis_output/${verilog_src}_pixel${pixel}_fp${precision}_${Hz}/syn

#         export top_level="${verilog_src}"

#         make SYN_RUN_DIR=../synthesis_output/${verilog_src}_fp${precision}_${Hz} ../synthesis_output/${verilog_src}_fp${precision}_${Hz}/syn

#         echo "Synthesis completed for Hz=$Hz, precision=$precision"
#     done
# done
# done

    # Inner loop: Iterate over Hz and clk_time configurations


# for k in "${!FIFO_depth_values[@]}"; do

#     FIFO_depth_value="${FIFO_depth_values[$k]}"

#     sed -i "s/parameter FIFO_depth = [0-9]*/parameter FIFO_depth = $FIFO_depth_value/" "$verilog_file"
#     echo "Current FIFO_depth value in file:"
#     grep "parameter FIFO_depth" "$verilog_file"

#     for l in "${!data_depth_values[@]}"; do
#         data_depth_value="${data_depth_values[$l]}"

#         sed -i "s/parameter input_data_width = [0-9]*/parameter input_data_width = $data_depth_value/" "$verilog_file"
#         sed -i "s/parameter output_data_width = [0-9]*/parameter output_data_width = $data_depth_value/" "$verilog_file"
#         echo "Current input_data_width value in file:"
#         grep "parameter input_data_width" "$verilog_file"
    

#         for j in "${!Hz_values[@]}"; do
#             Hz="${Hz_values[$j]}"
#             clk_time="${clk_time_values[$j]}"

#             echo "Running synthesis for Hz=$Hz with clk_time=${clk_time}ns, precision=$precision" 

#             # Export variables for Makefile and Tcl script
#             export clk_time="${clk_time}"
#             export Hz="${Hz}"

#             # Call Makefile with appropriate RUN_DIR
#             # make SYN_RUN_DIR=./output_fp${precision}_${Hz} Hz=${Hz} clk_time=${clk_time} ../synthesis_output/${verilog_src}_pixel${pixel}_fp${precision}_${Hz}/syn

#             export top_level="${verilog_src}"

#             make SYN_RUN_DIR=../synthesis_output/${verilog_src}_FIFO_depth${FIFO_depth_value}_data_depth${data_depth_value}_${Hz} ../synthesis_output/${verilog_src}_FIFO_depth${FIFO_depth_value}_data_depth${data_depth_value}_${Hz}/syn

#             echo "Synthesis completed for Hz=$Hz, precision=$precision"
#         done
#     done
# done


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
