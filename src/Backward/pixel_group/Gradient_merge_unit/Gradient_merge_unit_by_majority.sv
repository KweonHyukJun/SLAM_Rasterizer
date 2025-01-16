module Gradient_merge_unit_by_majority #(
    parameter BLOCK_SIZE = 16, 
    parameter exponent_bit = 8, 
    parameter precision = 16, 
    parameter mantissa_bit = 7, 
    parameter num_pixels = 16, 
    parameter GID_bit = 24,
    parameter First_FIFO_depth = 4,
    parameter Last_FIFO_depth = 16,
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
    input logic [GID_bit-1:0]       gaussian_id         [num_pixels-1:0],
    input logic [(3*precision)-1:0] dL_dcolor           [num_pixels-1:0],
    input logic [precision-1:0]     dL_ddepth           [num_pixels-1:0],
    input logic [(2*precision)-1:0] dL_dmean2D          [num_pixels-1:0],
    input logic [(4*precision)-1:0] dL_dconic           [num_pixels-1:0],
    input logic [precision-1:0]     dL_dopacity         [num_pixels-1:0],

    input logic                     GID_valid           [num_pixels-1:0], // gradient_valid_out in Backward_Rasterizer_unit

    input logic                     stall_backpressure,


    // Input From Controller
    input logic                     FIFO_pop_valid_in  [Banks-1:0], // 컨트롤러 입력




    // FIFO Output은 Push/Pop으로 cycle 수 감소해서 처리하도록


    // Output To Read SRAM GID
    // output logic                    GID_valid_out       [Banks-1:0], 
    output logic                    FIFO_pop_ready_out          [Banks-1:0], // Wired Logic

    output logic [GID_bit-1:0]      FIFO_GID_out        [Banks-1:0],
    output logic [FIFO_to_SRAM_data_size-1:0] FIFO_pop_out       [Banks-1:0],


    // // Control Signal
    output logic stall_to_controller
);

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
    logic                                   encoder_valid_in   [Banks * num_pixels-1:0];


    logic fifo_4x_full [Banks-1:0]; // 
    logic fifo_4x_empty [Banks-1:0];
    logic fifo_1x_full [Banks-1:0];
    logic fifo_1x_empty [Banks-1:0];

    // logic [encoder_and_fifo_data_size-1:0] encoder_to_fifo_data_out [num_pixels-1:0];
    logic [encoder_and_fifo_data_size-1:0] encoder_to_fifo_data_out [Banks * Encoder_outs-1:0];

    // logic encoder_to_fifo_valid_out [num_pixels-1:0];
    logic encoder_to_fifo_valid_out [Banks * Encoder_outs-1:0];


    logic stall_from_encoder [num_pixels-1:0];

    // logic src_grant_out [num_pixels * Banks-1:0];
    logic src_grant_out [Encoder_outs * Banks-1:0];

    logic [encoder_and_fifo_data_size-1:0] FIFO_pop       [Banks-1:0];

    logic last_input_done_o [Banks * Encoder_outs-1:0];
    


    ////////////////////////////////
    //////////// FF Register ////////
    ////////////////////////////////

    logic [(3 * precision)-1:0]     dL_dcolor_before_majority_voter      [num_pixels-1:0];
    logic [precision-1:0]           dL_ddepth_before_majority_voter      [num_pixels-1:0];
    logic [(2 * precision)-1:0]     dL_dmean2D_before_majority_voter     [num_pixels-1:0];
    logic [(4 * precision)-1:0]     dL_dconic_before_majority_voter      [num_pixels-1:0];
    logic [precision-1:0]           dL_dopacity_before_majority_voter    [num_pixels-1:0];

    logic [GID_bit-1:0]             gaussian_id_before_majority_voter    [num_pixels-1:0];

    logic GID_valid_before_majority_voter [num_pixels-1:0];
    



    logic [(3 * precision)-1:0]     dL_dcolor_after_majority_voter      [num_pixels-1:0];
    logic [precision-1:0]           dL_ddepth_after_majority_voter      [num_pixels-1:0];
    logic [(2 * precision)-1:0]     dL_dmean2D_after_majority_voter     [num_pixels-1:0];
    logic [(4 * precision)-1:0]     dL_dconic_after_majority_voter      [num_pixels-1:0];
    logic [precision-1:0]           dL_dopacity_after_majority_voter    [num_pixels-1:0];
    logic [GID_bit-1:0]             gaussian_id_after_majority_voter    [num_pixels-1:0];

    logic                           GID_valid_after_majority_voter      [num_pixels-1:0];


    // Majority Adder 내부 stage
    logic [(3 * precision)-1:0] dL_dcolor_inside_majority_adder         [majority_adder_stages * num_pixels - 1 : 0];
    logic [precision-1:0]       dL_ddepth_inside_majority_adder         [majority_adder_stages * num_pixels - 1 : 0];
    logic [(2 * precision)-1:0] dL_dmean2D_inside_majority_adder        [majority_adder_stages * num_pixels - 1 : 0];
    logic [(4 * precision)-1:0] dL_dconic_inside_majority_adder         [majority_adder_stages * num_pixels - 1 : 0];
    logic [precision-1:0]       dL_dopacity_inside_majority_adder       [majority_adder_stages * num_pixels - 1 : 0];

    logic [GID_bit-1:0]         gaussian_id_inside_majority_adder       [majority_adder_stages * num_pixels - 1 : 0];

    logic                       is_majority_gid_inside_majority_adder   [majority_adder_stages * num_pixels - 1 : 0];

    logic                       GID_valid_inside_majority_adder         [majority_adder_stages * num_pixels - 1 : 0];


    // before encoder (수정용)

    logic [3*precision-1:0]     dL_dcolor_before_encoder    [num_pixels - 1:0];
    logic [precision-1:0]       dL_ddepth_before_encoder    [num_pixels - 1:0];
    logic [(2*precision)-1:0]   dL_dmean2D_before_encoder   [num_pixels - 1:0];
    logic [(4*precision)-1:0]   dL_dconic_before_encoder    [num_pixels - 1:0];
    logic [precision-1:0]       dL_dopacity_before_encoder  [num_pixels - 1:0];

    logic [GID_bit-1:0]         gaussian_id_before_encoder    [num_pixels-1:0];

    logic                       GID_valid_before_encoder    [num_pixels-1:0];


    logic encoder_to_fifo_push_valid_in [num_pixels-1:0];
    logic [encoder_and_fifo_data_size-1:0] encoder_to_fifo_push_in [num_pixels-1:0];

    // PE 에서 4xFIFO
    logic [4 * encoder_and_fifo_data_size-1:0] encoder_to_4x_FIFO_data [Banks-1:0];
    logic encoder_to_4x_FIFO_valid [Banks-1:0];

    


    
    //////////////////////////////////////
    ///////// Combinational Register //////
    //////////////////////////////////////

    logic majority_index_found;

    logic stall_from_encoder_comb;
    logic stall_from_1x_fifo_comb;
    logic stall_from_4x_fifo_comb;
    

    logic [3*precision-1:0]     dL_dcolor_to_encoder    [num_pixels-1:0];
    logic [precision-1:0]       dL_ddepth_to_encoder    [num_pixels-1:0];
    logic [(2*precision)-1:0]   dL_dmean2D_to_encoder   [num_pixels-1:0];
    logic [(4*precision)-1:0]   dL_dconic_to_encoder    [num_pixels-1:0];
    logic [precision-1:0]       dL_dopacity_to_encoder  [num_pixels-1:0];

    logic                       valid_gradient_to_pass_encoder [num_pixels-1:0];

    logic                       GID_valid_to_encoder_reg [num_pixels-1:0];
    
    

    always_comb begin
        stall_from_encoder_comb = 0;
        stall_from_1x_fifo_comb = 0;
        stall_from_4x_fifo_comb = 0;
        

        for (int i = 0; i < Banks; i++) begin
            stall_from_encoder_comb = stall_from_encoder_comb || stall_from_encoder[i];
            stall_from_1x_fifo_comb = stall_from_1x_fifo_comb || fifo_1x_full[i];
            stall_from_4x_fifo_comb = stall_from_4x_fifo_comb || fifo_4x_full[i];
        end

        // stall_to_controller_next = stall_from_encoder_comb || stall_from_1x_fifo_comb || stall_backpressure;
    
    end

    assign stall_to_controller = stall_from_encoder_comb || stall_from_1x_fifo_comb || stall_backpressure;


    majority_voter #(
        .num_pixels(num_pixels),
        .GID_bit(GID_bit)
    )
    majority_voter_inst (
    .clk(clk),
    .rst_n(rst_n),

    .gaussian_id(gaussian_id_before_majority_voter),
    .GID_valid(GID_valid_before_majority_voter),
    .stall_backpressure(stall_backpressure),

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

        .stall_backpressure(stall_backpressure),

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

                valid_gradient_to_pass_encoder[l] = GID_valid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];

                GID_valid_to_encoder_reg[l] = GID_valid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
            end 

            else begin
                // Is a majority index
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
                    valid_gradient_to_pass_encoder[l] = 1'b1;
                end 
                else begin
                    // Zero out all other majority indices
                    dL_dcolor_to_encoder[l] = 'h0;
                    dL_ddepth_to_encoder[l] = 'h0;
                    dL_dmean2D_to_encoder[l] = 'h0;
                    dL_dconic_to_encoder[l] = 'h0;
                    dL_dopacity_to_encoder[l] = 'h0;

                    GID_valid_to_encoder_reg[l] = 1'b0;
                    valid_gradient_to_pass_encoder[l] = 1'b0;
                end
            end
        end
    end


    genvar k, m;
    generate
        for (k = 0; k < Banks; k = k + 1) begin : aribtration_and_fifo

            // Problem: The signals are declared as 2D arrays [stage][pixel] but we're trying to do bit selection
            // which isn't valid for 2D arrays. We need to concatenate the full signals without bit selection.
            for (m = 0; m < num_pixels; m = m + 1) begin : encoder_data_in_concatenation

                assign encoder_data_in[k * Banks + m] = (gaussian_id_before_encoder[m][$clog2(num_pixels)-1:0] == k) ? 

                {
                    dL_dcolor_before_encoder[m],
                    dL_ddepth_before_encoder[m],
                    dL_dmean2D_before_encoder[m],
                    dL_dconic_before_encoder[m],
                    dL_dopacity_before_encoder[m],

                    gaussian_id_before_encoder[m]
                } : 'h0;

                assign encoder_valid_in[k * Banks + m] = ((gaussian_id_before_encoder[m][$clog2(num_pixels)-1:0] == k) 
                                                            // && valid_gradient_to_pass_encoder[m] 
                                                            && GID_valid_before_encoder[m]);
            end

            
            // Priority Encoder, 4x FIFO, Serializer, FIFO

            priority_encoder #(
                .INPUTS(num_pixels),
                .OUTPUTS(Encoder_outs),
                .DATA_SIZE(encoder_and_fifo_data_size)
            )
            priority_encoder_inst (
                .clk(clk),
                .rst_n(rst_n),

                .src_request_i(encoder_valid_in[k * Banks +: Banks]),
                .src_grant_o(src_grant_out[k * Encoder_outs +: Encoder_outs]),
                .src_data_i(encoder_data_in[k * Banks +: Banks]), 

                .last_input_done_i(last_input_done_i[k * Banks +: Banks]),
                .last_input_done_o(last_input_done_o[k * Encoder_outs +: Encoder_outs]),

                .dst_valid_o(encoder_to_fifo_valid_out[k * Encoder_outs +: Encoder_outs]), 
                .dst_data_o(encoder_to_fifo_data_out[k * Encoder_outs +: Encoder_outs]),

                .stall_backpressure(stall_backpressure),
                .stall_from_encoder(stall_from_encoder[k])
            );


            push_pop_FIFO #(
                .FIFO_depth(First_FIFO_depth),
                .input_data_width(4 * encoder_and_fifo_data_size),
                .output_data_width(4 * encoder_and_fifo_data_size)
            )
            FIFO_4x_inst (
                .clk(clk),
                .rst_n(rst_n),

                .push_data_in(encoder_to_4x_data_in),
                .push_valid_in(encoder_to_4x_valid_in),

                .pop_valid_in(), 
                .pop_data_out(),

                .full_out(fifo_4x_full), // stall_from_fifo
                .empty_out(fifo_4x_empty)
            );

            serializer #(
                .DATA_SIZE(encoder_and_fifo_data_size),
                .Encoder_outs(Encoder_outs)
            )
            serializer_inst (
                .clk(clk),
                .rst_n(rst_n),
            )

            push_pop_FIFO #(
                .FIFO_depth(Last_FIFO_depth),
                .input_data_width(encoder_and_fifo_data_size),
                .output_data_width(encoder_and_fifo_data_size)
            )
            FIFO_inst (
                .clk(clk),
                .rst_n(rst_n),

                .push_data_in(encoder_to_fifo_push_in[k]),
                .push_valid_in(encoder_to_fifo_push_valid_in[k]),

                .pop_valid_in(FIFO_pop_valid_in[k]), 
                .pop_data_out(FIFO_pop[k]),

                .full_out(fifo_full[k]), // stall_from_fifo
                .empty_out(fifo_empty[k])
            );



            assign FIFO_pop_ready_out[k] = !fifo_empty[k];
            assign FIFO_GID_out[k] = FIFO_pop[k][GID_bit-1:0];
            assign FIFO_pop_out[k] = FIFO_pop[k][encoder_and_fifo_data_size-1:GID_bit];
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

                dL_dcolor_after_majority_voter[i] <= '0;
                dL_ddepth_after_majority_voter[i] <= '0;
                dL_dmean2D_after_majority_voter[i] <= '0;
                dL_dconic_after_majority_voter[i] <= '0;
                dL_dopacity_after_majority_voter[i] <= '0;
                gaussian_id_after_majority_voter[i] <= '0;
                GID_valid_after_majority_voter[i] <= '0;

                dL_dcolor_before_encoder[i] <= '0;
                dL_ddepth_before_encoder[i] <= '0;
                dL_dmean2D_before_encoder[i] <= '0;
                dL_dconic_before_encoder[i] <= '0;
                dL_dopacity_before_encoder[i] <= '0;
                gaussian_id_before_encoder[i] <= '0;
                GID_valid_before_encoder[i] <= '0;


                for (int j = 0; j < majority_adder_stages; j++) begin
                    dL_dcolor_inside_majority_adder[j * num_pixels + i] <= '0;
                    dL_ddepth_inside_majority_adder[j * num_pixels + i] <= '0;
                    dL_dmean2D_inside_majority_adder[j * num_pixels + i] <= '0;
                    dL_dconic_inside_majority_adder[j * num_pixels + i] <= '0;
                    dL_dopacity_inside_majority_adder[j * num_pixels + i] <= '0;
                    gaussian_id_inside_majority_adder[j * num_pixels + i] <= '0;
                    is_majority_gid_inside_majority_adder[j * num_pixels + i] <= '0;
                    GID_valid_inside_majority_adder[j * num_pixels + i] <= '0;
                end
            end

        
            
        end

        else begin

            for (int j = 0; j < Banks; j++) begin
                for (int i = 0; i < num_pixels; i++) begin
                    // encoder와의 Handshake시 신호 처리
                    // if (encoder_valid_in[j * Banks + i] && src_grant_out[j * Banks + i]) begin
                    //     GID_valid_inside_majority_adder[(majority_adder_stages-1) * num_pixels + i] <= 1'b0;
                    // end

                    if (encoder_valid_in[j * Banks + i] && src_grant_out[j * Banks + i]) begin
                        GID_valid_before_encoder[i] <= 1'b0;

                    end                    
                end
                encoder_to_fifo_push_in[j] <= encoder_to_fifo_data_out[j];
                encoder_to_fifo_push_valid_in[j] <= encoder_to_fifo_valid_out[j];
            end

            if (!stall_to_controller) begin

                for (int i = 0; i < num_pixels; i++) begin
                    dL_dcolor_before_majority_voter[i] <= dL_dcolor[i];
                    dL_ddepth_before_majority_voter[i] <= dL_ddepth[i];
                    dL_dmean2D_before_majority_voter[i] <= dL_dmean2D[i];
                    dL_dconic_before_majority_voter[i] <= dL_dconic[i];
                    dL_dopacity_before_majority_voter[i] <= dL_dopacity[i];
                    gaussian_id_before_majority_voter[i] <= gaussian_id[i];
                    GID_valid_before_majority_voter[i] <= GID_valid[i];


                    dL_dcolor_after_majority_voter[i] <= dL_dcolor_before_majority_voter[i];
                    dL_ddepth_after_majority_voter[i] <= dL_ddepth_before_majority_voter[i];
                    dL_dmean2D_after_majority_voter[i] <= dL_dmean2D_before_majority_voter[i];
                    dL_dconic_after_majority_voter[i] <= dL_dconic_before_majority_voter[i];
                    dL_dopacity_after_majority_voter[i] <= dL_dopacity_before_majority_voter[i];
                    gaussian_id_after_majority_voter[i] <= gaussian_id_before_majority_voter[i];
                    GID_valid_after_majority_voter[i] <= GID_valid_before_majority_voter[i];


                    dL_dcolor_inside_majority_adder[i] <= dL_dcolor_after_majority_voter[i];
                    dL_ddepth_inside_majority_adder[i] <= dL_ddepth_after_majority_voter[i];
                    dL_dmean2D_inside_majority_adder[i] <= dL_dmean2D_after_majority_voter[i];
                    dL_dconic_inside_majority_adder[i] <= dL_dconic_after_majority_voter[i];
                    dL_dopacity_inside_majority_adder[i] <= dL_dopacity_after_majority_voter[i];
                    gaussian_id_inside_majority_adder[i] <= gaussian_id_after_majority_voter[i];
                    is_majority_gid_inside_majority_adder[i] <= is_majority_gid[i];
                    GID_valid_inside_majority_adder[i] <= GID_valid_after_majority_voter[i];



                    dL_dcolor_before_encoder[i] <= dL_dcolor_to_encoder[i];
                    dL_ddepth_before_encoder[i] <= dL_ddepth_to_encoder[i];
                    dL_dmean2D_before_encoder[i] <= dL_dmean2D_to_encoder[i];
                    dL_dconic_before_encoder[i] <= dL_dconic_to_encoder[i];
                    dL_dopacity_before_encoder[i] <= dL_dopacity_to_encoder[i];

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
                    end

                end

            end


        end
    end




endmodule