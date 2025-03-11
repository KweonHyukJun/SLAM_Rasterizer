#!/bin/bash

# Array of gaussian_inputs values to test
gaussian_inputs_values=("8" "4" "3" "2")

# Path to testbench file
TESTBENCH_FILE="./verif/tb/Forward/tb_Forward_Rasterizer_group_unit_to_frame.sv"

for gaussian_inputs in "${gaussian_inputs_values[@]}"; do

    echo "Running simulation with gaussian_inputs: $gaussian_inputs"

    sed -i "s/gaussian_inputs = [0-9]\+/gaussian_inputs = ${gaussian_inputs}/" "$TESTBENCH_FILE"


    # Run simulation for precision 16 and mantissa bit 7 pair
    echo "Running simulation with precision 16, mantissa bit 7"
    sed -i "s/precision = [0-9]\+/precision = 16/" "$TESTBENCH_FILE"
    sed -i "s/mantissa_bit = [0-9]\+/mantissa_bit = 7/" "$TESTBENCH_FILE"
    make ../output_forward_frame/simv
    echo "Simulation completed for precision 16, mantissa bit 7"
    echo "----------------------------------------"

    # Run simulation for precision 32 and mantissa bit 23 pair
    echo "Running simulation with precision 32, mantissa bit 23" 
    sed -i "s/precision = [0-9]\+/precision = 32/" "$TESTBENCH_FILE"
    sed -i "s/mantissa_bit = [0-9]\+/mantissa_bit = 23/" "$TESTBENCH_FILE"
    make ../output_forward_frame/simv
    echo "Simulation completed for precision 32, mantissa bit 23"
    echo "----------------------------------------"
    
    # Run the simulation
    
    echo "Simulation completed for gaussian_inputs = $gaussian_inputs"
    echo "----------------------------------------"
done

echo "All simulations completed."