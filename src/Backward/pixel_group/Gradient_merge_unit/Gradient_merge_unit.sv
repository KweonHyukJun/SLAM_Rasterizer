module Gradient_merge_unit #(BLOCK_SIZE = 16, exponent_bit = 8, precision = 16, mantissa_bit = 7, num_pixels = 16, GID_bit = 24) (
    input logic clk,
    input logic rst_n,
    
    input logic [GID_bit-1:0] gaussian_id [num_pixels-1:0],
    input logic [(3*precision)-1:0] dL_dcolor [num_pixels-1:0],
    input logic [precision-1:0] dL_ddepth [num_pixels-1:0],
    input logic [(2*precision)-1:0] dL_dmean2D [num_pixels-1:0],
    input logic [(4*precision)-1:0] dL_dconic [num_pixels-1:0],
    input logic [precision-1:0] dL_dopacity [num_pixels-1:0],

    input logic [GID_bit-1:0] gaussian_id_in [num_pixels-1:0],
    input logic GID_valid [num_pixels-1:0], // gradient_valid_out in Backward_Rasterizer_unit

    input logic stall_backpressure,


    output logic [precision-1:0] dL_dcolor_out [num_pixels-1:0],
    output logic [precision-1:0] dL_ddepth_out [num_pixels-1:0],
    output logic [precision-1:0] dL_dmean2D_out [num_pixels-1:0],
    output logic [precision-1:0] dL_dconic_out [num_pixels-1:0],
    output logic [precision-1:0] dL_dopacity_out [num_pixels-1:0],

    output logic [GID_bit-1:0] gaussian_id_out [num_pixels-1:0],
    output logic GID_valid_out [num_pixels-1:0], 

    output logic stall_to_controller
);

    // Wire Declare
    logic is_majority_gid [num_pixels-1:0];

    // Register Declare



    majority_voter #(
        .num_pixels(num_pixels),
        .GID_bit(GID_bit)
    )
    majority_voter_inst (
    .clk(clk),
    .rst_n(rst_n),

    .gaussian_id(gaussian_id_in),
    .GID_valid(GID_valid),
    .stall_backpressure(stall_backpressure),

    .is_majority_gid(is_majority_gid)
    );


    majority_adder #(
        .num_pixels(num_pixels),
        .precision(precision),
        .exponent_bit(exponent_bit)
    )    
    majority_adder_inst (
        .clk(clk),
        .rst_n(rst_n),

        .dL_dcolor_in(dL_dcolor),
        .dL_ddepth_in(dL_ddepth),
        .dL_dmean2D_in(dL_dmean2D),
        .dL_dconic_in(dL_dconic),
        .dL_dopacity_in(dL_dopacity),

        .is_majority_gid_in(is_majority_gid),

        .stall_backpressure(stall_backpressure),

        .dL_dcolor_out(dL_dcolor_out),
        .dL_ddepth_out(dL_ddepth_out),
        .dL_dmean2D_out(dL_dmean2D_out),
        .dL_dconic_out(dL_dconic_out),
        .dL_dopacity_out(dL_dopacity_out),

        .majority_valid_out(majority_valid_out)
    );
    





    always_ff @ (posedge clk) begin
        if (!rst_n) begin

        end
    end




endmodule