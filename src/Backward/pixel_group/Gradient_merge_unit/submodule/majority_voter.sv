// latency : 2 clock cycles
module majority_voter
#(
    parameter num_pixels = 16,
    parameter GID_bit = 24
)
(
    input wire clk,
    input wire rst_n,

    input wire [GID_bit-1:0] gaussian_id [num_pixels-1:0],
    input wire GID_valid [num_pixels-1:0],
    
    input wire stall_backpressure,

    output reg is_majority_gid [num_pixels-1:0]
);
    // synopsys template

    // Temporary storage for unique GIDs and their counts
    
    
    reg [GID_bit-1:0] unique_gid_temp [num_pixels-1:0];
    reg [$clog2(num_pixels):0] unique_gid_count [num_pixels-1:0];
    reg same_gid_flag [num_pixels-1:0];
    // integer unique_gids;
    // integer majority_index;
    reg [$clog2(num_pixels)-1:0] majority_index;
    reg is_majority_gid_temp [num_pixels-1:0];
    reg first_valid_flag;

    reg [$clog2(num_pixels):0] majority_count;

    // FF Registers
    reg [GID_bit-1:0] unique_gid_next [num_pixels-1:0];
    reg [$clog2(num_pixels):0] unique_gid_count_next [num_pixels-1:0];
    reg GID_valid_next [num_pixels-1:0];
    reg [GID_bit-1:0] gaussian_id_next [num_pixels-1:0];


    // always_comb begin
    //     majority_count = 'd0;
    //     unique_gids = 'd1;
    //     majority_index = 'd0;
    //     first_valid_flag = 1'b0;

    //     // For not latching the output
    //     for (int i = 0; i < num_pixels; i++) begin
    //         is_majority_gid_temp[i] = 'b0;
    //         unique_gid_temp[i] = 'h0;
    //         unique_gid_count[i] = 'd0;
    //     end

    //     for (int i = 0; i < num_pixels; i++) begin
    //         same_gid_flag[i] = 1'b0;
            
    //         // Use fixed size loop to avoid synthesis issues
    //         if (GID_valid[i]) begin
    //             for (int j = 0; j < num_pixels; j++) begin

    //                 // First valid GID found


    //                 if (j == 0 && !first_valid_flag) begin
    //                     unique_gid_temp[0] = gaussian_id[i];
    //                     unique_gid_count[0] = 'd1;
    //                     same_gid_flag[i] = 1'b1;
    //                     first_valid_flag = 1'b1;
    //                 end

    //                 // Check remaining slots
    //                 else if (!same_gid_flag[i]) begin
    //                     // Match found - increment count
    //                     if (unique_gid_temp[j] == gaussian_id[i]) begin
    //                         unique_gid_count[j] = unique_gid_count[j] + 'd1;
    //                         same_gid_flag[i] = 1'b1;
    //                     end
    //                     // No match and empty slot - add new entry
    //                     else if (unique_gid_count[j] == 0) begin
    //                         unique_gid_temp[j] = gaussian_id[i];
    //                         unique_gid_count[j] = 'd1;
    //                         same_gid_flag[i] = 1'b1;
    //                     end
    //                 end
    //             end
    //         end
    //     end

    //     // Find majority GID using fixed bounds
    //     for (int i = 0; i < num_pixels; i++) begin
    //         if (unique_gid_count[i] > majority_count) begin
    //             majority_count = unique_gid_count[i];
    //             majority_index = i;
    //         end
    //     end

    //     // Assign the majority GID
    //     for (int i = 0; i < num_pixels; i++) begin
    //         // if ((unique_gid_temp[majority_index] == gaussian_id[i]) && majority_count >= 2 ) begin
    //         if ((unique_gid_temp[majority_index] == gaussian_id[i]) && majority_count >= 2 && GID_valid[i]) begin                
    //             is_majority_gid_temp[i] = 1'b1;
    //         end
    //     end
    // end


    always_comb begin
        first_valid_flag = 1'b0;

        // For not latching the output
        for (int i = 0; i < num_pixels; i++) begin
            unique_gid_temp[i] = 'h0;
            unique_gid_count[i] = 'd0;
        end


        for (int i = 0; i < num_pixels; i++) begin
            same_gid_flag[i] = 1'b0;
        
            
            // Use fixed size loop to avoid synthesis issues
            if (GID_valid[i]) begin

                // First valid GID found
                if (!first_valid_flag) begin
                    unique_gid_temp[0] = gaussian_id[i];
                    unique_gid_count[0] = 'd1;
                    same_gid_flag[i] = 1'b1;
                    first_valid_flag = 1'b1;
                end

                for (int j = 0; j < num_pixels; j++) begin
                    // Check remaining slots
                    if (!same_gid_flag[i]) begin

                        // Match found - increment count
                        if (unique_gid_temp[j] == gaussian_id[i]) begin
                            unique_gid_count[j] = unique_gid_count[j] + 'd1;
                            same_gid_flag[i] = 1'b1;
                        end

                        // No match and empty slot - add new entry
                        else if (unique_gid_count[j] == 0) begin
                            unique_gid_temp[j] = gaussian_id[i];
                            unique_gid_count[j] = 'd1;
                            same_gid_flag[i] = 1'b1;
                        end
                    end
                end
            end
        end

        // 여기서 자르고
    end


    always_comb begin
        majority_count = 'd0;
        majority_index = 'd0;

        // Find majority GID using fixed bounds
        for (int i = 0; i < num_pixels; i++) begin
            is_majority_gid_temp[i] = 'b0;

            if (unique_gid_count[i] > majority_count) begin
                majority_count = unique_gid_count_next[i];
                majority_index = i[$clog2(num_pixels)-1:0];
            end
        end

        // Assign the majority GID
        for (int i = 0; i < num_pixels; i++) begin
            if ((unique_gid_next[majority_index] == gaussian_id_next[i]) && (majority_count >= 2) && (GID_valid_next[i])) begin                
                is_majority_gid_temp[i] = 1'b1;
            end
        end
    end




    always_ff @ (posedge clk) begin

        if (!rst_n) begin
            for (int i = 0; i < num_pixels; i++) begin
                is_majority_gid[i] <= 1'b0;
                GID_valid_next[i] <= 1'b0;
                unique_gid_count_next[i] <= 'd0;
                unique_gid_next[i] <= 'h0;
                gaussian_id_next[i] <= 'h0;
            end
        end

        else begin
            if (!stall_backpressure) begin
                for (int i = 0; i < num_pixels; i++) begin
                    is_majority_gid[i] <= is_majority_gid_temp[i];

                    // GID_Valid
                    GID_valid_next[i] <= GID_valid[i];
                    // unique_gid_count
                    unique_gid_count_next[i] <= unique_gid_count[i];
                    // unique_gid
                    unique_gid_next[i] <= unique_gid_temp[i];
                    // gaussian_id
                    gaussian_id_next[i] <= gaussian_id[i];

                end
            end
        end
    end

endmodule