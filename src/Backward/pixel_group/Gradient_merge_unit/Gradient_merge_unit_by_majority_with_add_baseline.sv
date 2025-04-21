module Gradient_merge_unit_by_majority_with_add_baseline #(
    parameter BLOCK_SIZE = 16, 
    parameter exponent_bit = 8, 
    parameter precision = 16, 
    parameter mantissa_bit = 7, 
    parameter num_pixels = 16, 
    parameter GID_bit = 11,
    parameter First_FIFO_depth = 4,
    parameter Last_FIFO_depth = 4,
    parameter encoder_and_fifo_data_size = 11 * precision + GID_bit,
    parameter FIFO_to_SRAM_data_size = 11 * precision,
    parameter Banks = 16,
    parameter Encoder_outs = 4
    ) 

    //Input과 Output 모두 Wired logic
    (
    input logic clk,
    input logic rst_n,

    // Input From Gradient Calculator
    input logic [GID_bit-1:0]       gaussian_id_in         [num_pixels-1:0],
    input logic [(3*precision)-1:0] dL_dcolor_in           [num_pixels-1:0],
    input logic [precision-1:0]     dL_ddepth_in           [num_pixels-1:0],
    input logic [(2*precision)-1:0] dL_dmean2D_in          [num_pixels-1:0],
    input logic [(4*precision)-1:0] dL_dconic_in           [num_pixels-1:0],
    input logic [precision-1:0]     dL_dopacity_in         [num_pixels-1:0],

    input logic                     GID_valid_in           [num_pixels-1:0], // gradient_valid_out in Backward_Rasterizer_unit
    input logic                     last_input_done_in     [num_pixels-1:0],

    input logic                     stall_backpressure,


    // Input From Controller
    input logic                     FIFO_pop_valid_in  [Banks-1:0], // 컨트롤러 입력

    // FIFO Output은 Push/Pop으로 cycle 수 감소해서 처리하도록

    // Output To Read SRAM GID
    // output logic                    GID_valid_out       [Banks-1:0], 


    // 이거 3개 그거해야됨

    // output logic                    FIFO_pop_ready_out          [Banks-1:0], // Wired Logic
    output wire [GID_bit-1:0]      FIFO_GID_out        [Banks-1:0], // == Read_address_before_add
    // output wire [FIFO_to_SRAM_data_size-1:0] FIFO_to_SRAM_data [Banks-1:0],

    output wire                    FIFO_pop_ready_out          [Banks-1:0], // Wired Logic
    // output reg [GID_bit-1:0]       Read_address_before_add      [Banks-1:0], // == Read_address_before_add
    output reg [FIFO_to_SRAM_data_size-1:0] FIFO_to_SRAM_data[Banks-1:0],
    output wire last_input_done_out [Banks-1:0], // Wire


    // last_Input_done 컨트롤을 위한
    output wire last_input_done_and_data_zero [Banks-1:0],

    // output logic [GID_bit-1:0]      Read_address_before_add        [Banks-1:0],
    // output logic [FIFO_to_SRAM_data_size-1:0] FIFO_pop_out       [Banks-1:0],


    // // Control Signal
    output logic stall_to_controller,
    // output logic last_input_done_out [Banks-1:0], // Wire



    // Data from SRAM Cache
    input wire [FIFO_to_SRAM_data_size-1:0] SRAM_data_in_to_Adder [Banks-1:0], 

    // output reg [FIFO_to_SRAM_data_size-1:0] FIFO_data_before_add_FF [Banks-1:0],
    // output reg [FIFO_to_SRAM_data_size-1:0] FIFO_to_SRAM_data_out [Banks-1:0],
    


    // output reg  [GID_bit-1:0] Read_address_before_add [Banks-1:0],

    output reg  [GID_bit-1:0] Write_address_after_add [Banks-1:0]

    );
    // synopsys template




    ///////////////////////////////////////////
    //////////// Wire Declare ///////////////
    ///////////////////////////////////////////
    

    logic [encoder_and_fifo_data_size-1:0]  encoder_data_in         [Banks * num_pixels-1:0];
    logic                                   encoder_request_in   [Banks * num_pixels-1:0];
    logic                                   encoder_last_input_done_in   [Banks * num_pixels-1:0];
    
    logic                                   last_input_done_grant_out   [Banks * num_pixels-1:0];

    logic fifo_1x_full [Banks-1:0];
    logic fifo_1x_empty [Banks-1:0];

    // logic [encoder_and_fifo_data_size-1:0] encoder_to_fifo_data_out [num_pixels-1:0];
    // logic [encoder_and_fifo_data_size-1:0] encoder_to_fifo_data_out [Banks * Encoder_outs-1:0];

    // logic encoder_to_fifo_valid_out [num_pixels-1:0];

    logic encoder_to_1x_fifo_valid_out [Banks-1:0];
    logic [encoder_and_fifo_data_size-1:0] encoder_to_1x_fifo_data_out [Banks-1:0];

    logic stall_from_encoder [Banks-1:0];

    logic src_grant_out [num_pixels * Banks-1:0];
    // logic src_grant_out [Encoder_outs * Banks-1:0];

    logic [ (encoder_and_fifo_data_size + 1)-1:0] fifo_1x_pop_data   [Banks-1:0];    
    

    logic last_input_done_from_encoder_out [Banks-1:0];
    

    
    
    // logic [ ( encoder_and_fifo_data_size)-1:0] serializer_data_in_from_1x_fifo [Encoder_outs * Banks-1:0]; // last input done은 따로 빼는걸로
    // logic serializer_last_input_done_from_4x_fifo [Encoder_outs * Banks-1:0];
    // logic serializer_valid_from_4x_fifo [Encoder_outs * Banks-1:0];

    wire [FIFO_to_SRAM_data_size-1:0] FIFO_pop_out       [Banks-1:0];

    wire [FIFO_to_SRAM_data_size-1:0] FIFO_to_SRAM_data_wire [Banks-1:0];

    logic [7:0] status_inst [Banks-1:0][1:11];
    // before encoder (수정용)

    logic [3*precision-1:0]     dL_dcolor_before_encoder    [num_pixels - 1:0];
    logic [precision-1:0]       dL_ddepth_before_encoder    [num_pixels - 1:0];
    logic [(2*precision)-1:0]   dL_dmean2D_before_encoder   [num_pixels - 1:0];
    logic [(4*precision)-1:0]   dL_dconic_before_encoder    [num_pixels - 1:0];
    logic [precision-1:0]       dL_dopacity_before_encoder  [num_pixels - 1:0];

    logic [GID_bit-1:0]         gaussian_id_before_encoder    [num_pixels-1:0];

    logic                       GID_valid_before_encoder    [num_pixels-1:0];
    logic                       last_input_done_before_encoder [num_pixels-1:0];


    

    logic [(encoder_and_fifo_data_size + 1)-1:0] encoder_to_fifo_1x_push_in [Banks-1:0];
    logic encoder_to_fifo_1x_push_valid_in [Banks-1:0];
    
    
    reg [FIFO_to_SRAM_data_size-1:0] FIFO_data_before_add_FF [Banks-1:0];
    reg [GID_bit-1:0] Write_address_after_add_temp1 [Banks-1:0];
    


    
    //////////////////////////////////////
    ///////// Combinational Register //////
    //////////////////////////////////////

    

    logic stall_from_encoder_comb;
    logic stall_from_1x_fifo_comb;

    
    logic last_input_done_to_1x_fifo_valid_comb [Banks-1:0];


    // logic                       valid_gradient_to_pass_encoder [num_pixels-1:0];

    logic                       GID_valid_to_encoder_reg [num_pixels-1:0];
    
    

    always_comb begin
        stall_from_encoder_comb = 0;
        stall_from_1x_fifo_comb = 0;
        

        for (int i = 0; i < Banks; i++) begin
            
            stall_from_encoder_comb = stall_from_encoder_comb || stall_from_encoder[i];
            
            

            last_input_done_to_1x_fifo_valid_comb[i] = 0;

            last_input_done_to_1x_fifo_valid_comb[i] = last_input_done_to_1x_fifo_valid_comb[i] || last_input_done_from_encoder_out[i];
        end
    
    end

    assign stall_to_controller = stall_from_encoder_comb || stall_backpressure;


    genvar k, m, n; // k : Bank, m : Pixel, n : Encoder_outs
    generate
        for (k = 0; k < Banks; k = k + 1) begin : aribtration_and_fifo

            // Problem: The signals are declared as 2D arrays [stage][pixel] but we're trying to do bit selection
            // which isn't valid for 2D arrays. We need to concatenate the full signals without bit selection.
            for (m = 0; m < num_pixels; m = m + 1) begin : encoder_data_in_concatenation

                assign encoder_data_in[k * num_pixels + m] = (gaussian_id_before_encoder[m][$clog2(Banks)-1:0] == k) ? 

                {
                    dL_dcolor_before_encoder[m],
                    dL_ddepth_before_encoder[m],
                    dL_dmean2D_before_encoder[m],
                    dL_dconic_before_encoder[m],
                    dL_dopacity_before_encoder[m],

                    gaussian_id_before_encoder[m]
                } : 'h0;

                assign encoder_request_in[k * num_pixels + m] = ((gaussian_id_before_encoder[m][$clog2(Banks)-1:0] == k) 
                                                            && GID_valid_before_encoder[m]);

                assign encoder_last_input_done_in[k * num_pixels + m] = ((gaussian_id_before_encoder[m][$clog2(Banks)-1:0] == k) 
                                                            && last_input_done_before_encoder[m]);
            end

            
            // Priority Encoder, 4x FIFO, Serializer, FIFO

            priority_encoder_single_out #(
                .INPUTS(num_pixels),
                // .OUTPUTS(Encoder_outs),
                .DATA_SIZE(encoder_and_fifo_data_size)
            )
            priority_encoder_inst (
                .clk(clk),
                .rst_n(rst_n),

                // .src_request_i(encoder_request_in[k * Banks +: Banks]),
                .src_request_i(encoder_request_in[k * num_pixels +: num_pixels]),
                .src_grant_o(src_grant_out[k * num_pixels +: num_pixels]),
                .src_data_i(encoder_data_in[k * num_pixels +: num_pixels]), 


                .last_input_done_i(encoder_last_input_done_in[k * num_pixels +: num_pixels]),

                .last_input_done_grant_o(last_input_done_grant_out[k * num_pixels +: num_pixels]),


                .last_input_done_o(last_input_done_from_encoder_out[k]),

                .dst_valid_o(encoder_to_1x_fifo_valid_out[k]), // 다음 단에 Data 전송
                .dst_data_o(encoder_to_1x_fifo_data_out[k]), // 각 포트에 Valid한 데이터인지 기입

                .stall_backpressure(stall_backpressure || (fifo_1x_full[k])),
                .stall_from_encoder(stall_from_encoder[k]),

                // .dst_ready_i(!fifo_4x_full[k])
                .dst_ready_i(!fifo_1x_full[k])
            );


            push_pop_FIFO #(
                .FIFO_depth(Last_FIFO_depth),
                .input_data_width(encoder_and_fifo_data_size + 1),
                .output_data_width(encoder_and_fifo_data_size + 1)
            )
            FIFO_1x_inst (
                .clk(clk),
                .rst_n(rst_n),

                // .push_data_in(serializer_to_fifo_1x_push_in[k]),
                // .push_valid_in(serializer_to_fifo_1x_push_valid_in[k]),

                .push_data_in(encoder_to_fifo_1x_push_in[k]),
                .push_valid_in(encoder_to_fifo_1x_push_valid_in[k]),

                .pop_valid_in(FIFO_pop_valid_in[k]), 
                .pop_data_out(fifo_1x_pop_data[k]),

                .full_out(fifo_1x_full[k]), // stall_from_fifo
                .empty_out(fifo_1x_empty[k])
            );



            assign FIFO_pop_ready_out[k] = !fifo_1x_empty[k];
            assign FIFO_GID_out[k] = fifo_1x_pop_data[k][GID_bit-1:0];
            assign FIFO_pop_out[k] = fifo_1x_pop_data[k][encoder_and_fifo_data_size-1:GID_bit];
            assign last_input_done_out[k] = fifo_1x_pop_data[k][encoder_and_fifo_data_size];

            assign last_input_done_and_data_zero[k] = (last_input_done_out[k] && (FIFO_pop_out[k] == 'h0));



            // R G B depth mean2Dx mean2Dy conic_x conic_y conic_z conic_w opacity


            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dcolor_R_adder_inst (
                .a(FIFO_data_before_add_FF[k][(11 * precision) - 1: 10 * precision]),
                .b(SRAM_data_in_to_Adder[k][(11 * precision) - 1: 10 * precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data_wire[k][(11 * precision) - 1: 10 * precision]),
                .status(status_inst[k][1])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dcolor_G_adder_inst (
                .a(FIFO_data_before_add_FF[k][(10 * precision) - 1: 9 * precision]),
                .b(SRAM_data_in_to_Adder[k][(10 * precision) - 1: 9 * precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data_wire[k][(10 * precision) - 1: 9 * precision]),
                .status(status_inst[k][2])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dcolor_B_adder_inst (
                .a(FIFO_data_before_add_FF[k][(9 * precision) - 1: 8 *precision]),
                .b(SRAM_data_in_to_Adder[k][(9 * precision) - 1: 8 * precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data_wire[k][(9 * precision) - 1: 8 * precision]),
                .status(status_inst[k][3])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_ddepth_adder_inst (
                .a(FIFO_data_before_add_FF[k][(8 * precision) - 1: 7 * precision]),
                .b(SRAM_data_in_to_Adder[k][(8 * precision) - 1: 7 * precision]),
                .rnd(3'b0),
                .z(FIFO_to_SRAM_data_wire[k][(8 * precision) - 1: 7 * precision]),
                .status(status_inst[k][4])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_mean2D_x_adder_inst (
                .a(FIFO_data_before_add_FF[k][(7 * precision) - 1: 6 * precision]),
                .b(SRAM_data_in_to_Adder[k][(7 * precision) - 1: 6 * precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data_wire[k][(7 * precision) - 1: 6 * precision]),
                .status(status_inst[k][5])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_mean2D_y_adder_inst (
                .a(FIFO_data_before_add_FF[k][(6 * precision) - 1: 5 * precision]),
                .b(SRAM_data_in_to_Adder[k][(6 * precision) - 1: 5 * precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data_wire[k][(6 * precision) - 1: 5 * precision]),
                .status(status_inst[k][6])
            );


            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_x_adder_inst (
                .a(FIFO_data_before_add_FF[k][(5 * precision) - 1: 4*precision]),
                .b(SRAM_data_in_to_Adder[k][(5 * precision) - 1: 4*precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data_wire[k][(5 * precision) - 1: 4*precision]),
                .status(status_inst[k][7])
            );            


            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_y_adder_inst (
                .a(FIFO_data_before_add_FF[k][(4 * precision) - 1: 3*precision]),
                .b(SRAM_data_in_to_Adder[k][(4 * precision) - 1: 3*precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data_wire[k][(4 * precision) - 1: 3*precision]),
                .status(status_inst[k][8])
            );


            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_z_adder_inst (
                .a(FIFO_data_before_add_FF[k][(3 * precision) - 1: 2 * precision]),
                .b(SRAM_data_in_to_Adder[k][(3 * precision) - 1: 2 * precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data_wire[k][(3 * precision) - 1: 2 * precision]),
                .status(status_inst[k][9])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dconic_w_adder_inst (
                .a(FIFO_data_before_add_FF[k][(2 * precision) - 1: precision]),
                .b(SRAM_data_in_to_Adder[k][(2 * precision) - 1: precision]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data_wire[k][(2 * precision) - 1: precision]),
                .status(status_inst[k][10])
            );

            DW_fp_add #(mantissa_bit, exponent_bit, 0)
            majority_dL_dopacity_adder_inst (
                .a(FIFO_data_before_add_FF[k][(precision) - 1: 0]),
                .b(SRAM_data_in_to_Adder[k][(precision) - 1: 0]),
                .rnd(3'b000),
                .z(FIFO_to_SRAM_data_wire[k][(precision) - 1: 0]),
                .status(status_inst[k][11])
            );

        end
    endgenerate


    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < num_pixels; i++) begin

                dL_dcolor_before_encoder[i] <= '0;
                dL_ddepth_before_encoder[i] <= '0;
                dL_dmean2D_before_encoder[i] <= '0;
                dL_dconic_before_encoder[i] <= '0;
                dL_dopacity_before_encoder[i] <= '0;
                gaussian_id_before_encoder[i] <= '0;
                GID_valid_before_encoder[i] <= '0;
                last_input_done_before_encoder[i] <= '0;


            end

            for (int j = 0; j < Banks; j++) begin
                FIFO_data_before_add_FF[j] <= 'h0;
                Write_address_after_add[j] <= 'h0;
                Write_address_after_add_temp1[j] <= 'h0;
                FIFO_to_SRAM_data[j] <= 'h0;
            end
        end

        else begin

            for (int j = 0; j < Banks; j++) begin

                for (int i = 0; i < num_pixels; i++) begin

                    if (encoder_request_in[j * num_pixels + i] && src_grant_out[j * num_pixels + i]) begin
                        GID_valid_before_encoder[i] <= 1'b0;
                    end      

                    if (encoder_last_input_done_in[j * num_pixels + i] && last_input_done_grant_out[j * num_pixels + i]) begin
                        last_input_done_before_encoder[i] <= 1'b0;
                    end        
                end
                
                FIFO_to_SRAM_data[j] <= FIFO_to_SRAM_data_wire[j];
                
                Write_address_after_add[j] <= Write_address_after_add_temp1[j];


                // SRAM Read/Write
                if (FIFO_pop_valid_in[j] && FIFO_pop_ready_out[j]) begin
                    Write_address_after_add_temp1[j] <= FIFO_GID_out[j];                    
                    FIFO_data_before_add_FF[j] <= FIFO_pop_out[j];
                end
                
                else begin
                    // 변경사항
                    Write_address_after_add_temp1[j] <= 'h0; 

                    FIFO_data_before_add_FF[j] <= 'h0;
                end


                if (!fifo_1x_full[j]) begin
                    encoder_to_fifo_1x_push_in[j] <= {last_input_done_from_encoder_out[j], encoder_to_1x_fifo_data_out[j] };
                    encoder_to_fifo_1x_push_valid_in[j] <= encoder_to_1x_fifo_valid_out[j] || last_input_done_to_1x_fifo_valid_comb[j];
                end

            end

            // stall to controller는 Encoder 이전 단계에서 적용 그 후 단계는 각각 FULL /EMPTY 신호로 각자 제어
            if (!stall_to_controller) begin

                for (int i = 0; i < num_pixels; i++) begin
                    dL_dcolor_before_encoder[i] <= dL_dcolor_in[i];
                    dL_ddepth_before_encoder[i] <= dL_ddepth_in[i];
                    dL_dmean2D_before_encoder[i] <= dL_dmean2D_in[i];
                    dL_dconic_before_encoder[i] <= dL_dconic_in[i];
                    dL_dopacity_before_encoder[i] <= dL_dopacity_in[i];
                    gaussian_id_before_encoder[i] <= gaussian_id_in[i];
                    GID_valid_before_encoder[i] <= GID_valid_in[i];
                    last_input_done_before_encoder[i] <= last_input_done_in[i];

                end
            end
        end
    end




endmodule