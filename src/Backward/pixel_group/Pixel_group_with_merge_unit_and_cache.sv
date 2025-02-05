module Pixel_group_with_merge_unit_and_cache
    # (
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter precision = 16,
        parameter mantissa_bit = 7,
        parameter num_pixels = 16,
        parameter GID_bit = 24,
        parameter First_FIFO_depth = 4,
        parameter Last_FIFO_depth = 16,
        parameter Banks = 16,
        parameter SRAM_bits = 11 * precision,
        parameter Bank_depth = 2048
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

        output wire stall_to_controller,

        input wire last_input_done_in [num_pixels-1:0],


        // Testbench의 컨트롤 신호 (원래는 Controller에서 처리)
        input wire FIFO_pop_valid_in [Banks-1:0],
        input wire SRAM_REB [Banks-1:0], 
        input wire SRAM_WEB [Banks-1:0],  


        output wire [GID_bit-1:0] Read_address_before_add [Banks-1:0],
        output wire FIFO_pop_ready_out [Banks-1:0],

        output wire last_input_done_out [Banks-1:0]

        
    );
    // synopsys template


    // FF Register Declaration
    reg [GID_bit-1:0] Write_address_after_add_FF [Banks-1:0];

    reg [SRAM_bits-1:0] FIFO_data_before_add_FF [Banks-1:0];

    reg SRAM_REB_cycle_before_FF [Banks-1:0];



    // Comb Register Declaration



    // Wire Declaration
    wire [SRAM_bits-1:0] FIFO_to_SRAM_data [Banks-1:0];
    wire [SRAM_bits-1:0] FIFO_data_before_add [Banks-1:0];
    wire [SRAM_bits-1:0] SRAM_data_out [Banks-1:0];

    wire [SRAM_bits-1:0] SRAM_data_out_to_Adder [Banks-1:0];

    wire [7:0] status_inst [Banks-1:0][1:11];




    Gradient_merge_unit_by_majority #(
    .BLOCK_SIZE(BLOCK_SIZE),
    .exponent_bit(exponent_bit),
    .precision(precision),
    .num_pixels(num_pixels),
    .GID_bit(GID_bit),
    .First_FIFO_depth(First_FIFO_depth),
    .Last_FIFO_depth(Last_FIFO_depth),
    .Banks(Banks)
    )

    Gradient_merge_unit_by_majority_inst (
        .clk(clk),
        .rst_n(rst_n),

        .gaussian_id_in(gaussian_id_in),
        .dL_dcolor_in(dL_dcolor_in),
        .dL_ddepth_in(dL_ddepth_in),
        .dL_dmean2D_in(dL_dmean2D_in),
        .dL_dconic_in(dL_dconic_in),
        .dL_dopacity_in(dL_dopacity_in),

        .GID_valid_in(GID_valid_in),
        .last_input_done_in(last_input_done_in),

        .stall_backpressure(stall_backpressure),



        .FIFO_pop_valid_in(FIFO_pop_valid_in),    

        // Output
        .FIFO_pop_ready_out(FIFO_pop_ready_out),

        .FIFO_GID_out(Read_address_before_add),
        .FIFO_pop_out(FIFO_data_before_add),
        
        .stall_to_controller(stall_to_controller),
        .last_input_done_out(last_input_done_out)
    );




    genvar i;
    generate
        for (i = 0; i < Banks; i = i + 1) begin : add_and_write_to_SRAM

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dcolor_R_adder_inst (
                .a(FIFO_data_before_add_FF[i][(11 * precision) - 1: 10 * precision]),
                .b(SRAM_data_out_to_Adder[i][(11 * precision) - 1: 10 * precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data[i][(11 * precision) - 1: 10 * precision]),
                .status(status_inst[i][1])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dcolor_G_adder_inst (
                .a(FIFO_data_before_add_FF[i][(10 * precision) - 1: 9*precision]),
                .b(SRAM_data_out_to_Adder[i][(10 * precision) - 1: 9*precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data[i][(10 * precision) - 1: 9*precision]),
                .status(status_inst[i][2])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dcolor_B_adder_inst (
                .a(FIFO_data_before_add_FF[i][(9 * precision) - 1: 8*precision]),
                .b(SRAM_data_out_to_Adder[i][(9 * precision) - 1: 8*precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data[i][(9 * precision) - 1: 8*precision]),
                .status(status_inst[i][3])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_ddepth_adder_inst (
                .a(FIFO_data_before_add_FF[i][(8 * precision) - 1: 7*precision]),
                .b(SRAM_data_out_to_Adder[i][(8 * precision) - 1: 7*precision]),
                .rnd(3'b0),
                .z(FIFO_to_SRAM_data[i][(8 * precision) - 1: 7*precision]),
                .status(status_inst[i][4])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_mean2D_x_adder_inst (
                .a(FIFO_data_before_add_FF[i][(7 * precision) - 1: 6*precision]),
                .b(SRAM_data_out_to_Adder[i][(7 * precision) - 1: 6*precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data[i][(7 * precision) - 1: 6*precision]),
                .status(status_inst[i][5])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_mean2D_y_adder_inst (
                .a(FIFO_data_before_add_FF[i][(6 * precision) - 1: 5*precision]),
                .b(SRAM_data_out_to_Adder[i][(6 * precision) - 1: 5*precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data[i][(6 * precision) - 1: 5*precision]),
                .status(status_inst[i][6])
            );


            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_x_adder_inst (
                .a(FIFO_data_before_add_FF[i][(5 * precision) - 1: 4*precision]),
                .b(SRAM_data_out_to_Adder[i][(5 * precision) - 1: 4*precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data[i][(5 * precision) - 1: 4*precision]),
                .status(status_inst[i][7])
            );            


            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_y_adder_inst (
                .a(FIFO_data_before_add_FF[i][(4 * precision) - 1: 3*precision]),
                .b(SRAM_data_out_to_Adder[i][(4 * precision) - 1: 3*precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data[i][(4 * precision) - 1: 3*precision]),
                .status(status_inst[i][8])
            );


            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_z_adder_inst (
                .a(FIFO_data_before_add_FF[i][(3 * precision) - 1: 2*precision]),
                .b(SRAM_data_out_to_Adder[i][(3 * precision) - 1: 2*precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data[i][(3 * precision) - 1: 2*precision]),
                .status(status_inst[i][9])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_w_adder_inst (
                .a(FIFO_data_before_add_FF[i][(2 * precision) - 1: precision]),
                .b(SRAM_data_out_to_Adder[i][(2 * precision) - 1: precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data[i][(2 * precision) - 1: precision]),
                .status(status_inst[i][10])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dopacity_adder_inst (
                .a(FIFO_data_before_add_FF[i][(precision) - 1: 0]),
                .b(SRAM_data_out_to_Adder[i][(precision) - 1: 0]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data[i][(precision) - 1: 0]),
                .status(status_inst[i][11])
            );


            dp_ram #(
                .N(SRAM_bits),
                .W(Bank_depth)
            )
            SRAM_inst (
                .clk(clk),
                .rst_n(rst_n),

                .AA((Write_address_after_add_FF[i] >> $clog2(Banks))), // Write Address
                .D(FIFO_to_SRAM_data[i]), // Write Data
                .WEB(SRAM_WEB[i]), // Write Enable Low 
                .AB((Read_address_before_add[i] >> $clog2(Banks))), // Read Address
                .REB(SRAM_REB[i]), // Read Enable Low
                .Q(SRAM_data_out[i]) // Read Data Out
            );

            assign SRAM_data_out_to_Adder[i] = !SRAM_REB_cycle_before_FF[i] ? SRAM_data_out[i] : 'h0;
        end
    endgenerate



    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int j = 0; j < Banks; j = j + 1) begin
                Write_address_after_add_FF[j] <= '0;
                FIFO_data_before_add_FF[j] <= '0;
                SRAM_REB_cycle_before_FF[j] <= '0;
            end
        end
        else begin
            for (int j = 0; j < Banks; j = j + 1) begin
                if (FIFO_pop_valid_in[j] && FIFO_pop_ready_out[j]) begin
                    Write_address_after_add_FF[j] <= Read_address_before_add[j];
                    FIFO_data_before_add_FF[j] <= FIFO_data_before_add[j];
                end
                
                // FIFO is empty or handshake is not happened
                else begin 
                    Write_address_after_add_FF[j] <= 'h0;
                    FIFO_data_before_add_FF[j] <= 'h0;
                end

                SRAM_REB_cycle_before_FF[j] <= SRAM_REB[j];
            end
        end
    end

endmodule