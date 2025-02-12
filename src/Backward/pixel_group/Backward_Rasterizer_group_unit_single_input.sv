module Backward_Rasterizer_group_unit_single_input #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter num_pixels = 16, // number of pixel units
    parameter GID_bit = 24
    ) 
    (
    input logic clk,
    input logic rst_n,
    input logic i_valid [1 * num_pixels - 1:0],

    input logic [11:0] W,
    input logic [11:0] H,

    input logic start [num_pixels-1:0],
    input logic [(3 * precision) - 1:0] dL_dpixel [num_pixels-1:0],
    input logic [precision - 1:0] dL_dpixel_depth [num_pixels-1:0],
    input logic [precision - 1:0] T_first [num_pixels-1:0],

    input logic [15:0] block_id,
    input logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id [num_pixels-1:0],

    input logic stall_backpressure [num_pixels-1:0],

    input logic last_input [1 * num_pixels -1:0],



    input logic [(2 * precision) - 1:0] mean2D [1 * num_pixels - 1:0],
    input logic [(4 * precision) - 1:0] conic_opacity [1 * num_pixels - 1:0],

    input logic [GID_bit-1:0] gaussian_id_in [1 * num_pixels - 1:0],
    input logic [(3 * precision) - 1:0] gaussian_color [1 * num_pixels - 1:0],
    input logic [precision - 1 : 0] gaussian_depth [1 * num_pixels - 1:0],

    // input logic [(2 * precision) - 1:0] mean2D [1-1:0][num_pixels-1:0],
    // input logic [(4 * precision) - 1:0] conic_opacity [1-1:0][num_pixels-1:0],

    // input logic [31:0] gaussian_id [1-1:0][num_pixels-1:0],
    // input logic [(3 * precision) - 1:0] gaussian_color [1-1:0][num_pixels-1:0],
    // input logic [precision - 1 : 0] gaussian_depth [1-1:0][num_pixels-1:0],

    output logic [(3 * precision) - 1:0] dL_dcolor_out [num_pixels-1:0],
    output logic [precision - 1:0] dL_ddepth_out [num_pixels-1:0],
    output logic [precision - 1:0] dL_dopacity_out [num_pixels-1:0],
    output logic [(2 * precision) - 1:0] dL_dmean2D_out [num_pixels-1:0],
    output logic [(4 * precision) - 1:0] dL_dconic_out [num_pixels-1:0],
    output logic [GID_bit-1:0] gaussian_id_out [num_pixels-1:0],

    output logic gradient_valid_out [num_pixels-1:0],
    output logic stall_to_controller [num_pixels-1:0],
    output logic last_input_done [num_pixels-1:0]
);
    //synopsys template

    genvar i;
    generate
        for (i = 0; i < num_pixels; i = i + 1) begin : rasterizer_units
            Backward_Rasterizer_unit_single_input #(
            .BLOCK_SIZE(BLOCK_SIZE),
            .exponent_bit(exponent_bit),
            .mantissa_bit(mantissa_bit),
            .precision(precision),
            .GID_bit(GID_bit)
            )
            rasterizer_inst (
                .clk(clk),
                .rst_n(rst_n),

                .i_valid(i_valid[i]),

                .W(W),
                .H(H),

                .start(start[i]),
                .dL_dpixel(dL_dpixel[i]),
                .dL_dpixel_depth(dL_dpixel_depth[i]),
                .T_first(T_first[i]),

                .block_id(block_id),
                .pixel_id(pixel_id[i]),

                .stall_backpressure(stall_backpressure[i]),

                .last_input(last_input[i]),

                // .mean2D(mean2D[i * 1 +: 1]),
                .mean2D(mean2D[i]),
                .conic_opacity(conic_opacity[i]),
                .gaussian_id(gaussian_id_in[i]),
                .gaussian_color(gaussian_color[i]),
                .gaussian_depth(gaussian_depth[i]),
                

                .dL_dcolor_out(dL_dcolor_out[i]),
                .dL_ddepth_out(dL_ddepth_out[i]),
                .dL_dopacity_out(dL_dopacity_out[i]),
                .dL_dmean2D_out(dL_dmean2D_out[i]),
                .dL_dconic_out(dL_dconic_out[i]),
                .gaussian_id_out(gaussian_id_out[i]),

                .gradient_valid_out(gradient_valid_out[i]),
                .stall_to_controller(stall_to_controller[i]),
                .last_input_done(last_input_done[i])
            );
        end
    endgenerate

endmodule

// genvar i, j;
// generate
//     for (i = 0; i < num_pixels; i = i + 1) begin : rasterizer_units
//         Rasterizer_unit rasterizer_inst (
//             .clk(clk),
//             .rst_n(rst_n),
//             .i_valid(i_valid[i]),

//             .W(W),
//             .H(H),

//             .start(start[i]),
//             .dL_dpixel(dL_dpixel[i]),
//             .dL_dpixel_depth(dL_dpixel_depth[i]),
//             .T_first(T_first[i]),

//             .block_id(block_id),
//             .pixel_id(pixel_id[i]),

//             .stall_backpressure(stall_backpressure[i]),

//             // Connect each Gaussian parameter for this pixel unit
//             .mean2D({
//                 mean2D[0][i],
//                 mean2D[1][i],
//                 mean2D[2][i],
//                 mean2D[3][i]
//             }),
//             .conic_opacity({
//                 conic_opacity[0][i],
//                 conic_opacity[1][i],
//                 conic_opacity[2][i],
//                 conic_opacity[3][i]
//             }),

//             .gaussian_id({
//                 gaussian_id[0][i],
//                 gaussian_id[1][i],
//                 gaussian_id[2][i],
//                 gaussian_id[3][i]
//             }),
//             .gaussian_color({
//                 gaussian_color[0][i],
//                 gaussian_color[1][i],
//                 gaussian_color[2][i],
//                 gaussian_color[3][i]
//             }),
//             .gaussian_depth({
//                 gaussian_depth[0][i],
//                 gaussian_depth[1][i],
//                 gaussian_depth[2][i],
//                 gaussian_depth[3][i]
//             }),

//             .dL_dcolor_out(dL_dcolor_out[i]),
//             .dL_ddepth_out(dL_ddepth_out[i]),
//             .dL_dopacity_out(dL_dopacity_out[i]),
//             .dL_dmean2D_out(dL_dmean2D_out[i]),
//             .dL_dconic_out(dL_dconic_out[i]),
//             .gaussian_id_out(gaussian_id_out[i]),

//             .gradient_valid_out(gradient_valid_out[i]),
//             .stall_to_controller(stall_to_controller[i])
//         );
//     end
//     endgenerate