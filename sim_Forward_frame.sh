#!/bin/bash

# Array of gaussian_inputs values to test
gaussian_inputs_values=("8" "4" "3" "2")

# Path to testbench file
TESTBENCH_FILE="./verif/tb/Forward/tb_Forward_Rasterizer_group_unit_to_frame.sv"

for gaussian_inputs in "${gaussian_inputs_values[@]}"; do
    echo "Running simulation with gaussian_inputs: $gaussian_inputs"

    sed -i "s/gaussian_inputs = [0-9]\+/gaussian_inputs = ${gaussian_inputs}/" "$TESTBENCH_FILE"

    
    # Run the simulation
    make ../output_forward/simv
    
    echo "Simulation completed for gaussian_inputs = $gaussian_inputs"
    echo "----------------------------------------"
done

echo "All simulations completed."