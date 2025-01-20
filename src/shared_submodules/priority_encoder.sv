module priority_encoder #(
    parameter INPUTS = 16,
    parameter OUTPUTS = 4,
    // parameter precision = 16,
    // parameter GID_bit = 24,
    // parameter DATA_SIZE = 11 * precision + GID_bit
    parameter DATA_SIZE = 24
) 
(
    input logic                clk,
    input logic                rst_n,  // _n means active low

    // input interfaces
    // input logic                src_valid_i[N_MASTER-1:0],
    // output logic                 src_ready_o[N_MASTER-1:0],
    // input logic    [DATA_SIZE-1:0]     src_data_i[N_MASTER-1:0],

    input logic                         src_request_i[INPUTS-1:0], // Wire
    output logic                        src_grant_o[INPUTS-1:0], // Wire
    input logic    [DATA_SIZE-1:0]      src_data_i[INPUTS-1:0], // Wire

    input logic                         last_input_done_i[INPUTS-1:0], // Wire
    output logic                        last_input_done_o[OUTPUTS-1:0], // Wire

    // output interface
    output logic                    dst_valid_o [OUTPUTS-1:0], // Wire
    input   wire                    dst_ready_i,
    output logic     [DATA_SIZE-1:0] dst_data_o [OUTPUTS-1:0], // Wire

    input logic                  stall_backpressure, // Wire
    output logic                 stall_from_encoder // Wire

    // input logic                  dst_ready_i
);
 //synopsys template


integer input_idx; 
integer output_idx;

// Comb
reg [DATA_SIZE-1:0] output_temp [OUTPUTS-1:0];
reg output_valid_temp [OUTPUTS-1:0];
reg output_encoder_full; 
reg last_input_done_temp [OUTPUTS-1:0];

// Wire


always_comb begin

    for (int k = 0; k < OUTPUTS; k = k + 1) begin
        output_temp[k] = 'h0;
        output_valid_temp[k] = 1'b0;
        last_input_done_temp[k] = 1'b0;
    end

    output_idx = 0;
    output_encoder_full = 1'b0;
    

    for (input_idx = 0; input_idx < INPUTS; input_idx = input_idx + 1) begin
        src_grant_o[input_idx] = 1'b0;

        // if ((src_request_i[input_idx] || last_input_done_i[input_idx]) && !output_encoder_full && dst_ready_i) begin
        if ((src_request_i[input_idx] || last_input_done_i[input_idx]) && !output_encoder_full) begin

            output_temp[output_idx] = src_data_i[input_idx];
            output_valid_temp[output_idx] = 1'b1;

            if (dst_ready_i) begin
                src_grant_o[input_idx] = 1'b1;
            end
            
            // Last input
            if (last_input_done_i[input_idx]) begin
                last_input_done_temp[output_idx] = 1'b1;
            end

            output_idx = output_idx + 1;

            if (output_idx == OUTPUTS) begin
                output_encoder_full = 1'b1;
            end

        end
    end
end

genvar i;
generate
    for (i = 0; i < OUTPUTS; i = i + 1) begin : output_assign
        assign dst_data_o[i] = output_temp[i];
        assign dst_valid_o[i] = output_valid_temp[i];
        assign last_input_done_o[i] = last_input_done_temp[i];
    end
endgenerate

assign stall_from_encoder = stall_backpressure || output_encoder_full;


endmodule