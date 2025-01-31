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

First_FIFO_depth_values=("2 4") 
#First FIFO depth 1 == No FIFO, Latency 1이라는 가정
Last_FIFO_depth_values=("2 4 8 16")
Bank_values=("8 16")
Encoder_outs_values=("2 4")

# Pixels_values=("16")
# gaussians_values=("2")

# num_pixels_values=("16")

# gaussians_values=("2" "4" "8" "16")

# Path to the Verilog file to modify

# verilog_file="./src/pixel_group/Rasterizer_unit/Rasterizer_unit.sv"
# Iterate over First_FIFO_depth values
for first_fifo_depth in $First_FIFO_depth_values; do
    # Update First_FIFO_depth parameter
    sed -i "s/parameter First_FIFO_depth = [0-9]*/parameter First_FIFO_depth = $first_fifo_depth/" "./verif/tb/Backward/tb_Pixel_group_with_merge_unit_and_cache.sv"
    echo "Current First_FIFO_depth value: $first_fifo_depth"

    # Iterate over Last_FIFO_depth values  
    for last_fifo_depth in $Last_FIFO_depth_values; do
        # Update Last_FIFO_depth parameter
        sed -i "s/parameter Last_FIFO_depth = [0-9]*/parameter Last_FIFO_depth = $last_fifo_depth/" "./verif/tb/Backward/tb_Pixel_group_with_merge_unit_and_cache.sv"
        echo "Current Last_FIFO_depth value: $last_fifo_depth"

        # Iterate over Bank values
        for bank in $Bank_values; do
            # Update Bank parameter
            sed -i "s/parameter Banks = [0-9]*/parameter Banks = $bank/" "./verif/tb/Backward/tb_Pixel_group_with_merge_unit_and_cache.sv"
            echo "Current Bank value: $bank"

            # Iterate over Encoder_outs values
            for encoder_outs in $Encoder_outs_values; do
                # Update Encoder_outs parameter
                sed -i "s/parameter Encoder_outs = [0-9]*/parameter Encoder_outs = $encoder_outs/" "./verif/tb/Backward/tb_Pixel_group_with_merge_unit_and_cache.sv"
                echo "Current Encoder_outs value: $encoder_outs"

                echo "Running simulation with:"
                echo "First_FIFO_depth=$first_fifo_depth"
                echo "Last_FIFO_depth=$last_fifo_depth" 
                echo "Bank=$bank"
                echo "Encoder_outs=$encoder_outs"

                # Run simulation
                make output_backward_grad_merge/simv

                echo "Simulation completed."

            done
        done
    done
done

echo "All simulations completed."
