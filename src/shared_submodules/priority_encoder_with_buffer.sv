module priority_encoder_with_buffer #(
    parameter INPUTS = 16,
    parameter OUTPUTS = 4,
    // parameter precision = 16,
    // parameter GID_bit = 24,
    // parameter DATA_SIZE = 11 * precision + GID_bit
    parameter DATA_SIZE = 200
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
    output logic                        last_input_done_grant_o[INPUTS-1:0], // Wire


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


// FF
reg output_valid_temp [OUTPUTS-1:0];
reg output_encoder_full; 
reg last_input_done_temp [OUTPUTS-1:0];

// 4 cycles with 16 data
// $clog2(num_pixels)-1 bit is for full/empty

reg [$clog2(INPUTS)-1:0] first_stage_valid_count;
reg circular_buffer_full;
reg circular_buffer_empty;

// Wire
wire first_stage_valid [INPUTS-1:0];

wire full_out;
wire empty_out;

wire pop_valid_out [OUTPUTS-1:0];
wire [DATA_SIZE:0] pop_data_out [OUTPUTS-1:0];

wire push_valid_in;
wire pop_valid_in;

wire push_data_in [INPUTS-1:0];

wire push_valid_index_in [INPUTS-1:0];
wire push_valid_in_grant_out [INPUTS-1:0];


genvar i , j;
generate

    for (i = 0 ; i < INPUTS ; i = i + 1) begin : push_valid_index_assign
        assign push_valid_index_in[i] = src_request_i[i] || last_input_done_i[i];
    end

    for (i = 0; i < OUTPUTS; i = i + 1) begin : output_assign
        // assign dst_data_o[i] = output_temp[i];
        // assign dst_valid_o[i] = output_valid_temp[i];
        assign dst_data_o[i] = pop_data_out[i];
        assign dst_valid_o[i] = pop_valid_out[i][DATA_SIZE-1:0];
        assign last_input_done_o[i] = pop_valid_out[i][DATA_SIZE];
    end

    for (j = 0; j < INPUTS; j = j + 1) begin : last_input_done_grant_assign
        assign last_input_done_grant_o[j] = last_input_done_grant_temp[j];
    end
endgenerate

// assign stall_from_encoder = stall_backpressure || output_encoder_full;

assign stall_from_encoder = stall_backpressure || full_out;
assign pop_valid_in = dst_ready_i && !empty_out && !stall_backpressure;

always_comb begin
    push_valid_in = push_valid_index_in[0];
    for (int k = 1 ; k < INPUTS ; k = k + 1) begin
        push_valid_in = push_valid_in || push_valid_index_in[k];
    end
end


always_ff @(posedge clk) begin
    if (!rst_n) begin

    end

    else begin
        if (!stall_backpressure) begin

        end

    end

end



// Try to Make all inputs are FF registered

// Priority Encoder FIFO
Priority_encoder_FIFO #(
    .FIFO_depth(INPUTS),
    .DATA_WIDTH(DATA_SIZE),
    .Encoder_out(OUTPUTS),
    .Encoder_in(INPUTS)
)
Priority_encoder_FIFO_inst (
    .clk(clk),
    .rst_n(rst_n),

    .push_data_in(push_data_in),
    .push_valid_in(push_valid_in), 
    .push_valid_index_in(push_valid_index_in), // 이게 valid하게 들어갈 index, Registered 


    .push_valid_in_grant_out(push_valid_in_grant_out), // 들어간 index가 유효하게 FIFO로 기입될 시 1, 아니면 0 1이면 push_valid_index_in 0
    

    .pop_valid_in(pop_valid_in), // FIFO pop하는 신호

    .pop_data_out(pop_data_out),
    .pop_valid_out(dst_valid_o), 


    .full_out(full_out),
    .empty_out(empty_out)
);


endmodule