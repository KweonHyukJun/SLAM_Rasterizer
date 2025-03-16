module Forward_Rasterizer_group_unit #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 3, // in one pixel unit, gaussians
    parameter num_pixels = 16, // number of pixel units
    parameter GID_bit = 24
    ) 
    (
    input logic clk,
    input logic rst_n,
    input logic i_valid [(gaussian_inputs * num_pixels) - 1:0],



    input logic start [num_pixels-1:0],

    input logic [15:0] block_id,
    input logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id [num_pixels-1:0],

    // input logic stall_backpressure [num_pixels-1:0],
    input logic stall_backpressure,

    input logic last_input [gaussian_inputs * num_pixels -1:0],



    input logic [(2 * precision) - 1:0] mean2D [gaussian_inputs * num_pixels - 1:0],
    input logic [(4 * precision) - 1:0] conic_opacity [gaussian_inputs * num_pixels - 1:0],

    input logic [GID_bit-1:0] gaussian_id_in [gaussian_inputs * num_pixels - 1:0],
    input logic [(3 * precision) - 1:0] gaussian_color [gaussian_inputs * num_pixels - 1:0],
    input logic [precision - 1 : 0] gaussian_depth [gaussian_inputs * num_pixels - 1:0],


    output logic [GID_bit-1:0] gaussian_id_out [num_pixels-1:0],
    output logic pixel_valid_out [num_pixels-1:0],

    output logic stall_to_controller [num_pixels-1:0],
    

    output logic [(3 * precision)-1:0] pixel_color_out [num_pixels-1:0],
    output logic [precision-1:0] pixel_depth_out [num_pixels-1:0],
    output logic [precision-1:0] pixel_opacity_out [num_pixels-1:0],
    output logic [precision-1:0] T_first_out [num_pixels-1:0],

    output logic [11:0] n_contrib_out [num_pixels-1:0]
);

    genvar i;
    generate
        for (i = 0; i < num_pixels; i = i + 1) begin : rasterizer_units
            Forward_Rasterizer_unit #(

                .BLOCK_SIZE(BLOCK_SIZE),
                .exponent_bit(exponent_bit),
                .mantissa_bit(mantissa_bit),
                .precision(precision),
                .gaussian_inputs(gaussian_inputs),
                .GID_bit(GID_bit)
                
            )
            rasterizer_inst (
                .clk(clk),
                .rst_n(rst_n),

                .i_valid(i_valid[((i + 1) * gaussian_inputs) - 1 : i * gaussian_inputs]),

                .start(start[i]),

                .block_id(block_id),
                .pixel_id(pixel_id[i]),

                // .stall_backpressure(stall_backpressure[i]),
                .stall_backpressure(stall_backpressure),

                .last_input(last_input[ ((i + 1) * gaussian_inputs) - 1 : i * gaussian_inputs]),

                // .mean2D(mean2D[i * gaussian_inputs +: gaussian_inputs]),
                .mean2D(mean2D[( (i + 1) * gaussian_inputs) - 1 : i * gaussian_inputs]),
                .conic_opacity(conic_opacity[( (i + 1) * gaussian_inputs) - 1 : i * gaussian_inputs]),
                .gaussian_id(gaussian_id_in[( (i + 1) * gaussian_inputs) - 1 : i * gaussian_inputs]),
                .gaussian_color(gaussian_color[( (i + 1) * gaussian_inputs) - 1 : i * gaussian_inputs]),
                .gaussian_depth(gaussian_depth[( (i + 1) * gaussian_inputs) - 1 : i * gaussian_inputs]),
                

                .gaussian_id_out(gaussian_id_out[i]),
                .pixel_valid_out(pixel_valid_out[i]),

                .stall_to_controller(stall_to_controller[i]),
                .pixel_color_out(pixel_color_out[i]),
                .pixel_depth_out(pixel_depth_out[i]),
                .pixel_opacity_out(pixel_opacity_out[i]),
                .T_first_out(T_first_out[i]),
                .n_contrib_out(n_contrib_out[i])
            );
        end
    endgenerate

endmodule
