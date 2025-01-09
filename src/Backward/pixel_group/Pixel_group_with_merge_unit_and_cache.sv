module Pixel_group_with_merge_unit_and_cache
# (
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter precision = 16,
    parameter mantissa_bit = 7,
    parameter num_pixels = 16,
    parameter GID_bit = 24,
    parameter FIFO_depth = 16,
    parameter Banks = 16,
    parameter SRAM_bits = 11 * precision
)
(
    input wire clk,
    input wire rst_n,

    input wire [GID_bit-1:0] gaussian_id_in [num_pixels-1:0],

    input wire [(3*precision)-1:0] dL_dcolor_in [num_pixels-1:0],
    input wire [precision-1:0] dL_ddepth_in [num_pixels-1:0],
    input wire [(2*precision)-1:0] dL_dmean2D_in [num_pixels-1:0],
    input wire [(4*precision)-1:0] dL_dconic_in [num_pixels-1:0],
    input wire [precision-1:0] dL_dopacity_in [num_pixels-1:0],

    input wire GID_valid_in [num_pixels-1:0],

    input wire stall_backpressure,

    output wire stall_to_controller
);


// FF Register Declaration



// Comb Register Declaration



// Wire Declaration





Gradient_merge_unit_by_majority #(
    .BLOCK_SIZE(BLOCK_SIZE),
    .exponent_bit(exponent_bit),
    .precision(precision),
    .num_pixels(num_pixels),
    .GID_bit(GID_bit),
    .FIFO_depth(FIFO_depth),
    .Banks(Banks)
)
(
    .clk(clk),
    .rst_n(rst_n),

    .gaussian_id_in(gaussian_id_in),
    .dL_dcolor_in(dL_dcolor_in),
    .dL_ddepth_in(dL_ddepth_in),
    .dL_dmean2D_in(dL_dmean2D_in),
    .dL_dconic_in(dL_dconic_in),
    .dL_dopacity_in(dL_dopacity_in),

    .GID_valid_in(GID_valid_in),
    .stall_backpressure(stall_backpressure),
    




);

genvar i;
generate
    
    for (i = 0; i < num_pixels; i = i + 1) begin : pixel_group_with_merge_unit_and_cache
        assign stall_to_controller = stall_backpressure;
    end


endgenerate

endmodule