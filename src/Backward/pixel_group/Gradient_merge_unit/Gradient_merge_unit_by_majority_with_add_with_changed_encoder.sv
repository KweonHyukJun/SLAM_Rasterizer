module Gradient_merge_unit_by_majority_with_add_with_changed_encoder #(
    parameter BLOCK_SIZE = 16, 
    parameter exponent_bit = 8, 
    parameter precision = 16, 
    parameter mantissa_bit = 7, 
    parameter num_pixels = 16, 
    parameter GID_bit = 12,
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


    localparam majority_adder_stages = $clog2(num_pixels) + 1;
    // localparam encoder_and_fifo_data_size = 11 * precision + GID_bit;


    ///////////////////////////////////////////
    //////////// Wire Declare ///////////////
    ///////////////////////////////////////////
    
    logic is_majority_gid [num_pixels-1:0];

    logic [3 * precision-1:0]   majority_dL_dcolor_out ;
    logic [precision-1:0]       majority_dL_ddepth_out ;
    logic [2 * precision-1:0]   majority_dL_dmean2D_out;
    logic [4 * precision-1:0]   majority_dL_dconic_out ;
    logic [precision-1:0]       majority_dL_dopacity_out;

    logic majority_valid_out;

    logic [encoder_and_fifo_data_size-1:0]  encoder_data_in         [Banks * num_pixels-1:0];
    logic                                   encoder_request_in   [Banks * num_pixels-1:0];
    logic                                   encoder_last_input_done_in   [Banks * num_pixels-1:0];
    
    logic                                   last_input_done_grant_out   [Banks * num_pixels-1:0];

    logic fifo_4x_full [Banks-1:0]; // 
    logic fifo_4x_empty [Banks-1:0];
    logic fifo_1x_full [Banks-1:0];
    logic fifo_1x_empty [Banks-1:0];

    // logic [encoder_and_fifo_data_size-1:0] encoder_to_fifo_data_out [num_pixels-1:0];
    // logic [encoder_and_fifo_data_size-1:0] encoder_to_fifo_data_out [Banks * Encoder_outs-1:0];

    // logic encoder_to_fifo_valid_out [num_pixels-1:0];
    logic encoder_to_fifo_valid_out [Banks * Encoder_outs-1:0];

    logic encoder_to_4x_fifo_valid_out [Banks * Encoder_outs-1:0];
    logic [encoder_and_fifo_data_size-1:0] encoder_to_4x_fifo_data_out [Banks * Encoder_outs-1:0];

    logic stall_from_encoder [Banks-1:0];

    logic src_grant_out [num_pixels * Banks-1:0];
    // logic src_grant_out [Encoder_outs * Banks-1:0];

    logic [ (encoder_and_fifo_data_size + 1)-1:0] fifo_1x_pop_data   [Banks-1:0];    

    logic [4 * (encoder_and_fifo_data_size + 2) -1:0] fifo_4x_to_serializer_data_out [Banks-1:0];
    logic serializer_to_4x_fifo_pop_valid [Banks-1:0];

    // logic [encoder_and_fifo_data_size-1:0] fifo_1x_to_serializer_data_out [Encoder_outs * Banks-1:0];
    // logic fifo_1x_to_serializer_pop_valid [Encoder_outs * Banks-1:0];

    logic [encoder_and_fifo_data_size-1:0] serializer_to_fifo_1x_data_out [Banks-1:0];
    logic serializer_to_fifo_1x_valid_out [Banks-1:0];

    logic last_input_done_from_encoder_out [Banks * Encoder_outs-1:0];
    logic last_input_done_from_serializer_out [Banks-1:0];

    logic [4 * (encoder_and_fifo_data_size + 2) -1:0] encoder_to_4x_fifo_push_in_wire [Banks-1:0];
    
    logic [ ( encoder_and_fifo_data_size)-1:0] serializer_data_in_from_4x_fifo [Encoder_outs * Banks-1:0]; // last input done은 따로 빼는걸로
    logic serializer_last_input_done_from_4x_fifo [Encoder_outs * Banks-1:0];
    logic serializer_valid_from_4x_fifo [Encoder_outs * Banks-1:0];

    wire [FIFO_to_SRAM_data_size-1:0] FIFO_pop_out       [Banks-1:0];

    wire [FIFO_to_SRAM_data_size-1:0] FIFO_to_SRAM_data_wire [Banks-1:0];

    logic [7:0] status_inst [Banks-1:0][1:11];

    // logic [GID_bit-1:0]      FIFO_GID_out        [Banks-1:0]; // == Read_address_before_add



    // logic serializer_data_in_grant_out [Encoder_outs * Banks-1:0];

    ////////////////////////////////
    //////////// FF Register ////////
    ////////////////////////////////

    logic [(3 * precision)-1:0]     dL_dcolor_before_majority_voter      [num_pixels-1:0];
    logic [precision-1:0]           dL_ddepth_before_majority_voter      [num_pixels-1:0];
    logic [(2 * precision)-1:0]     dL_dmean2D_before_majority_voter     [num_pixels-1:0];
    logic [(4 * precision)-1:0]     dL_dconic_before_majority_voter      [num_pixels-1:0];
    logic [precision-1:0]           dL_dopacity_before_majority_voter    [num_pixels-1:0];
    logic                           last_input_done_before_majority_voter [num_pixels-1:0];

    logic [GID_bit-1:0]             gaussian_id_before_majority_voter    [num_pixels-1:0];

    logic GID_valid_before_majority_voter [num_pixels-1:0];
    

    // Majority voter 내부 1 cycle 레지스터

    logic [(3 * precision)-1:0]     dL_dcolor_inside_majority_voter      [num_pixels-1:0];
    logic [precision-1:0]           dL_ddepth_inside_majority_voter      [num_pixels-1:0];
    logic [(2 * precision)-1:0]     dL_dmean2D_inside_majority_voter     [num_pixels-1:0];
    logic [(4 * precision)-1:0]     dL_dconic_inside_majority_voter      [num_pixels-1:0];
    logic [precision-1:0]           dL_dopacity_inside_majority_voter    [num_pixels-1:0];
    logic [GID_bit-1:0]             gaussian_id_inside_majority_voter    [num_pixels-1:0];

    logic                           GID_valid_inside_majority_voter      [num_pixels-1:0];

    logic                           last_input_done_inside_majority_voter [num_pixels-1:0];

    // Majority voter 2 cycle 레지스터

    logic [(3 * precision)-1:0]     dL_dcolor_inside_majority_voter_2_cycle      [num_pixels-1:0];
    logic [precision-1:0]           dL_ddepth_inside_majority_voter_2_cycle      [num_pixels-1:0];
    logic [(2 * precision)-1:0]     dL_dmean2D_inside_majority_voter_2_cycle     [num_pixels-1:0];
    logic [(4 * precision)-1:0]     dL_dconic_inside_majority_voter_2_cycle      [num_pixels-1:0];
    logic [precision-1:0]           dL_dopacity_inside_majority_voter_2_cycle    [num_pixels-1:0];
    logic [GID_bit-1:0]             gaussian_id_inside_majority_voter_2_cycle    [num_pixels-1:0];

    logic                           GID_valid_inside_majority_voter_2_cycle      [num_pixels-1:0];

    logic                           last_input_done_inside_majority_voter_2_cycle [num_pixels-1:0];




    logic [(3 * precision)-1:0]     dL_dcolor_after_majority_voter      [num_pixels-1:0];
    logic [precision-1:0]           dL_ddepth_after_majority_voter      [num_pixels-1:0];
    logic [(2 * precision)-1:0]     dL_dmean2D_after_majority_voter     [num_pixels-1:0];
    logic [(4 * precision)-1:0]     dL_dconic_after_majority_voter      [num_pixels-1:0];
    logic [precision-1:0]           dL_dopacity_after_majority_voter    [num_pixels-1:0];
    logic [GID_bit-1:0]             gaussian_id_after_majority_voter    [num_pixels-1:0];

    logic                           GID_valid_after_majority_voter      [num_pixels-1:0];

    logic                           last_input_done_after_majority_voter [num_pixels-1:0];


    // Majority Adder 내부 stage
    logic [(3 * precision)-1:0] dL_dcolor_inside_majority_adder         [majority_adder_stages * num_pixels - 1 : 0];
    logic [precision-1:0]       dL_ddepth_inside_majority_adder         [majority_adder_stages * num_pixels - 1 : 0];
    logic [(2 * precision)-1:0] dL_dmean2D_inside_majority_adder        [majority_adder_stages * num_pixels - 1 : 0];
    logic [(4 * precision)-1:0] dL_dconic_inside_majority_adder         [majority_adder_stages * num_pixels - 1 : 0];
    logic [precision-1:0]       dL_dopacity_inside_majority_adder       [majority_adder_stages * num_pixels - 1 : 0];

    logic [GID_bit-1:0]         gaussian_id_inside_majority_adder       [majority_adder_stages * num_pixels - 1 : 0];

    logic                       is_majority_gid_inside_majority_adder   [majority_adder_stages * num_pixels - 1 : 0];

    logic                       GID_valid_inside_majority_adder         [majority_adder_stages * num_pixels - 1 : 0];

    logic                       last_input_done_inside_majority_adder   [majority_adder_stages * num_pixels - 1 : 0];


    // before encoder (수정용)

    logic [3*precision-1:0]     dL_dcolor_before_encoder    [num_pixels - 1:0];
    logic [precision-1:0]       dL_ddepth_before_encoder    [num_pixels - 1:0];
    logic [(2*precision)-1:0]   dL_dmean2D_before_encoder   [num_pixels - 1:0];
    logic [(4*precision)-1:0]   dL_dconic_before_encoder    [num_pixels - 1:0];
    logic [precision-1:0]       dL_dopacity_before_encoder  [num_pixels - 1:0];

    logic [GID_bit-1:0]         gaussian_id_before_encoder    [num_pixels-1:0];

    logic                       GID_valid_before_encoder    [num_pixels-1:0];
    logic                       last_input_done_before_encoder [num_pixels-1:0];


    

    logic [(encoder_and_fifo_data_size + 1)-1:0] serializer_to_fifo_1x_push_in [Banks-1:0];
    logic serializer_to_fifo_1x_push_valid_in [Banks-1:0];
    

    // logic encoder_to_4x_fifo_push_valid_in [Encoder_outs-1:0];
    logic encoder_to_4x_fifo_push_valid_in [Banks-1:0];
    logic [4 * (encoder_and_fifo_data_size + 2) -1:0] encoder_to_4x_fifo_push_in [Banks-1:0];

    // PE 에서 4xFIFO

    logic encoder_to_4x_FIFO_buffer_valid [Banks-1:0];

    
    reg [FIFO_to_SRAM_data_size-1:0] FIFO_data_before_add_FF [Banks-1:0];
    reg [GID_bit-1:0] Write_address_after_add_temp1 [Banks-1:0];
    

    // logic last_input_done_from_encoder_in [Banks-1:0];
    
    


    
    //////////////////////////////////////
    ///////// Combinational Register //////
    //////////////////////////////////////

    logic majority_index_found;

    logic stall_from_encoder_comb;
    logic stall_from_1x_fifo_comb;
    logic stall_from_4x_fifo_comb;
    logic stall_from_serializer_comb;

    logic last_input_done_to_4x_fifo_valid_comb [Banks-1:0];
    logic last_input_done_to_1x_fifo_valid_comb [Banks-1:0];

    logic [3*precision-1:0]     dL_dcolor_to_encoder    [num_pixels-1:0];
    logic [precision-1:0]       dL_ddepth_to_encoder    [num_pixels-1:0];
    logic [(2*precision)-1:0]   dL_dmean2D_to_encoder   [num_pixels-1:0];
    logic [(4*precision)-1:0]   dL_dconic_to_encoder    [num_pixels-1:0];
    logic [precision-1:0]       dL_dopacity_to_encoder  [num_pixels-1:0];

    // logic                       valid_gradient_to_pass_encoder [num_pixels-1:0];

    logic                       GID_valid_to_encoder_reg [num_pixels-1:0];
    
    

    always_comb begin
        stall_from_encoder_comb = 0;
        stall_from_1x_fifo_comb = 0;
        stall_from_4x_fifo_comb = 0;
        stall_from_serializer_comb = 0;

        

        for (int i = 0; i < Banks; i++) begin
            
            stall_from_encoder_comb = stall_from_encoder_comb || stall_from_encoder[i];
            stall_from_1x_fifo_comb = stall_from_1x_fifo_comb || fifo_1x_full[i];
            stall_from_4x_fifo_comb = stall_from_4x_fifo_comb || fifo_4x_full[i];
            stall_from_serializer_comb = stall_from_serializer_comb || !serializer_to_4x_fifo_pop_valid[i];

            last_input_done_to_4x_fifo_valid_comb[i] = 0;
            last_input_done_to_1x_fifo_valid_comb[i] = 0;

            for (int j = 0; j < Encoder_outs; j++) begin
                last_input_done_to_4x_fifo_valid_comb[i] = last_input_done_to_4x_fifo_valid_comb[i] || last_input_done_from_encoder_out[i * Encoder_outs + j];
                
            end
            last_input_done_to_1x_fifo_valid_comb[i] = last_input_done_to_1x_fifo_valid_comb[i] || last_input_done_from_serializer_out[i];
        end

        // stall_to_controller_next = stall_from_encoder_comb || stall_from_1x_fifo_comb || stall_backpressure;
    
    end

    // assign stall_to_controller = stall_from_encoder_comb || stall_from_1x_fifo_comb || stall_backpressure;
    assign stall_to_controller = stall_from_encoder_comb || stall_backpressure;


    majority_voter #(
        .num_pixels(num_pixels),
        .GID_bit(GID_bit)
    )
    majority_voter_inst (
    .clk(clk),
    .rst_n(rst_n),

    .gaussian_id(gaussian_id_before_majority_voter),
    .GID_valid(GID_valid_before_majority_voter),
    // .stall_backpressure(stall_backpressure),
    // .stall_backpressure(stall_backpressure),
    .stall_backpressure(stall_to_controller),

    .is_majority_gid(is_majority_gid)
    );


    majority_adder #(
        .exponent_bit(exponent_bit),
        .precision(precision),
        .mantissa_bit(mantissa_bit),
        .num_pixels(num_pixels)
    )    
    majority_adder_inst (
        .clk(clk),
        .rst_n(rst_n),

        .dL_dcolor_in(dL_dcolor_after_majority_voter),
        .dL_ddepth_in(dL_ddepth_after_majority_voter),
        .dL_dmean2D_in(dL_dmean2D_after_majority_voter),
        .dL_dconic_in(dL_dconic_after_majority_voter),
        .dL_dopacity_in(dL_dopacity_after_majority_voter),

        .is_majority_gid_in(is_majority_gid),

        // .stall_backpressure(stall_backpressure),
        .stall_backpressure(stall_to_controller),

        .majority_dL_dcolor_out(majority_dL_dcolor_out),
        .majority_dL_ddepth_out(majority_dL_ddepth_out),
        .majority_dL_dmean2D_out(majority_dL_dmean2D_out),
        .majority_dL_dconic_out(majority_dL_dconic_out),
        .majority_dL_dopacity_out(majority_dL_dopacity_out),

        .majority_valid_out(majority_valid_out)
    );
    

    // // Majority인 값 중에서 Added 된 값 처리
    // genvar l;
    // generate 

    // Majority인 INDEX 확인
    always_comb begin
        majority_index_found = 1'b0;

        // Default values for all indices
        for (int l = 0; l < num_pixels; l = l + 1) begin
            if (!is_majority_gid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l]) begin
                // Not a majority index - use default values
                dL_dcolor_to_encoder[l] = dL_dcolor_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_ddepth_to_encoder[l] = dL_ddepth_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_dmean2D_to_encoder[l] = dL_dmean2D_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_dconic_to_encoder[l] = dL_dconic_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_dopacity_to_encoder[l] = dL_dopacity_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];

                // valid_gradient_to_pass_encoder[l] = GID_valid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                

                GID_valid_to_encoder_reg[l] = GID_valid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
            end 

            else begin
                // Is a majority index
                // last input done이 majority에 모여있는 경우에는? 
                if (majority_valid_out && !majority_index_found && 
                    GID_valid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l]) begin
                    // First valid majority index found
                    majority_index_found = 1'b1;
                    dL_dcolor_to_encoder[l] = majority_dL_dcolor_out;
                    dL_ddepth_to_encoder[l] = majority_dL_ddepth_out;
                    dL_dmean2D_to_encoder[l] = majority_dL_dmean2D_out;
                    dL_dconic_to_encoder[l] = majority_dL_dconic_out;
                    dL_dopacity_to_encoder[l] = majority_dL_dopacity_out;

                    GID_valid_to_encoder_reg[l] = 1'b1;
                    // valid_gradient_to_pass_encoder[l] = 1'b1;
                end 
                else begin
                    // Zero out all other majority indices
                    dL_dcolor_to_encoder[l] = 'h0;
                    dL_ddepth_to_encoder[l] = 'h0;
                    dL_dmean2D_to_encoder[l] = 'h0;
                    dL_dconic_to_encoder[l] = 'h0;
                    dL_dopacity_to_encoder[l] = 'h0;

                    GID_valid_to_encoder_reg[l] = 1'b0;
                    // valid_gradient_to_pass_encoder[l] = 1'b0;
                end
            end
        end
    end


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

            priority_encoder_with_buffer #(
                .INPUTS(num_pixels),
                .OUTPUTS(Encoder_outs),
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

                .last_input_done_o(last_input_done_from_encoder_out[k * Encoder_outs +: Encoder_outs]),

                .dst_valid_o(encoder_to_4x_fifo_valid_out[k * Encoder_outs +: Encoder_outs]), // 다음 단에 Data 전송
                .dst_data_o(encoder_to_4x_fifo_data_out[k * Encoder_outs +: Encoder_outs]), // 각 포트에 Valid한 데이터인지 기입

                .stall_backpressure(stall_backpressure || (fifo_4x_full[k] && encoder_to_4x_fifo_push_valid_in[k])),
                .stall_from_encoder(stall_from_encoder[k]),

                // .dst_ready_i(!fifo_4x_full[k])
                .dst_ready_i(!fifo_4x_full[k] || !encoder_to_4x_fifo_push_valid_in[k])
            );


            for (n = 0; n < Encoder_outs; n = n + 1) begin : encoder_to_4x_fifo_push_in_wire_concatenation

                // encoder => FIFO 4x
                assign encoder_to_4x_fifo_push_in_wire[k][(n + 1) * (encoder_and_fifo_data_size + 2) - 1 : n * (encoder_and_fifo_data_size + 2)] = {
                                                                                                                            encoder_to_4x_fifo_valid_out[k * Encoder_outs + n],
                                                                                                                            last_input_done_from_encoder_out[k * Encoder_outs + n], 
                                                                                                                            encoder_to_4x_fifo_data_out[k * Encoder_outs + n]
                                                                                                                        };
                // // FIFO 4x => Serializer
                assign serializer_valid_from_4x_fifo[k * Encoder_outs + n] = !fifo_4x_empty[k] ? fifo_4x_to_serializer_data_out[k][(n + 1) * (encoder_and_fifo_data_size + 2) - 1] : 'h0;
                assign serializer_last_input_done_from_4x_fifo[k * Encoder_outs + n] = !fifo_4x_empty[k] ? fifo_4x_to_serializer_data_out[k][(n + 1) * (encoder_and_fifo_data_size + 2) - 2] : 'h0;
                assign serializer_data_in_from_4x_fifo[k * Encoder_outs + n] = !fifo_4x_empty[k] ? fifo_4x_to_serializer_data_out[k][(n + 1) * (encoder_and_fifo_data_size + 2) - 3 : n * (encoder_and_fifo_data_size + 2)] : 'h0;  
            end




            push_pop_FIFO #(
                .FIFO_depth(First_FIFO_depth),
                .input_data_width(4 * (encoder_and_fifo_data_size + 2)),
                .output_data_width(4 * (encoder_and_fifo_data_size + 2))
            )
            FIFO_4x_inst (
                .clk(clk),
                .rst_n(rst_n),

                .push_data_in(encoder_to_4x_fifo_push_in[k]),
                .push_valid_in(encoder_to_4x_fifo_push_valid_in[k] && !fifo_4x_full[k]),

                .pop_valid_in(serializer_to_4x_fifo_pop_valid[k]), 
                .pop_data_out(fifo_4x_to_serializer_data_out[k]),

                .full_out(fifo_4x_full[k]), // stall_from_fifo
                .empty_out(fifo_4x_empty[k])
            );

            serializer #(
                .precision(precision),
                .GID_bit(GID_bit),
                .DATA_SIZE(encoder_and_fifo_data_size),
                .Encoder_outs(Encoder_outs)
            )
            serializer_inst (
                .clk(clk),
                .rst_n(rst_n),

                .data_in(serializer_data_in_from_4x_fifo[k * Encoder_outs +: Encoder_outs]),
                .valid_in(serializer_valid_from_4x_fifo[k * Encoder_outs +: Encoder_outs]), // serializer에 들어온 4개중 몇개가 valid인가

                // .data_in_grant_out(serializer_data_in_grant_out[k * Encoder_outs +: Encoder_outs]),

                .data_out(serializer_to_fifo_1x_data_out[k]),
                .valid_out(serializer_to_fifo_1x_valid_out[k]),

                .last_input_done_i(serializer_last_input_done_from_4x_fifo[k * Encoder_outs +: Encoder_outs]),
                .last_input_done_o(last_input_done_from_serializer_out[k]),

                .stall_backpressure(stall_backpressure || fifo_1x_full[k]),

                .pop_next_valid_out(serializer_to_4x_fifo_pop_valid[k]), // 사실상 stall의 기능 수행

                .src_pop_valid_i(!fifo_4x_empty[k]),

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

                .push_data_in(serializer_to_fifo_1x_push_in[k]),
                .push_valid_in(serializer_to_fifo_1x_push_valid_in[k]),

                .pop_valid_in(FIFO_pop_valid_in[k]), 
                .pop_data_out(fifo_1x_pop_data[k]),

                .full_out(fifo_1x_full[k]), // stall_from_fifo
                .empty_out(fifo_1x_empty[k])
            );



            assign FIFO_pop_ready_out[k] = !fifo_1x_empty[k];
            assign FIFO_GID_out[k] = fifo_1x_pop_data[k][GID_bit-1:0];
            assign FIFO_pop_out[k] = fifo_1x_pop_data[k][encoder_and_fifo_data_size-1:GID_bit];
            assign last_input_done_out[k] = fifo_1x_pop_data[k][encoder_and_fifo_data_size];






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
                dL_dcolor_before_majority_voter[i] <= '0;
                dL_ddepth_before_majority_voter[i] <= '0;
                dL_dmean2D_before_majority_voter[i] <= '0;
                dL_dconic_before_majority_voter[i] <= '0;
                dL_dopacity_before_majority_voter[i] <= '0;
                gaussian_id_before_majority_voter[i] <= '0;
                GID_valid_before_majority_voter[i] <= '0;
                last_input_done_before_majority_voter[i] <= '0;

                dL_dcolor_inside_majority_voter[i] <= '0;
                dL_ddepth_inside_majority_voter[i] <= '0;
                dL_dmean2D_inside_majority_voter[i] <= '0;
                dL_dconic_inside_majority_voter[i] <= '0;
                dL_dopacity_inside_majority_voter[i] <= '0;
                gaussian_id_inside_majority_voter[i] <= '0;
                GID_valid_inside_majority_voter[i] <= '0;
                last_input_done_inside_majority_voter[i] <= '0;

                dL_dcolor_inside_majority_voter_2_cycle[i] <= '0;
                dL_ddepth_inside_majority_voter_2_cycle[i] <= '0;
                dL_dmean2D_inside_majority_voter_2_cycle[i] <= '0;
                dL_dconic_inside_majority_voter_2_cycle[i] <= '0;
                dL_dopacity_inside_majority_voter_2_cycle[i] <= '0;
                gaussian_id_inside_majority_voter_2_cycle[i] <= '0;
                GID_valid_inside_majority_voter_2_cycle[i] <= '0;
                last_input_done_inside_majority_voter_2_cycle[i] <= '0;
                

                dL_dcolor_after_majority_voter[i] <= '0;
                dL_ddepth_after_majority_voter[i] <= '0;
                dL_dmean2D_after_majority_voter[i] <= '0;
                dL_dconic_after_majority_voter[i] <= '0;
                dL_dopacity_after_majority_voter[i] <= '0;
                gaussian_id_after_majority_voter[i] <= '0;
                GID_valid_after_majority_voter[i] <= '0;
                last_input_done_after_majority_voter[i] <= '0;

                dL_dcolor_before_encoder[i] <= '0;
                dL_ddepth_before_encoder[i] <= '0;
                dL_dmean2D_before_encoder[i] <= '0;
                dL_dconic_before_encoder[i] <= '0;
                dL_dopacity_before_encoder[i] <= '0;
                gaussian_id_before_encoder[i] <= '0;
                GID_valid_before_encoder[i] <= '0;
                last_input_done_before_encoder[i] <= '0;

                for (int j = 0; j < majority_adder_stages; j++) begin
                    dL_dcolor_inside_majority_adder[j * num_pixels + i] <= '0;
                    dL_ddepth_inside_majority_adder[j * num_pixels + i] <= '0;
                    dL_dmean2D_inside_majority_adder[j * num_pixels + i] <= '0;
                    dL_dconic_inside_majority_adder[j * num_pixels + i] <= '0;
                    dL_dopacity_inside_majority_adder[j * num_pixels + i] <= '0;
                    gaussian_id_inside_majority_adder[j * num_pixels + i] <= '0;
                    is_majority_gid_inside_majority_adder[j * num_pixels + i] <= '0;
                    GID_valid_inside_majority_adder[j * num_pixels + i] <= '0;
                    last_input_done_inside_majority_adder[j * num_pixels + i] <= '0;
                end
            end

            for (int j = 0; j < Banks; j++) begin
                FIFO_data_before_add_FF[j] <= 'h0;
                // FIFO_to_SRAM_data_out[j] <= 'h0;
                // Read_address_before_add[j] <= 'h0;
                Write_address_after_add[j] <= 'h0;
                Write_address_after_add_temp1[j] <= 'h0;
                // Read_address_before_add[j] <= 'h0;  
                FIFO_to_SRAM_data[j] <= 'h0;
            end
        end

        else begin

            for (int j = 0; j < Banks; j++) begin

                for (int i = 0; i < num_pixels; i++) begin
                    // handshake part

                    if (encoder_request_in[j * num_pixels + i] && src_grant_out[j * num_pixels + i]) begin
                    // if (encoder_request_in[j * num_pixels + i]) begin
                        GID_valid_before_encoder[i] <= 1'b0;
                    end      

                    if (encoder_last_input_done_in[j * num_pixels + i] && last_input_done_grant_out[j * num_pixels + i]) begin
                        last_input_done_before_encoder[i] <= 1'b0;
                    end        
                end


                // Read_address_before_add[j] <= FIFO_GID_out[j];
                // FIFO_to_SRAM_data[j] <= FIFO_pop_out[j];
                
                FIFO_to_SRAM_data[j] <= FIFO_to_SRAM_data_wire[j];
                // Write_address_after_add_temp2[j] <= Write_address_after_add_temp1[j];
                // Write_address_after_add[j] <= Write_address_after_add_temp2[j];

                
                // Write_address_after_add[j] <= Write_address_after_add_temp1[j];
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

                // FIFO_to_SRAM_data_out[j] <= FIFO_to_SRAM_data[j];

                

                // FIFO 1x Part handshake  
                // fifo 1x 가 full 이면서 push valid가 1인 경우 제외 파이프라이닝 이동 >> 이게 무슨 의미일까
                // full인데 push 넣을려고하는 불가능 상황은 현상 유지 그 외에는 
                // 
                // if (!(fifo_1x_full[j] && serializer_to_fifo_1x_push_valid_in[j])) begin

                if (!fifo_1x_full[j]) begin
                    serializer_to_fifo_1x_push_in[j] <= {last_input_done_from_serializer_out[j], serializer_to_fifo_1x_data_out[j]};
                    serializer_to_fifo_1x_push_valid_in[j] <= serializer_to_fifo_1x_valid_out[j] || last_input_done_to_1x_fifo_valid_comb[j];
                end

                // FIFO 4x Part handshake   
                if ( !(fifo_4x_full[j] && encoder_to_4x_fifo_push_valid_in[j])) begin
                    encoder_to_4x_fifo_push_valid_in[j] <= encoder_to_4x_fifo_valid_out[j * Encoder_outs] || last_input_done_to_4x_fifo_valid_comb[j]; // 각 Bank의 0번 데이터가 Valid하면 전송 (왜냐하면 0번부터 나온다고 가정)
                    encoder_to_4x_fifo_push_in[j] <= encoder_to_4x_fifo_push_in_wire[j];
                end
                
    


            end

            // stall to controller는 Encoder 이전 단계에서 적용 그 후 단계는 각각 FULL /EMPTY 신호로 각자 제어
            if (!stall_to_controller) begin

                for (int i = 0; i < num_pixels; i++) begin
                    dL_dcolor_before_majority_voter[i] <= dL_dcolor_in[i];
                    dL_ddepth_before_majority_voter[i] <= dL_ddepth_in[i];
                    dL_dmean2D_before_majority_voter[i] <= dL_dmean2D_in[i];
                    dL_dconic_before_majority_voter[i] <= dL_dconic_in[i];
                    dL_dopacity_before_majority_voter[i] <= dL_dopacity_in[i];
                    gaussian_id_before_majority_voter[i] <= gaussian_id_in[i];
                    GID_valid_before_majority_voter[i] <= GID_valid_in[i];
                    last_input_done_before_majority_voter[i] <= last_input_done_in[i];

                    dL_dcolor_inside_majority_voter[i] <= dL_dcolor_before_majority_voter[i];
                    dL_ddepth_inside_majority_voter[i] <= dL_ddepth_before_majority_voter[i];
                    dL_dmean2D_inside_majority_voter[i] <= dL_dmean2D_before_majority_voter[i];
                    dL_dconic_inside_majority_voter[i] <= dL_dconic_before_majority_voter[i];
                    dL_dopacity_inside_majority_voter[i] <= dL_dopacity_before_majority_voter[i];
                    gaussian_id_inside_majority_voter[i] <= gaussian_id_before_majority_voter[i];
                    GID_valid_inside_majority_voter[i] <= GID_valid_before_majority_voter[i];
                    last_input_done_inside_majority_voter[i] <= last_input_done_before_majority_voter[i];

                    dL_dcolor_inside_majority_voter_2_cycle[i] <= dL_dcolor_inside_majority_voter[i];
                    dL_ddepth_inside_majority_voter_2_cycle[i] <= dL_ddepth_inside_majority_voter[i];
                    dL_dmean2D_inside_majority_voter_2_cycle[i] <= dL_dmean2D_inside_majority_voter[i];
                    dL_dconic_inside_majority_voter_2_cycle[i] <= dL_dconic_inside_majority_voter[i];
                    dL_dopacity_inside_majority_voter_2_cycle[i] <= dL_dopacity_inside_majority_voter[i];
                    gaussian_id_inside_majority_voter_2_cycle[i] <= gaussian_id_inside_majority_voter[i];
                    GID_valid_inside_majority_voter_2_cycle[i] <= GID_valid_inside_majority_voter[i];
                    last_input_done_inside_majority_voter_2_cycle[i] <= last_input_done_inside_majority_voter[i];

                    dL_dcolor_after_majority_voter[i] <= dL_dcolor_inside_majority_voter_2_cycle[i];
                    dL_ddepth_after_majority_voter[i] <= dL_ddepth_inside_majority_voter_2_cycle[i];
                    dL_dmean2D_after_majority_voter[i] <= dL_dmean2D_inside_majority_voter_2_cycle[i];
                    dL_dconic_after_majority_voter[i] <= dL_dconic_inside_majority_voter_2_cycle[i];
                    dL_dopacity_after_majority_voter[i] <= dL_dopacity_inside_majority_voter_2_cycle[i];
                    gaussian_id_after_majority_voter[i] <= gaussian_id_inside_majority_voter_2_cycle[i];
                    GID_valid_after_majority_voter[i] <= GID_valid_inside_majority_voter_2_cycle[i];
                    last_input_done_after_majority_voter[i] <= last_input_done_inside_majority_voter_2_cycle[i];
                    
                    dL_dcolor_inside_majority_adder[i] <= dL_dcolor_after_majority_voter[i];
                    dL_ddepth_inside_majority_adder[i] <= dL_ddepth_after_majority_voter[i];
                    dL_dmean2D_inside_majority_adder[i] <= dL_dmean2D_after_majority_voter[i];
                    dL_dconic_inside_majority_adder[i] <= dL_dconic_after_majority_voter[i];
                    dL_dopacity_inside_majority_adder[i] <= dL_dopacity_after_majority_voter[i];
                    gaussian_id_inside_majority_adder[i] <= gaussian_id_after_majority_voter[i];
                    is_majority_gid_inside_majority_adder[i] <= is_majority_gid[i];
                    GID_valid_inside_majority_adder[i] <= GID_valid_after_majority_voter[i];
                    last_input_done_inside_majority_adder[i] <= last_input_done_after_majority_voter[i];


                    dL_dcolor_before_encoder[i] <= dL_dcolor_to_encoder[i];
                    dL_ddepth_before_encoder[i] <= dL_ddepth_to_encoder[i];
                    dL_dmean2D_before_encoder[i] <= dL_dmean2D_to_encoder[i];
                    dL_dconic_before_encoder[i] <= dL_dconic_to_encoder[i];
                    dL_dopacity_before_encoder[i] <= dL_dopacity_to_encoder[i];

                    last_input_done_before_encoder[i] <= last_input_done_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + i];


                    gaussian_id_before_encoder[i] <= gaussian_id_inside_majority_adder[(majority_adder_stages-1) * num_pixels + i];
                    GID_valid_before_encoder[i] <= GID_valid_to_encoder_reg[i];


                    for (int j = 1; j < majority_adder_stages; j++) begin
                        dL_dcolor_inside_majority_adder[j * num_pixels + i] <= dL_dcolor_inside_majority_adder[(j-1) * num_pixels + i];
                        dL_ddepth_inside_majority_adder[j * num_pixels + i] <= dL_ddepth_inside_majority_adder[(j-1) * num_pixels + i];
                        dL_dmean2D_inside_majority_adder[j * num_pixels + i] <= dL_dmean2D_inside_majority_adder[(j-1) * num_pixels + i];
                        dL_dconic_inside_majority_adder[j * num_pixels + i] <= dL_dconic_inside_majority_adder[(j-1) * num_pixels + i];
                        dL_dopacity_inside_majority_adder[j * num_pixels + i] <= dL_dopacity_inside_majority_adder[(j-1) * num_pixels + i];
                        gaussian_id_inside_majority_adder[j * num_pixels + i] <= gaussian_id_inside_majority_adder[(j-1) * num_pixels + i];
                        is_majority_gid_inside_majority_adder[j * num_pixels + i] <= is_majority_gid_inside_majority_adder[(j-1) * num_pixels + i];
                        GID_valid_inside_majority_adder[j * num_pixels + i] <= GID_valid_inside_majority_adder[(j-1) * num_pixels + i];

                        last_input_done_inside_majority_adder[j * num_pixels + i] <= last_input_done_inside_majority_adder[(j-1) * num_pixels + i];
                    end
                end
            end
        end
    end




endmodule