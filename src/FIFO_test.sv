module FIFO_test #(FIFO_depth = 32, FIFO_width = 12 * 32)
    (
    input wire clk,
    input wire rst_n,
    input wire [FIFO_width - 1 : 0] data_in,
    input wire valid_in,

    output reg [FIFO_width - 1 : 0] data_out,
    output reg full,
    output reg empty,
    output reg valid_out
    );


    


endmodule