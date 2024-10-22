module skip_distribution #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter inputs = 1,
    parameter FIFO_depth = 32,
    parameter input_data_width = 13, 
    parameter output_data_width = 13
)
(
    input wire clk,
    input wire rst_n,
    // input wire skip [inputs- 1:0],
    // input wire skip_unit_done [inputs - 1:0],

    input wire [inputs- 1:0] skip, // 다른거랑 shape이 다름
    input wire [inputs- 1:0] skip_unit_done,  // 다른거랑 shape이 다름
    input wire stall,

    // data in
    input wire [precision - 1: 0] G_in [inputs-1:0],
    input wire [(2 * precision) - 1: 0] d_in [inputs-1:0],
    input wire [precision - 1:0] alpha_in [inputs-1:0],
    input wire [(4 * precision) - 1: 0] conic_opacity_in [inputs-1:0],
    input wire [(3 * precision) - 1: 0] gaussian_color_in [inputs-1:0],
    input wire [precision - 1: 0] gaussian_depth_in [inputs-1:0],

    input wire [precision - 1: 0] T_first_in [inputs-1:0],
    input wire T_first_valid [inputs-1:0],
    
    //combined output
    output reg [input_data_width * precision : 0] data_out,

    // control signal
    output reg data_valid_out,

    // output reg FIFO_empty, // can be work as Stage 3 valid
    output reg stage1_stall 
);

    // Register declaration
    reg [inputs-1:0] request, request_next;      // Request signal
    reg [input_data_width * precision : 0] data_out_next;
    reg data_valid_next;
    reg stage1_stall_next;
    


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            request <= 'h0;
            data_out <= 'h0;
            data_valid_out <= 'b0;
            stage1_stall <= 'b0;
        end
        
        else begin
            if (!stall) begin
                request <= request_next;
                data_out <= data_out_next;
                data_valid_out <= data_valid_next;
                stage1_stall <= stage1_stall_next;
            end
        end

    end

    always_comb begin
        stage1_stall_next = stage1_stall;
        data_out_next = 'h0;
        data_valid_next = 'b0;
        request_next = request;

        if (request == {inputs{1'b0}}) begin
            request_next = (skip_unit_done & ~skip);
            stage1_stall_next = 1'b0;
            data_out_next = 'h0;
            data_valid_next = 'b0;
        end

        else begin
            for (int i = 0; i < inputs; i++) begin
                if (request[i]) begin
                    // Construct the output data
                    stage1_stall_next = 1'b1;
                    data_out_next = {T_first_in[i], T_first_valid[i], G_in[i], d_in[i], alpha_in[i], conic_opacity_in[i], gaussian_color_in[i], gaussian_depth_in[i]};
                    data_valid_next = 1'b1;
                    // granted_index_next[i] = 1'b1; // Set granted_index for this request
                    request_next[i] = 1'b0;
                    break;                   // Only grant one request per cycle
                end
            end
        end

    end

    // // Fixed-priority arbiter: Grant the lowest-index request and set the output data
    // always_comb begin
    //     granted_index = 'h0;           // Clear the granted index every cycle
    //     data_valid_out = 1'b0;         // Default: no valid data
    //     data_out = 'h0;                // Default: clear data output

    //     for (int i = 0; i < inputs; i++) begin
    //         if (request[i]) begin
    //             // Construct the output data
    //             data_out = {G_in[i], d_in[i], alpha_in[i], conic_opacity_in[i], gaussian_color_in[i], gaussian_depth_in[i], T_first_in[i], T_first_valid[i]};
    //             data_valid_out = 1'b1;
    //             granted_index[i] = 1'b1; // Set granted_index for this request
    //             break;                   // Only grant one request per cycle
    //         end
    //     end
    // end

    // Sequential logic: Handle requests and clear request[i] after it is granted
    // always_ff @(posedge clk) begin

    //     if (!rst_n) begin
    //         request <= 'h0;            // Reset all requests
    //         stage1_stall <= 1'b0;
    //     end 


    //     else begin

    //         if (!stall) begin

    //             if (request == {inputs{1'b0}}) begin // 받아야 하는 상황
    //                 request <= skip_unit_done & ~skip; // Initialize requests only when all are cleared
    //                 stage1_stall <= 1'b1;
    //             end

    //             else begin
    //                 if (granted_index == {inputs{1'b0}}) begin
    //                     stage1_stall <= 1'b0;
    //                 end

    //                 else begin
    //                     for (int i = 0; i < inputs; i++) begin
    //                         if (granted_index[i]) begin
    //                             request[i] <= 1'b0; // Clear request[i] after it is granted
    //                         end

    //                     end

    //                 end

    //             end

    //         end

    //     end

    // end

    // // Fixed-priority arbiter: Grant the lowest-index request and set the output data
    // always_comb begin
    //     granted_index = 'h0;           // Clear the granted index every cycle
    //     data_valid_out = 1'b0;         // Default: no valid data
    //     data_out = 'h0;                // Default: clear data output

    //     for (int i = 0; i < inputs; i++) begin
    //         if (request[i]) begin
    //             // Construct the output data
    //             data_out = {G_in[i], d_in[i], alpha_in[i], conic_opacity_in[i], gaussian_color_in[i], gaussian_depth_in[i], T_first_in[i], T_first_valid[i]};
    //             data_valid_out = 1'b1;
    //             granted_index[i] = 1'b1; // Set granted_index for this request
    //             break;                   // Only grant one request per cycle
    //         end
    //     end
    // end







    // FIFO_pixel #(.FIFO_depth(FIFO_depth), .input_data_width((input_data_width * precision) + 1), output_data_width((output_data_width * precision) + 1))
    //  FIFO_pixel_unit(
    //     // input
    //     .clk(clk), .rst_n(rst_n), .write_data_in(), 
    //     .write_valid_in(),


    //     //output
    //     .read_data_out(), 

    //     .full_out(), .empty_out()
    //  );



endmodule