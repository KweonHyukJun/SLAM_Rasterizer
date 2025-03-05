module Backward_top_controller
(
    input wire clk,
    input wire rst_n,


    // Connection with Entire system controller
    input wire loss_block_done,
    input wire [11:0] block_index_for_backward_control,

    output wire backward_ready,

    // Connection with Block Controller
    input wire 



    // Connection with External DRAM Memory



    // Connection with Cache SRAM











);

// State
reg [1:0] Gradient_state_current;
reg [1:0] Gradient_state_next;

localparam  GRADIENT_IDLE = 2'd0,
            GRADIENT_BUSY = 2'd1,
            GRADIENT_FETCHING = 2'd2;

reg [1:0] Top_block_value_state_current;
reg [1:0] Top_block_value_state_next;

localparam  TOP_BLOCK_IDLE = 2'd0,
            TOP_BLOCK_FETCHING = 2'd1,
            TOP_BLOCK_DONE = 2'd2;


endmodule