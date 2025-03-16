#!/bin/bash


Hz_values=("600M" "800M" "1G" "1.25G" "2G")
clk_time_values=("1.67" "1.25" "1" "0.8" "0.5")
precision_values=("16" "32")
mantissa_bit_values=("7" "23")

# Hz_values=("800M")
# clk_time_values=("1.25")
# precision_values=("16")
# mantissa_bit_values=("7")


# Path to the Verilog file to modify
verilog_src="synopsys_dp2"
verilog_file="./src/shared_submodules/${verilog_src}.sv"

# verilog_srcs=("Backward_skip_unit" "gradient_unit")
# verilog_file="./src/Backward/pixel_group/${verilog_src}.sv"
# verilog_file="./src/pixel_group/Rasterizer_unit/Rasterizer_unit.sv"

# for verilog_src in "${!verilog_srcs[@]}"; do

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


# for ((i=0; i<${#verilog_srcs[@]}; i++)); do
#     verilog_src="${verilog_srcs[$i]}"
    
#     verilog_file="./src/Backward/pixel_group/Backward_Rasterizer_unit/submodule/${verilog_src}.sv"
#     Hz="${Hz_values[0]}"  # Since we only have one value in Hz_values array
#     clk_time="${clk_time_values[0]}"  # Since we only have one value in clk_time_values array

#     # Export variables for Makefile and Tcl script
#     export clk_time="${clk_time}"
#     export Hz="${Hz}"
#     export top_level="${verilog_src}"

#     # Create output directory if it doesn't exist
#     mkdir -p "../synthesis_output/${verilog_src}_fp${precision_values[0]}_${Hz}"

#     # Run synthesis
#     make SYN_RUN_DIR="../synthesis_output/${verilog_src}_fp${precision_values[0]}_${Hz}" \
#          "../synthesis_output/${verilog_src}_fp${precision_values[0]}_${Hz}/syn"
# done

echo "All operations are done."
