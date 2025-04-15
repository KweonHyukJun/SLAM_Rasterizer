#!/bin/bash

# Array of gaussian_inputs values to test
# target_count_values=("15000" "20000")
target_count_values=("15000")
# Path to testbench file

gaussian_inputs=("4" "8" "2")


TESTBENCH_FILE="./verif/tb/Backward/tb_Backward_system_AXI4_fetching.sv"

for gaussian_input in "${gaussian_inputs[@]}"; do

    for target_count in "${target_count_values[@]}"; do

    sed -i "s/gaussian_inputs = [0-9]\+/gaussian_inputs = $gaussian_input/" "$TESTBENCH_FILE"

    # Run simulation for precision 16 and mantissa bit 7 pair
    echo "Running simulation with precision 16, mantissa bit 7"
    sed -i "s/precision = [0-9]\+/precision = 16/" "$TESTBENCH_FILE"
    sed -i "s/mantissa_bit = [0-9]\+/mantissa_bit = 7/" "$TESTBENCH_FILE"
    make ../output_backward_system/simv
    echo "Simulation completed for precision 16, mantissa bit 7"
    echo "----------------------------------------"

    echo "Running simulation with target_count: $target_count"


    echo "All simulations completed."

    done
done