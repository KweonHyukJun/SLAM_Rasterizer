module majority_voter
#(
    parameter num_pixels = 4,
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
    // Temporary storage for unique GIDs and their counts
    
    reg [$clog2(num_pixels):0] majority_count;
    reg [GID_bit-1:0] unique_gid_temp [num_pixels-1:0];
    reg [$clog2(num_pixels):0] unique_gid_count [num_pixels-1:0];
    reg same_gid_flag [num_pixels-1:0];
    integer unique_gids;
    integer majority_index;
    reg is_majority_gid_temp [num_pixels-1:0];
    reg first_valid_flag;


    always_comb begin
        majority_count = 'd0;
        unique_gids = 'd1;
        majority_index = 'd0;
        first_valid_flag = 1'b0;

        // For not latching the output
        for (int i = 0; i < num_pixels; i++) begin
            is_majority_gid_temp[i] = 'h0;
            unique_gid_temp[i] = 'h0;
            unique_gid_count[i] = 'd0;
        end

        // Find all unique GIDs
        for (int i = 0; i < num_pixels; i++) begin
            same_gid_flag[i] = 1'b0;
            
            if (GID_valid[i]) begin
                for (int j = 0; j < unique_gids; j++) begin

                    if (!first_valid_flag) begin
                        unique_gid_temp[j] = gaussian_id[i];
                        unique_gid_count[j] = 'd1;
                        same_gid_flag[i] = 1'b1;
                        first_valid_flag = 1'b1;
                    end

                    else if (!same_gid_flag[i]) begin
                        // Same GID found
                        if ((unique_gid_temp[j] == gaussian_id[i])) begin
                            unique_gid_count[j] = unique_gid_count[j] + 'd1;
                            same_gid_flag[i] = 1'b1;
                        end

                        // New GID found
                        else if ((j == (unique_gids - 1))) begin
                            unique_gid_temp[unique_gids] = gaussian_id[i];
                            unique_gid_count[unique_gids] = 'd1;
                            unique_gids = unique_gids + 'd1;
                        end
                    end
                end
            end
        end

        // After finding all unique GIDs, find the majority GID
        for (int i = 0; i < unique_gids; i++) begin
            if (unique_gid_count[i] > majority_count) begin
                majority_count = unique_gid_count[i];
                majority_index = i;
            end
        end

        // Assign the majority GID
        for (int i = 0; i < num_pixels; i++) begin
            if ((unique_gid_temp[majority_index] == gaussian_id[i]) && majority_count >= 2) begin
                is_majority_gid_temp[i] = 1'b1;
            end
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < num_pixels; i++) begin
                is_majority_gid[i] <= 1'b0;
            end
        end
        else begin
            if (!stall_backpressure) begin
                for (int i = 0; i < num_pixels; i++) begin
                    is_majority_gid[i] <= is_majority_gid_temp[i];
                end
            end
        end
    end

endmodule