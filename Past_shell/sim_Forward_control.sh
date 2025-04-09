#!/bin/bash

# Array of gaussian_inputs values to test
target_count_values=("20000" "15000")
# gaussian_inputs_values=("8" "4" "3" "2")
gaussian_inputs_values=("4")

# Path to testbench file
TESTBENCH_FILE="./verif/tb/Forward/tb_Forward_Block_controller_with_SRAM.sv"

# step 1 : operate with target count's target_count with multi-precision

for target_count in "${target_count_values[@]}"; do

    echo "Running simulation with target_count: $target_count"

    sed -i "s/target_count = [0-9]\+/target_count = ${target_count}/" "$TESTBENCH_FILE"

    # Run simulation for precision 32 and mantissa bit 23 pair
    echo "Running simulation with precision 32, mantissa bit 23" 
    sed -i "s/precision = [0-9]\+/precision = 32/" "$TESTBENCH_FILE"
    sed -i "s/mantissa_bit = [0-9]\+/mantissa_bit = 23/" "$TESTBENCH_FILE"
    make ../output_forward_control/simv
    echo "Simulation completed for precision 32, mantissa bit 23"
    echo "----------------------------------------"


    # Run simulation for precision 16 and mantissa bit 7 pair
    echo "Running simulation with precision 16, mantissa bit 7"
    sed -i "s/precision = [0-9]\+/precision = 16/" "$TESTBENCH_FILE"
    sed -i "s/mantissa_bit = [0-9]\+/mantissa_bit = 7/" "$TESTBENCH_FILE"
    make ../output_forward_control/simv
    echo "Simulation completed for precision 16, mantissa bit 7"
    echo "----------------------------------------"

    
    # Run the simulation
    
    echo "Simulation completed for gaussian_inputs = $gaussian_inputs"
    echo "----------------------------------------"
done

# step 2 : time comparsion with gaussian_inputs


# for gaussian_inputs in "${gaussian_inputs_values[@]}"; do

#     echo "Running simulation with gaussian_inputs: $gaussian_inputs"

#     sed -i "s/gaussian_inputs = [0-9]\+/gaussian_inputs = ${gaussian_inputs}/" "$TESTBENCH_FILE"

#     # Run simulation for precision 32 and mantissa bit 23 pair
    
#     make ../output_forward_control/simv
    
#     echo "----------------------------------------"
# done

echo "All simulations completed."