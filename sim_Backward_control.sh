#!/bin/bash

# Array of gaussian_inputs values to test

# Path to testbench file
TESTBENCH_FILE="./verif/tb/Backward/tb_Backward_Block_controller_with_SRAM.sv"

# Run simulation for precision 16 and mantissa bit 7 pair
echo "Running simulation with precision 16, mantissa bit 7"
sed -i "s/precision = [0-9]\+/precision = 16/" "$TESTBENCH_FILE"
sed -i "s/mantissa_bit = [0-9]\+/mantissa_bit = 7/" "$TESTBENCH_FILE"
make ../output_backward/simv
echo "Simulation completed for precision 16, mantissa bit 7"
echo "----------------------------------------"

# Run simulation for precision 32 and mantissa bit 23 pair
echo "Running simulation with precision 32, mantissa bit 23" 
sed -i "s/precision = [0-9]\+/precision = 32/" "$TESTBENCH_FILE"
sed -i "s/mantissa_bit = [0-9]\+/mantissa_bit = 23/" "$TESTBENCH_FILE"
make ../output_backward/simv
echo "Simulation completed for precision 32, mantissa bit 23"
echo "----------------------------------------"

echo "All simulations completed."