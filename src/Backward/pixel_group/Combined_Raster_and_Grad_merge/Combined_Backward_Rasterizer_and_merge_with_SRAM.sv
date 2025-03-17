module Combined_Backward_Rasterizer_and_merge_with_SRAM #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 4, // in one pixel unit, gaussians
    parameter num_pixels = 16, // number of pixel units
    // parameter GID_bit = 24,
    parameter GID_bit = 16,
    parameter First_FIFO_depth = 4,
    parameter Last_FIFO_depth = 16,    
    parameter Banks = 16,
    parameter SRAM_bits = 11 * precision,
    // parameter Bank_depth = 128,
    parameter Bank_depth = 2048,
    parameter Encoder_outs = 4
    )
    (
        // Input to Backward Rasterizer Unit
        input logic clk,
        input logic rst_n,
        input logic i_valid [(gaussian_inputs * num_pixels) - 1:0],

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

        output logic stall_to_controller_from_rasterizer [num_pixels-1:0],

        // Input and Output from Gradient Merge and SRAM

        input logic FIFO_pop_valid_in [Banks-1:0],
        input logic SRAM_REB [Banks-1:0], 
        input logic SRAM_WEB [Banks-1:0],  

        output logic [GID_bit-1:0] Read_address_before_add [Banks-1:0],
        output logic FIFO_pop_ready_out [Banks-1:0],

        output logic last_input_done_out [Banks-1:0]
    );

    logic [SRAM_bits-1:0] SRAM_data_in_to_Adder [Banks-1:0];
    logic [SRAM_bits-1:0] FIFO_data_before_add [Banks-1:0];
    logic [SRAM_bits-1:0] FIFO_to_SRAM_data [Banks-1:0];

    // logic [SRAM_bits-1:0] SRAM_data_to_Adder [Banks-1:0];


    logic last_input_done [num_pixels-1:0];

    logic gradient_valid_out [num_pixels-1:0];

    // logic stall_to_controller_from_rasterizer [num_pixels-1:0];
    logic stall_to_controller_from_grad_merge;
    logic stall_to_rasterizer [num_pixels-1:0];


    logic [GID_bit-1:0] Write_address_after_add [Banks-1:0];
    reg SRAM_REB_cycle_before_FF [Banks-1:0];

    logic [SRAM_bits-1:0] SRAM_data_out [Banks-1:0];

    // Backward Rasterizer + Grad merge + Adder
    Combined_Backward_Rasterizer_and_merge #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .exponent_bit(exponent_bit),
        .mantissa_bit(mantissa_bit),
        .precision(precision),
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .gaussian_inputs(gaussian_inputs),
        .First_FIFO_depth(First_FIFO_depth),
        .Last_FIFO_depth(Last_FIFO_depth),
        .Banks(Banks),
        .SRAM_bits(SRAM_bits),
        .Encoder_outs(Encoder_outs)
    )
    Combined_Backward_Rasterizer_and_merge_inst (
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

        .stall_backpressure(stall_backpressure),

        .last_input(last_input),

        .mean2D(mean2D),
        .conic_opacity(conic_opacity),

        .gaussian_id_in(gaussian_id_in),
        .gaussian_color(gaussian_color),
        .gaussian_depth(gaussian_depth),

        .stall_to_controller(stall_to_controller_from_rasterizer),


        // SRAM Control signals
        .FIFO_pop_valid_in(FIFO_pop_valid_in),
        // .SRAM_REB(SRAM_REB),
        // .SRAM_WEB(SRAM_WEB),

        .FIFO_pop_ready_out(FIFO_pop_ready_out),

        .last_input_done_out(last_input_done_out),

        .SRAM_data_in_to_Adder(SRAM_data_in_to_Adder),
        // .FIFO_data_before_add_FF(FIFO_data_before_add),

        .FIFO_to_SRAM_data(FIFO_to_SRAM_data),
        .Read_address_before_add(Read_address_before_add),


        .Write_address_after_add(Write_address_after_add)
    );

    genvar k;
    generate 
        for (k = 0; k < Banks; k++) begin : SRAM_Bank_inst
            dp_ram #(
                .N(SRAM_bits),
                .W(Bank_depth)
            )
            SRAM_inst (
                .clk(clk),
                .rst_n(rst_n),

                .AA((Write_address_after_add[k] >> $clog2(Banks))), // Write Address
                .D(FIFO_to_SRAM_data[k]), // Write Data
                .WEB(SRAM_WEB[k]), // Write Enable Low 
                .AB((Read_address_before_add[k] >> $clog2(Banks))), // Read Address
                .REB(SRAM_REB[k]), // Read Enable Low
                .Q(SRAM_data_out[k]) // Read Data Out
            );
            
            assign SRAM_data_in_to_Adder[k] = !SRAM_REB_cycle_before_FF[k] ? SRAM_data_out[k] : 'h0;
        end
    endgenerate
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int j = 0; j < Banks; j = j + 1) begin
                SRAM_REB_cycle_before_FF[j] <= '0;
            end
        end
        else begin
            for (int j = 0; j < Banks; j = j + 1) begin
                SRAM_REB_cycle_before_FF[j] <= SRAM_REB[j];
            end
        end
    end




endmodule
