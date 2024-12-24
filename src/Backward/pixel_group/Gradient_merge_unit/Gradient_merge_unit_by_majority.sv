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

    input logic [GID_bit-1:0]       gaussian_id_in      [num_pixels-1:0],
    input logic                     GID_valid           [num_pixels-1:0], // gradient_valid_out in Backward_Rasterizer_unit

    input logic                     stall_backpressure,

    input logic                     FIFO_read_valid_in  [num_pixels-1:0], // 컨트롤러 입력


    // // Input From SRAM
    // input logic [arbiter_and_fifo_data_size-1:0] data_from_SRAM [num_pixels-1:0], // Bank마다 들어옴
    // input logic valid_from_SRAM [num_pixels-1:0],



    // Output To Read SRAM GID
    output logic                    GID_valid_out       [num_pixels-1:0], 
    output logic                    FIFO_GID_out        [num_pixels-1:0],

    // // Output To Write SRAM
    // output logic [arbiter_and_fifo_data_size-1:0] data_to_SRAM [num_pixels-1:0],
    // output logic valid_to_SRAM [num_pixels-1:0],

    // output logic [(3 * precision)-1:0] dL_dcolor_out [num_pixels-1:0],
    // output logic [precision-1:0] dL_ddepth_out [num_pixels-1:0],
    // output logic [(2 * precision)-1:0] dL_dmean2D_out [num_pixels-1:0],
    // output logic [(4 * precision)-1:0] dL_dconic_out [num_pixels-1:0],
    // output logic [precision-1:0] dL_dopacity_out [num_pixels-1:0],

    // output logic [GID_bit-1:0] gaussian_id_out [num_pixels-1:0],
    // output logic GID_valid_out [num_pixels-1:0], 

    // // Control Signal
    output logic stall_to_controller



    // output logic FIFO_read_out [num_pixels-1:0]
);

    localparam majority_adder_stages = $clog2(num_pixels) + 1;
    // localparam arbiter_and_fifo_data_size = 11 * precision + GID_bit;

    // Wire Declare
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
    logic fifo_empty [num_pixels-1:0];

    logic [arbiter_and_fifo_data_size-1:0] arbiter_to_fifo_data_in [num_pixels-1:0];
    logic arbiter_to_fifo_valid_in [num_pixels-1:0];


    logic stall_from_arbiter [num_pixels-1:0];
    

    // FF Register Declare

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


    


    // Combinational Register Declare
    logic Majority_Added_valid_comb;
    logic majority_index_found;

    logic stall_from_arbiter_comb;
    logic stall_from_fifo_comb;
    logic stall_to_controller_now;

    logic [3*precision-1:0]     dL_dcolor_to_arbiter    [num_pixels-1:0];
    logic [precision-1:0]       dL_ddepth_to_arbiter    [num_pixels-1:0];
    logic [(2*precision)-1:0]   dL_dmean2D_to_arbiter   [num_pixels-1:0];
    logic [(4*precision)-1:0]   dL_dconic_to_arbiter    [num_pixels-1:0];
    logic [precision-1:0]       dL_dopacity_to_arbiter  [num_pixels-1:0];

    logic                       arbiter_valid_in_comb [num_pixels-1:0];
    
    

    always_comb begin
        stall_from_arbiter_comb = 0;
        stall_from_fifo_comb = 0;
        

        for (int i = 0; i < Banks; i++) begin
            stall_from_arbiter_comb = stall_from_arbiter_comb || stall_from_arbiter[i];
            stall_from_fifo_comb = stall_from_fifo_comb || fifo_full[i];
        end

        // stall_to_controller_next = stall_from_arbiter_comb || stall_from_fifo_comb || stall_backpressure;
        stall_to_controller_now = stall_from_arbiter_comb || stall_from_fifo_comb || stall_backpressure;
    end



    majority_voter #(
        .num_pixels(num_pixels),
        .GID_bit(GID_bit)
    )
    majority_voter_inst (
    .clk(clk),
    .rst_n(rst_n),

    .gaussian_id(gaussian_id_before_majority_voter),
    .GID_valid(GID_valid_before_majority_voter),
    .stall_backpressure(stall_to_controller_now),

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

        .stall_backpressure(stall_to_controller_now),

        .majority_dL_dcolor_out(majority_dL_dcolor_out),
        .majority_dL_ddepth_out(majority_dL_ddepth_out),
        .majority_dL_dmean2D_out(majority_dL_dmean2D_out),
        .majority_dL_dconic_out(majority_dL_dconic_out),
        .majority_dL_dopacity_out(majority_dL_dopacity_out),

        .majority_valid_out(majority_valid_out)
    );
    

    // // Majority인 값 중에서 Added 된 값 처리
    genvar l;
    generate 
        
        // Majority인 INDEX 확인
        always_comb begin
            majority_index_found = 1'b0;

            

            for (l = 0; l < num_pixels; l++) begin : majority_index_finder

                // 기본값 : Majority가 존재하지 않을 때 Clock FF 값으로 초기화

                dL_dcolor_to_arbiter[l] = dL_dcolor_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_ddepth_to_arbiter[l] = dL_ddepth_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_dmean2D_to_arbiter[l] = dL_dmean2D_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_dconic_to_arbiter[l] = dL_dconic_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];
                dL_dopacity_to_arbiter[l] = dL_dopacity_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];

                arbiter_valid_in_comb[l] = is_majority_gid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l] || GID_valid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l];

                // Majority가 존재, 첫 index시 합의 값을 덮어씀
                if (!majority_index_found && majority_valid_out && is_majority_gid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l]) begin
                    majority_index_found = 1'b1;

                    dL_dcolor_to_arbiter[l] = majority_dL_dcolor_out;
                    dL_ddepth_to_arbiter[l] = majority_dL_ddepth_out;
                    dL_dmean2D_to_arbiter[l] = majority_dL_dmean2D_out;
                    dL_dconic_to_arbiter[l] = majority_dL_dconic_out;
                    dL_dopacity_to_arbiter[l] = majority_dL_dopacity_out;

                    arbiter_valid_in_comb[l] = 1'b1;
                end

                // Majority가 존재하고, 첫 index가 아닐 때 0으로 초기화
                else if (majority_index_found && majority_valid_out && !is_majority_gid_inside_majority_adder[(majority_adder_stages - 1) * num_pixels + l]) begin

                    dL_dcolor_to_arbiter[l] = 'h0;
                    dL_ddepth_to_arbiter[l] = 'h0;
                    dL_dmean2D_to_arbiter[l] = 'h0;
                    dL_dconic_to_arbiter[l] = 'h0;
                    dL_dopacity_to_arbiter[l] = 'h0;

                    arbiter_valid_in_comb[l] = 1'b0;
                end

            end
        end
    endgenerate





    genvar k, m;
    generate
        for (k = 0; k < Banks; k = k + 1) begin : aribtration

            // Problem: The signals are declared as 2D arrays [stage][pixel] but we're trying to do bit selection
            // which isn't valid for 2D arrays. We need to concatenate the full signals without bit selection.
            for (m = 0; m < num_pixels; m = m + 1) begin : arbiter_data_in_concatenation
                assign arbiter_data_in[k * Banks + m] = (gaussian_id_inside_majority_adder[(majority_adder_stages-1) * num_pixels + m][$clog2(num_pixels)-1:0] == k) ? 

                {
                    dL_dcolor_to_arbiter[m],
                    dL_ddepth_to_arbiter[m],
                    dL_dmean2D_to_arbiter[m],
                    dL_dconic_to_arbiter[m],
                    dL_dopacity_to_arbiter[m],

                    gaussian_id_inside_majority_adder[(majority_adder_stages-1) * num_pixels + m]
                    // is_majority_gid_inside_majority_adder[majority_adder_stages][k] 이거는 valid 신호로 사용
                } : 'h0;

                assign arbiter_valid_in[k * Banks + m] = (gaussian_id_inside_majority_adder[(majority_adder_stages-1) * num_pixels + m][$clog2(num_pixels)-1:0] == k) && arbiter_valid_in_comb[m];
            end


            // rr arbiter 입력에 GID % bank와 Valid 신호에 대한 조건을 추가해야 함.

            round_robin_arbiter #( // 각 i가 SRAM Bank의 i
                .N_MASTER(num_pixels),
                .DATA_SIZE(arbiter_and_fifo_data_size)
            )
            round_robin_arbiter_inst (
                .clk(clk),
                .rst_n(rst_n),

                // .src_valid_i(!is_majority_gid_inside_majority_adder[majority_adder_stages][k] && GID_valid_inside_majority_voter[majority_adder_stages][k] && (gaussian_id_inside_majority_adder[majority_adder_stages][k][$clog2(num_pixels)-1:0] == k)),
                .src_valid_i(arbiter_valid_in[k * Banks +: Banks]),
                .src_ready_o(!stall_from_arbiter[k]),
                .src_data_i(arbiter_data_in[k * Banks +: Banks]),

                .dst_valid_o(arbiter_to_fifo_valid_in[k]), 
                .dst_ready_i(!fifo_full[k]), // FIFO
                .dst_data_o(arbiter_to_fifo_data_in[k])
            );


            FIFO #(
                .FIFO_depth(FIFO_depth),
                .input_data_width(arbiter_and_fifo_data_size),
                .output_data_width(arbiter_and_fifo_data_size)
            )
            FIFO_inst (
                .clk(clk),
                .rst_n(rst_n),

                .write_data_in(arbiter_to_fifo_data_in[k]),
                .write_valid_in(arbiter_to_fifo_valid_in[k]),

                .read_valid_in(FIFO_read_valid_in[k]), 
                .read_data_out(FIFO_read_out[k]),

                .full_out(fifo_full[k]), // stall_from_fifo
                .empty_out(fifo_empty[k])
            );
        end
    endgenerate




    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            
        end

        else begin

        end
    end




endmodule