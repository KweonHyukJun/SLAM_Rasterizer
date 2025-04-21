#!/bin/bash


Hz_values=("1G" "1.25G")
clk_time_values=("1" "0.8")
precision_values=("16"  "32")
mantissa_bit_values=("7" "23")

# Hz_values=("800M")
# clk_time_values=("1.25")
# precision_values=("16")
# mantissa_bit_values=("7")


# Path to the Verilog file to modify
verilog_src="synopsys_mac_test"
verilog_file="./src/shared_submodules/${verilog_src}.sv"

# verilog_srcs=("Backward_skip_unit" "gradient_unit")
# verilog_file="./src/Backward/pixel_group/${verilog_src}.sv"
# verilog_file="./src/pixel_group/Rasterizer_unit/Rasterizer_unit.sv"

# for verilog_src in "${!verilog_srcs[@]}"; do

for k in "${!Hz_values[@]}"; do
    Hz="${Hz_values[$k]}"
    clk_time="${clk_time_values[$k]}"

    for j in "${!precision_values[@]}"; do

    precision="${precision_values[$j]}"
    mantissa_bit="${mantissa_bit_values[$j]}"

    sed -i "s/parameter mantissa_bit = 7/parameter mantissa_bit = ${mantissa_bit}/g" ${verilog_file}
    sed -i "s/parameter precision = 16/parameter precision = ${precision}/g" ${verilog_file}

      for i in "${!Hz_values[@]}"; do
          Hz="${Hz_values[$i]}"
          clk_time="${clk_time_values[$i]}"


        # Export variables for Makefile and Tcl script
          export clk_time="${clk_time}"
          export Hz="${Hz}"

          export top_level="${verilog_src}"



          make SYN_RUN_DIR=../synthesis_output/${verilog_src}_fp${precision}_${Hz}_speedup ../synthesis_output/${verilog_src}_fp${precision}_${Hz}_speedup/syn
        done
    done
done


echo "All operations are done."
