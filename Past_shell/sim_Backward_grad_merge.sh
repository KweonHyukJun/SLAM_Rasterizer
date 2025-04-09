#!/bin/bash

# Arrays of values for mantissa and precision bit pairs

# mantissa_bit_values=("7")
# precision_values=("16")
# mantissa_bit_values=("7" "15" "23")
# precision_values=("16" "24" "32")



# Arrays of values for Hz and clk_time
# Hz_values=("600M" "800M" "1G")
# clk_time_values=("1.67" "1.25" "1.0")
# Hz_values=("600M")
# clk_time_values=("1.67")

First_FIFO_depth_values=("4") 
#First FIFO depth 1 == No FIFO, Latency 1이라는 가정
Last_FIFO_depth_values=("16")
Bank_values=("16")

# gaussian_inputs_values=("2" "3" "4" "8")
gaussian_inputs_values=("8" "3" "2")


# Pixels_values=("16")
# gaussians_values=("2")

# num_pixels_values=("16")

# gaussians_values=("2" "4" "8" "16")

# Path to the Verilog file to modify

# verilog_file="./src/pixel_group/Rasterizer_unit/Rasterizer_unit.sv"
# Iterate over First_FIFO_depth values

# for first_fifo_depth in "${First_FIFO_depth_values[@]}"; do
#     sed -i "s/parameter First_FIFO_depth = [0-9]*/parameter First_FIFO_depth = $first_fifo_depth/" "./verif/tb/Backward/tb_Combined_Backward_Rasterizer_and_merge_with_SRAM.sv"
#     echo "Updated First_FIFO_depth to: $first_fifo_depth"
#     grep "First_FIFO_depth" "./verif/tb/Backward/tb_Combined_Backward_Rasterizer_and_merge_with_SRAM.sv"
    
#     for last_fifo_depth in "${Last_FIFO_depth_values[@]}"; do
#         sed -i "s/parameter Last_FIFO_depth = [0-9]*/parameter Last_FIFO_depth = $last_fifo_depth/" "./verif/tb/Backward/tb_Combined_Backward_Rasterizer_and_merge_with_SRAM.sv"
#         echo "Updated Last_FIFO_depth to: $last_fifo_depth"
#         grep "Last_FIFO_depth" "./verif/tb/Backward/tb_Combined_Backward_Rasterizer_and_merge_with_SRAM.sv"
        
        
#         for bank in ${Bank_values[@]}; do
#             sed -i "s/parameter Banks = [0-9]*/parameter Banks = $bank/" "./verif/tb/Backward/tb_Combined_Backward_Rasterizer_and_merge_with_SRAM.sv"
#             echo "Updated Bank to: $bank"
#             grep "Banks" "./verif/tb/Backward/tb_Combined_Backward_Rasterizer_and_merge_with_SRAM.sv"
            
#             echo "Running simulation with configuration:"
#             echo "First_FIFO_depth=$first_fifo_depth, Last_FIFO_depth=$last_fifo_depth, Bank=$bank"
            
#             if make ../output_combined_backward/simv; then
#                 echo "Simulation completed successfully"
#             else
#                 echo "Simulation failed with error code $?"
#             fi
#         done
#     done
# done

for gaussian_inputs in "${gaussian_inputs_values[@]}"; do
    echo "Running simulation with gaussian_inputs: $gaussian_inputs"

    sed -i "s/parameter gaussian_inputs = [0-9]*/parameter gaussian_inputs = $gaussian_inputs/" "./verif/tb/Backward/tb_Combined_Backward_Rasterizer_and_merge_with_SRAM_with_changed_encoder.sv"
    grep "gaussian_inputs" "./verif/tb/Backward/tb_Combined_Backward_Rasterizer_and_merge_with_SRAM.sv"

    make ../output_combined_backward/simv
    echo "Simulation completed successfully"
    

done
echo "All simulations completed."

