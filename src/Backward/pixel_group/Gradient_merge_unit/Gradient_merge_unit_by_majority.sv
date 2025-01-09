module Gradient_merge_unit_by_majority #(
    parameter BLOCK_SIZE = 16, 
    parameter exponent_bit = 8, 
    parameter precision = 16, 
    parameter mantissa_bit = 7, 
    parameter num_pixels = 16, 
    parameter GID_bit = 24,
    parameter FIFO_depth = 16,
    parameter arbiter_and_fifo_data_size = 11 * precision + GID_bit,
    parameter Banks = 16
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
    output logic [arbiter_and_fifo_data_size-1:0] FIFO_pop_out       [Banks-1:0],


    // // Control Signal
    output logic stall_to_controller
);

    localparam majority_adder_stages = $clog2(num_pixels) + 1;
    // localparam arbiter_and_fifo_data_size = 11 * precision + GID_bit;


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

    logic [arbiter_and_fifo_data_size-1:0]  arbiter_data_in         [Banks * num_pixels-1:0];
    logic                                   arbiter_valid_in   [Banks * num_pixels-1:0];


    logic fifo_full [num_pixels-1:0]; // 
    logic fifo_empty [Banks-1:0];

    logic [arbiter_and_fifo_data_size-1:0] arbiter_to_fifo_data_out [num_pixels-1:0];
    logic arbiter_to_fifo_valid_out [num_pixels-1:0];


    logic stall_from_arbiter [num_pixels-1:0];

    logic src_ready_out [num_pixels * Banks-1:0];
    

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


    // before arbiter (수정용)

    logic [3*precision-1:0]     dL_dcolor_before_arbiter    [num_pixels - 1:0];
    logic [precision-1:0]       dL_ddepth_before_arbiter    [num_pixels - 1:0];
    logic [(2*precision)-1:0]   dL_dmean2D_before_arbiter   [num_pixels - 1:0];
    logic [(4*precision)-1:0]   dL_dconic_before_arbiter    [num_pixels - 1:0];
    logic [precision-1:0]       dL_dopacity_before_arbiter  [num_pixels - 1:0];

    logic [GID_bit-1:0]         gaussian_id_before_arbiter    [num_pixels-1:0];

    logic                       GID_valid_before_arbiter    [num_pixels-1:0];


    logic arbiter_to_fifo_push_valid_in [num_pixels-1:0];
    logic [arbiter_and_fifo_data_size-1:0] arbiter_to_fifo_push_in [num_pixels-1:0];

    
    //////////////////////////////////////
    ///////// Combinational Register //////
    //////////////////////////////////////

    logic majority_index_found;

    logic stall_from_arbiter_comb;
    logic stall_from_fifo_comb;
    

    logic [3*precision-1:0]     dL_dcolor_to_arbiter    [num_pixels-1:0];
    logic [precision-1:0]       dL_ddepth_to_arbiter    [num_pixels-1:0];
    logic [(2*precision)-1:0]   dL_dmean2D_to_arbiter   [num_pixels-1:0];
    logic [(4*precision)-1:0]   dL_dconic_to_arbiter    [num_pixels-1:0];
    logic [precision-1:0]       dL_dopacity_to_arbiter  [num_pixels-1:0];

    logic                       valid_gradient_to_pass_arbiter [num_pixels-1:0];

    logic                       GID_valid_to_arbiter_reg [num_pixels-1:0];
    
    

    always_comb begin
        stall_from_arbiter_comb = 0;
        stall_from_fifo_comb = 0;
        

        for (int i = 0; i < Banks; i++) begin
            stall_from_arbiter_comb = stall_from_arbiter_comb || stall_from_arbiter[i];
            stall_from_fifo_comb = stall_from_fifo_comb || fifo_full[i];
        end

        // stall_to_controller_next = stall_from_arbiter_comb || stall_from_fifo_comb || stall_backpressure;
    
    end

    assign stall_to_controller = stall_from_arbiter_comb || stall_from_fifo_comb || stall_backpressure;


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
                dL_dcolor_to_arbiter[l] = dL_dcolor_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_ddepth_to_arbiter[l] = dL_ddepth_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_dmean2D_to_arbiter[l] = dL_dmean2D_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_dconic_to_arbiter[l] = dL_dconic_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_dopacity_to_arbiter[l] = dL_dopacity_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];

                valid_gradient_to_pass_arbiter[l] = GID_valid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];

                GID_valid_to_arbiter_reg[l] = GID_valid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
            end 

            else begin
                // Is a majority index
                if (majority_valid_out && !majority_index_found && 
                    GID_valid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l]) begin
                    // First valid majority index found
                    majority_index_found = 1'b1;
                    dL_dcolor_to_arbiter[l] = majority_dL_dcolor_out;
                    dL_ddepth_to_arbiter[l] = majority_dL_ddepth_out;
                    dL_dmean2D_to_arbiter[l] = majority_dL_dmean2D_out;
                    dL_dconic_to_arbiter[l] = majority_dL_dconic_out;
                    dL_dopacity_to_arbiter[l] = majority_dL_dopacity_out;

                    GID_valid_to_arbiter_reg[l] = 1'b1;
                    valid_gradient_to_pass_arbiter[l] = 1'b1;
                end 
                else begin
                    // Zero out all other majority indices
                    dL_dcolor_to_arbiter[l] = 'h0;
                    dL_ddepth_to_arbiter[l] = 'h0;
                    dL_dmean2D_to_arbiter[l] = 'h0;
                    dL_dconic_to_arbiter[l] = 'h0;
                    dL_dopacity_to_arbiter[l] = 'h0;

                    GID_valid_to_arbiter_reg[l] = 1'b0;
                    valid_gradient_to_pass_arbiter[l] = 1'b0;
                end
            end
        end
    end


    genvar k, m;
    generate
        for (k = 0; k < Banks; k = k + 1) begin : aribtration_and_fifo

            // Problem: The signals are declared as 2D arrays [stage][pixel] but we're trying to do bit selection
            // which isn't valid for 2D arrays. We need to concatenate the full signals without bit selection.
            for (m = 0; m < num_pixels; m = m + 1) begin : arbiter_data_in_concatenation
                // assign arbiter_data_in[k * Banks + m] = (gaussian_id_inside_majority_adder[(majority_adder_stages-1) * num_pixels + m][$clog2(num_pixels)-1:0] == k) ? 

                // {
                //     dL_dcolor_to_arbiter[m],
                //     dL_ddepth_to_arbiter[m],
                //     dL_dmean2D_to_arbiter[m],
                //     dL_dconic_to_arbiter[m],
                //     dL_dopacity_to_arbiter[m],

                //     gaussian_id_inside_majority_adder[(majority_adder_stages-1) * num_pixels + m]
                    
                // } : 'h0;

                // assign arbiter_valid_in[k * Banks + m] = ((gaussian_id_inside_majority_adder[(majority_adder_stages-1) * num_pixels + m][$clog2(num_pixels)-1:0] == k) 
                //                                             && valid_gradient_to_pass_arbiter[m] 
                //                                             && GID_valid_inside_majority_adder[(majority_adder_stages-1) * num_pixels + m]);


                assign arbiter_data_in[k * Banks + m] = (gaussian_id_before_arbiter[m][$clog2(num_pixels)-1:0] == k) ? 

                {
                    dL_dcolor_before_arbiter[m],
                    dL_ddepth_before_arbiter[m],
                    dL_dmean2D_before_arbiter[m],
                    dL_dconic_before_arbiter[m],
                    dL_dopacity_before_arbiter[m],

                    gaussian_id_before_arbiter[m]
                } : 'h0;

                assign arbiter_valid_in[k * Banks + m] = ((gaussian_id_before_arbiter[m][$clog2(num_pixels)-1:0] == k) 
                                                            // && valid_gradient_to_pass_arbiter[m] 
                                                            && GID_valid_before_arbiter[m]);

            end

            round_robin_arbiter #( // 각 k가 SRAM Bank의 k
                .N_MASTER(num_pixels),
                .DATA_SIZE(arbiter_and_fifo_data_size)
            )
            round_robin_arbiter_inst (
                .clk(clk),
                .rst_n(rst_n),

                
                .src_valid_i(arbiter_valid_in[k * Banks +: Banks]),
                .src_ready_o(src_ready_out[k * Banks +: Banks]),
                .src_data_i(arbiter_data_in[k * Banks +: Banks]),

                .dst_valid_o(arbiter_to_fifo_valid_out[k]), 
                .dst_ready_i(!fifo_full[k]), // FIFO
                .dst_data_o(arbiter_to_fifo_data_out[k]),

                .stall_backpressure(stall_backpressure),
                .stall_from_arbiter(stall_from_arbiter[k])
            );

            // Arbiter와 FIFO 사이 FF 처리 

            // FIFO #(
            //     .FIFO_depth(FIFO_depth),
            //     .input_data_width(arbiter_and_fifo_data_size),
            //     .output_data_width(arbiter_and_fifo_data_size)
            // )
            // FIFO_inst (
            //     .clk(clk),
            //     .rst_n(rst_n),

            //     .write_data_in(arbiter_to_fifo_write_data_in[k]),
            //     .write_valid_in(arbiter_to_fifo_write_valid_in[k]),

            //     .read_valid_in(FIFO_read_valid_in[k]), 
            //     .read_data_out(FIFO_read_out[k]),

            //     .full_out(fifo_full[k]), // stall_from_fifo
            //     .empty_out(fifo_empty[k])
            // );

            push_pop_FIFO #(
                .FIFO_depth(FIFO_depth),
                .input_data_width(arbiter_and_fifo_data_size),
                .output_data_width(arbiter_and_fifo_data_size)
            )
            FIFO_inst (
                .clk(clk),
                .rst_n(rst_n),

                .push_data_in(arbiter_to_fifo_push_in[k]),
                .push_valid_in(arbiter_to_fifo_push_valid_in[k]),

                .pop_valid_in(FIFO_pop_valid_in[k]), 
                .pop_data_out(FIFO_pop_out[k]),

                .full_out(fifo_full[k]), // stall_from_fifo
                .empty_out(fifo_empty[k])
            );



            assign FIFO_pop_ready_out[k] = !fifo_empty[k];
            assign FIFO_GID_out[k] = FIFO_pop_out[k][GID_bit-1:0];
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

                dL_dcolor_before_arbiter[i] <= '0;
                dL_ddepth_before_arbiter[i] <= '0;
                dL_dmean2D_before_arbiter[i] <= '0;
                dL_dconic_before_arbiter[i] <= '0;
                dL_dopacity_before_arbiter[i] <= '0;
                gaussian_id_before_arbiter[i] <= '0;
                GID_valid_before_arbiter[i] <= '0;


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
                    // Arbiter와의 Handshake시 신호 처리
                    // if (arbiter_valid_in[j * Banks + i] && src_ready_out[j * Banks + i]) begin
                    //     GID_valid_inside_majority_adder[(majority_adder_stages-1) * num_pixels + i] <= 1'b0;
                    // end

                    if (arbiter_valid_in[j * Banks + i] && src_ready_out[j * Banks + i]) begin
                        GID_valid_before_arbiter[i] <= 1'b0;

                    end                    
                end
                arbiter_to_fifo_push_in[j] <= arbiter_to_fifo_data_out[j];
                arbiter_to_fifo_push_valid_in[j] <= arbiter_to_fifo_valid_out[j];
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



                    dL_dcolor_before_arbiter[i] <= dL_dcolor_to_arbiter[i];
                    dL_ddepth_before_arbiter[i] <= dL_ddepth_to_arbiter[i];
                    dL_dmean2D_before_arbiter[i] <= dL_dmean2D_to_arbiter[i];
                    dL_dconic_before_arbiter[i] <= dL_dconic_to_arbiter[i];
                    dL_dopacity_before_arbiter[i] <= dL_dopacity_to_arbiter[i];

                    gaussian_id_before_arbiter[i] <= gaussian_id_inside_majority_adder[(majority_adder_stages-1) * num_pixels + i];
                    GID_valid_before_arbiter[i] <= GID_valid_to_arbiter_reg[i];


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