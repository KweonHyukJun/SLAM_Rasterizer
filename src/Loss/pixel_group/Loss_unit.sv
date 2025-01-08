module Loss_unit 
#(
    parameter exponent_bit = 8, 
    parameter precision = 16,
    parameter mantissa_bit = 7,
    parameter num_pixels = 16
)
(
    input wire clk,
    input wire rst_n,

    // Gradient를 구하는 원본 값
    input wire [precision - 1:0] depth_in [num_pixels-1:0],
    input wire [3 * precision - 1:0] image_in [num_pixels-1:0],
    input wire [precision - 1:0] opacity_in [num_pixels-1:0],
    input wire [precision - 1:0] exp_a_in [num_pixels-1:0],
    input wire [precision - 1:0] exp_b_in [num_pixels-1:0],

    output reg [precision-1:0] dL_ddepth_out [num_pixels-1:0],
    output reg [3 * precision - 1:0] dL_dcolor_out [num_pixels-1:0],
    output reg [precision - 1:0] dL_dexp_a_out [num_pixels-1:0],
    output reg [precision - 1:0] dL_dexp_b_out [num_pixels-1:0]
);

endmodule