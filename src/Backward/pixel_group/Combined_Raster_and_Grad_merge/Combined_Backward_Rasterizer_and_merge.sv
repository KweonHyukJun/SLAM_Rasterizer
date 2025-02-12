module Combined_Backward_Rasterizer_and_merge #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 2, // in one pixel unit, gaussians
    parameter num_pixels = 24, // number of pixel units
    // parameter GID_bit = 24,
    parameter GID_bit = 24,
    parameter First_FIFO_depth = 4,
    parameter Last_FIFO_depth = 16,    
    parameter Banks = 16,
    parameter SRAM_bits = 11 * precision,
    parameter Bank_depth = 128,
    parameter Encoder_outs = 4
    )
    (
        // Input to Backward Rasterizer Unit
        input logic clk,
        input logic rst_n,
        input logic i_valid [gaussian_inputs * num_pixels - 1:0],

        input logic [11:0] W,
        input logic [11:0] H,

        input logic start [num_pixels-1:0],
        input logic [(3 * precision) - 1:0] dL_dpixel [num_pixels-1:0],
        input logic [precision - 1:0] dL_dpixel_depth [num_pixels-1:0],
        input logic [precision - 1:0] T_first [num_pixels-1:0],

        input logic [15:0] block_id,
        input logic [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id [num_pixels-1:0],

        input logic stall_backpressure,

        input logic last_input [gaussian_inputs * num_pixels -1:0],

        input logic [(2 * precision) - 1:0] mean2D [gaussian_inputs * num_pixels - 1:0],
        input logic [(4 * precision) - 1:0] conic_opacity [gaussian_inputs * num_pixels - 1:0],

        input logic [GID_bit-1:0] gaussian_id_in [gaussian_inputs * num_pixels - 1:0],
        input logic [(3 * precision) - 1:0] gaussian_color [gaussian_inputs * num_pixels - 1:0],
        input logic [precision - 1 : 0] gaussian_depth [gaussian_inputs * num_pixels - 1:0],

        output logic stall_to_controller [num_pixels-1:0],

        // Input and Output from Gradient Merge and SRAM

        input logic FIFO_pop_valid_in [Banks-1:0],
        // input logic SRAM_REB [Banks-1:0], 
        // input logic SRAM_WEB [Banks-1:0],  

        // output logic [GID_bit-1:0] Read_address_before_add [Banks-1:0],
        output logic FIFO_pop_ready_out [Banks-1:0],

        output logic last_input_done_out [Banks-1:0],


        input wire [SRAM_bits-1:0] SRAM_data_in_to_Adder [Banks-1:0],
        // output wire [SRAM_bits-1:0] FIFO_data_before_add [Banks-1:0],

        output wire [SRAM_bits-1:0] FIFO_to_SRAM_data [Banks-1:0],
        output wire [GID_bit-1:0] Read_address_before_add [Banks-1:0],
        output wire [GID_bit-1:0] Write_address_after_add [Banks-1:0]

    );

    logic [(3 * precision) - 1:0] dL_dcolor_out [num_pixels-1:0];
    logic [precision - 1:0] dL_ddepth_out [num_pixels-1:0];
    logic [(2 * precision) - 1:0] dL_dmean2D_out [num_pixels-1:0];
    logic [(4 * precision) - 1:0] dL_dconic_out [num_pixels-1:0];
    logic [precision - 1:0] dL_dopacity_out [num_pixels-1:0];
    logic [GID_bit-1:0] gaussian_id_out [num_pixels-1:0];

    logic [(3 * precision) - 1:0] dL_dcolor_in_to_grad_merge [num_pixels-1:0];
    logic [precision - 1:0] dL_ddepth_in_to_grad_merge [num_pixels-1:0];
    logic [(2 * precision) - 1:0] dL_dmean2D_in_to_grad_merge [num_pixels-1:0];
    logic [(4 * precision) - 1:0] dL_dconic_in_to_grad_merge [num_pixels-1:0];
    logic [precision - 1:0] dL_dopacity_in_to_grad_merge [num_pixels-1:0];

    logic [GID_bit-1:0] gaussian_id_in_to_grad_merge [num_pixels-1:0];
    logic GID_valid_in_to_grad_merge [num_pixels-1:0];
    logic last_input_to_grad_merge [num_pixels-1:0];



    logic last_input_done [num_pixels-1:0];

    logic gradient_valid_out [num_pixels-1:0];

    logic stall_to_controller_from_rasterizer [num_pixels-1:0];
    logic stall_to_controller_from_grad_merge;
    logic stall_to_rasterizer [num_pixels-1:0];


    genvar i;
    generate
        for (i = 0; i < num_pixels; i++) begin
            assign stall_to_controller[i] = stall_to_controller_from_rasterizer[i] || stall_to_controller_from_grad_merge;
            assign stall_to_rasterizer[i] = stall_backpressure || stall_to_controller_from_grad_merge;

            assign gaussian_id_in_to_grad_merge[i] = gaussian_id_out[i];
            assign dL_dcolor_in_to_grad_merge[i] = dL_dcolor_out[i];
            assign dL_ddepth_in_to_grad_merge[i] = dL_ddepth_out[i];
            assign dL_dmean2D_in_to_grad_merge[i] = dL_dmean2D_out[i];
            assign dL_dconic_in_to_grad_merge[i] = dL_dconic_out[i];
            assign dL_dopacity_in_to_grad_merge[i] = dL_dopacity_out[i];
            assign GID_valid_in_to_grad_merge[i] = gradient_valid_out[i];
            assign last_input_to_grad_merge[i] = last_input_done[i];
        end
    endgenerate


    // Backward Rasterizer Part
    Backward_Rasterizer_group_unit #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .exponent_bit(exponent_bit),
        .mantissa_bit(mantissa_bit),
        .precision(precision),
        .gaussian_inputs(gaussian_inputs),
        .num_pixels(num_pixels),
        .GID_bit(GID_bit)
    )
    Backward_Rasterizer_group_unit_inst (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),

        .W(W),
        .H(H),

        .start(start),
        .dL_dpixel(dL_dpixel),
        .dL_dpixel_depth(dL_dpixel_depth),
        .T_first(T_first),

        .block_id(block_id),
        .pixel_id(pixel_id),

        .stall_backpressure(stall_to_rasterizer),

        .last_input(last_input),

        .mean2D(mean2D),
        .conic_opacity(conic_opacity),

        .gaussian_id_in(gaussian_id_in),
        .gaussian_color(gaussian_color),
        .gaussian_depth(gaussian_depth),

        .dL_dcolor_out(dL_dcolor_out),
        .dL_ddepth_out(dL_ddepth_out),
        .dL_dmean2D_out(dL_dmean2D_out),
        .dL_dconic_out(dL_dconic_out),
        .dL_dopacity_out(dL_dopacity_out),
        .gaussian_id_out(gaussian_id_out),

        .gradient_valid_out(gradient_valid_out),
        .stall_to_controller(stall_to_controller_from_rasterizer),
        .last_input_done(last_input_done)
    );


    // Backward Grad merge Part
    Gradient_merge_unit_by_majority_with_add #(
    .BLOCK_SIZE(BLOCK_SIZE),
    .exponent_bit(exponent_bit),
    .precision(precision),
    .num_pixels(num_pixels),
    .GID_bit(GID_bit),
    .First_FIFO_depth(First_FIFO_depth),
    .Last_FIFO_depth(Last_FIFO_depth),
    .Banks(Banks)
    )

    Gradient_merge_unit_by_majority_with_add_inst (
        .clk(clk),
        .rst_n(rst_n),

        .gaussian_id_in(gaussian_id_in_to_grad_merge),
        .dL_dcolor_in(dL_dcolor_in_to_grad_merge),
        .dL_ddepth_in(dL_ddepth_in_to_grad_merge),
        .dL_dmean2D_in(dL_dmean2D_in_to_grad_merge),
        .dL_dconic_in(dL_dconic_in_to_grad_merge),
        .dL_dopacity_in(dL_dopacity_in_to_grad_merge),

        .GID_valid_in(GID_valid_in_to_grad_merge),
        .last_input_done_in(last_input_to_grad_merge),

        .stall_backpressure(stall_backpressure),


        .FIFO_pop_valid_in(FIFO_pop_valid_in),    

        // Output
        .FIFO_pop_ready_out(FIFO_pop_ready_out),

        .FIFO_GID_out(Read_address_before_add),
        // .FIFO_pop_out(FIFO_data_before_add),
        
        .stall_to_controller(stall_to_controller_from_grad_merge),
        .last_input_done_out(last_input_done_out),


        .SRAM_data_in_to_Adder(SRAM_data_in_to_Adder),

        // .FIFO_data_before_add_FF(FIFO_data_before_add_FF),
        .FIFO_to_SRAM_data(FIFO_to_SRAM_data),
        
        // .Read_address_before_add(Read_address_before_add)
        .Write_address_after_add(Write_address_after_add)
    );

endmodule

