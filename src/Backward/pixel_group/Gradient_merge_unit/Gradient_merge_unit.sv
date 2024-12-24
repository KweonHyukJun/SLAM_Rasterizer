module Gradient_merge_unit #(
    BLOCK_SIZE = 16, 
    exponent_bit = 8, 
    precision = 16, 
    mantissa_bit = 7, 
    num_pixels = 16, 
    GID_bit = 24,
    FIFO_depth = 16) 
    (
    input logic clk,
    input logic rst_n,
    
    input logic [GID_bit-1:0] gaussian_id [num_pixels-1:0],
    input logic [(3*precision)-1:0] dL_dcolor [num_pixels-1:0],
    input logic [precision-1:0] dL_ddepth [num_pixels-1:0],
    input logic [(2*precision)-1:0] dL_dmean2D [num_pixels-1:0],
    input logic [(4*precision)-1:0] dL_dconic [num_pixels-1:0],
    input logic [precision-1:0] dL_dopacity [num_pixels-1:0],

    input logic [GID_bit-1:0] gaussian_id_in [num_pixels-1:0],
    input logic GID_valid [num_pixels-1:0], // gradient_valid_out in Backward_Rasterizer_unit

    input logic stall_backpressure,


    output logic [(3 * precision)-1:0] dL_dcolor_out [num_pixels-1:0],
    output logic [precision-1:0] dL_ddepth_out [num_pixels-1:0],
    output logic [(2 * precision)-1:0] dL_dmean2D_out [num_pixels-1:0],
    output logic [(4 * precision)-1:0] dL_dconic_out [num_pixels-1:0],
    output logic [precision-1:0] dL_dopacity_out [num_pixels-1:0],

    output logic [GID_bit-1:0] gaussian_id_out [num_pixels-1:0],
    output logic GID_valid_out [num_pixels-1:0], 

    output logic stall_to_controller
);

    localparam majority_adder_stages = $clog2(num_pixels) + 1;
    localparam arbiter_and_fifo_data_size = 11 * precision + GID_bit;

    // Wire Declare
    logic is_majority_gid [num_pixels-1:0];

    logic [3 * precision-1:0] majority_dL_dcolor_out ;
    logic [precision-1:0] majority_dL_ddepth_out ;
    logic [2 * precision-1:0] majority_dL_dmean2D_out;
    logic [4 * precision-1:0] majority_dL_dconic_out ;
    logic [precision-1:0] majority_dL_dopacity_out;

    logic majority_valid_out;

    logic [arbiter_and_fifo_data_size-1:0] arbiter_data_in [num_pixels-1:0];

    logic fifo_full [num_pixels-1:0]; // 
    logic fifo_empty [num_pixels-1:0];

    logic [arbiter_and_fifo_data_size-1:0] arbiter_to_fifo_data_in [num_pixels-1:0];

    // Register Declare
    logic [(3 * precision)-1:0] dL_dcolor_after_majority_voter [num_pixels-1:0];
    logic [precision-1:0] dL_ddepth_after_majority_voter [num_pixels-1:0];
    logic [(2 * precision)-1:0] dL_dmean2D_after_majority_voter [num_pixels-1:0];
    logic [(4 * precision)-1:0] dL_dconic_after_majority_voter [num_pixels-1:0];
    logic [precision-1:0] dL_dopacity_after_majority_voter [num_pixels-1:0];
    logic [GID_bit-1:0] gaussian_id_after_majority_voter [num_pixels-1:0];

    logic GID_valid_after_majority_voter [num_pixels-1:0];



    // Majority Adder 내부 stage
    logic [(3 * precision)-1:0] dL_dcolor_inside_majority_adder [1:majority_adder_stages][num_pixels-1:0];
    logic [precision-1:0] dL_ddepth_inside_majority_adder [1:majority_adder_stages][num_pixels-1:0];
    logic [(2 * precision)-1:0] dL_dmean2D_inside_majority_adder [1:majority_adder_stages][num_pixels-1:0];
    logic [(4 * precision)-1:0] dL_dconic_inside_majority_adder [1:majority_adder_stages][num_pixels-1:0];
    logic [precision-1:0] dL_dopacity_inside_majority_adder [1:majority_adder_stages][num_pixels-1:0];

    logic [GID_bit-1:0] gaussian_id_inside_majority_adder [1:majority_adder_stages][num_pixels-1:0];

    logic is_majority_gid_inside_majority_adder [1:majority_adder_stages][num_pixels-1:0];

    logic GID_valid_inside_majority_voter [1:majority_adder_stages][num_pixels-1:0];




    majority_voter #(
        .num_pixels(num_pixels),
        .GID_bit(GID_bit)
    )
    majority_voter_inst (
    .clk(clk),
    .rst_n(rst_n),

    .gaussian_id(gaussian_id_in),
    .GID_valid(GID_valid),
    .stall_backpressure(stall_backpressure),

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

        .stall_backpressure(stall_backpressure),

        .majority_dL_dcolor_out(majority_dL_dcolor_out),
        .majority_dL_ddepth_out(majority_dL_ddepth_out),
        .majority_dL_dmean2D_out(majority_dL_dmean2D_out),
        .majority_dL_dconic_out(majority_dL_dconic_out),
        .majority_dL_dopacity_out(majority_dL_dopacity_out),

        .majority_valid_out(majority_valid_out)
    );
    
    


    genvar k;
    generate
        for (k = 0; k < num_pixels; k++) begin : aribtration
            // Problem: The signals are declared as 2D arrays [stage][pixel] but we're trying to do bit selection
            // which isn't valid for 2D arrays. We need to concatenate the full signals without bit selection.
            assign arbiter_data_in[k] = {
                dL_dcolor_inside_majority_adder[majority_adder_stages][k],
                dL_ddepth_inside_majority_adder[majority_adder_stages][k],
                dL_dmean2D_inside_majority_adder[majority_adder_stages][k],
                dL_dconic_inside_majority_adder[majority_adder_stages][k],
                dL_dopacity_inside_majority_adder[majority_adder_stages][k],

                gaussian_id_inside_majority_adder[majority_adder_stages][k]
                // is_majority_gid_inside_majority_adder[majority_adder_stages][k] 이거는 valid 신호로 사용
            };

            // rr arbiter 입력에 GID % bank와 Valid 신호에 대한 조건을 추가해야 함.

            round_robin_arbiter #( // 각 i가 SRAM Bank의 i
                .N_MASTER(num_pixels),
                .DATA_SIZE(arbiter_and_fifo_data_size)
            )
            round_robin_arbiter_inst (
                .clk(clk),
                .rst_n(rst_n),

                .src_valid_i(!is_majority_gid_inside_majority_adder[majority_adder_stages][k] && GID_valid_inside_majority_voter[majority_adder_stages][k]),
                .src_ready_o(!stall_backpressure),
                .src_data_i(arbiter_data_in),

                .dst_valid_o(), 
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
                .write_valid_in(),

                .read_valid_in(),
                .read_data_out(),

                .full_out(fifo_full[k]),
                .empty_out(fifo_empty[k])
            );
        end


    endgenerate




    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < num_pixels; i++) begin
                dL_dcolor_after_majority_voter[i] <= 0;
                dL_ddepth_after_majority_voter[i] <= 0;
                dL_dmean2D_after_majority_voter[i] <= 0;
                dL_dconic_after_majority_voter[i] <= 0;
                dL_dopacity_after_majority_voter[i] <= 0;
                GID_valid_after_majority_voter[i] <= 0;
                gaussian_id_after_majority_voter[i] <= 0;

                for (int j = 1; j <= majority_adder_stages; j++) begin
                    dL_dcolor_inside_majority_adder[j][i] <= 0;
                    dL_ddepth_inside_majority_adder[j][i] <= 0;
                    dL_dmean2D_inside_majority_adder[j][i] <= 0;
                    dL_dconic_inside_majority_adder[j][i] <= 0;
                    dL_dopacity_inside_majority_adder[j][i] <= 0;
                    is_majority_gid_inside_majority_adder[j][i] <= 0;
                end
            end

        end
    end




endmodule