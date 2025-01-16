// 픽셀마다 초기값 기입 및 Gaussian 입력 처리
module Group_to_Pixel_controller 
    #(
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 7,
        parameter precision = 16,
        parameter gaussian_inputs = 3, // in one pixel unit, gaussians
        parameter num_pixels = 16, // number of pixel units
        parameter GID_bit = 24,
        parameter N_CONTRIB_bit = 24,
        parameter WINDOW_SIZE = 32
    )
    
    (
        input wire clk,
        input wire rst_n,

        // Input from Group Controller
        input wire [11:0] W_from_group,
        input wire [11:0] H_from_group,
        input wire [15:0] block_id_from_group,
        input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] start_pixel_id_from_group,
        input wire start_from_group,

        // 그 Block의 Gaussian의 범위
        input wire [11:0] ranges_from_group,

        input wire [10 * precision - 1:0] new_window_from_group [WINDOW_SIZE-1:0],
        input wire [11:0] first_window_index,
        input wire new_window_from_group_valid,

        
        // 확인 필요
        input wire [(3 * precision) - 1:0] dL_dpixel_from_group [num_pixels-1:0],
        input wire [precision - 1:0] dL_dpixel_depth_from_group [num_pixels-1:0],
        input wire [precision - 1:0] T_first_from_group [num_pixels-1:0],

        // Input from SRAM
        input wire [N_CONTRIB_bit - 1:0] n_contrib_from_SRAM [num_pixels-1:0],


        // Output to Group Controller & Memory Controller
        output wire window_size_full [num_pixels-1:0],
        output wire done_from_pixel,



        // Input from Backward Rasterizer Unit
        input wire stall_from_rasterizer [num_pixels-1:0],

        // Output to Backward Rasterizer Unit
        output reg start_to_rasterizer [num_pixels-1:0],
        output reg i_valid_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg last_input_done_to_rasterizer [num_pixels-1:0],

        output reg [11:0] W_to_rasterizer [num_pixels-1:0],
        output reg [11:0] H_to_rasterizer [num_pixels-1:0],

        output reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id_to_rasterizer [num_pixels-1:0],
        output reg [15:0] block_id_to_rasterizer [num_pixels-1:0],

        output reg [(3 * precision) - 1:0] dL_dpixel_to_rasterizer [num_pixels-1:0],
        output reg [precision - 1:0] dL_dpixel_depth_to_rasterizer [num_pixels-1:0],
        output reg [precision - 1:0] T_first_to_rasterizer [num_pixels-1:0],

        output reg stall_backpressure_to_rasterizer [num_pixels-1:0]
    );

    //////////////////////// State ////////////////////////
    localparam  IDLE = 2'd0,
                NOT_STARTED_BUSY = 2'd1,
                STARTED_BUSY = 2'd2,
                WINDOW_UPDATE_REQUIRED = 2'd3;

    //////////////////////// FF Register ////////////////////////

        // Out Register
        reg [1:0] state [num_pixels-1:0];
        

        // Next State
        reg [1:0] state_next [num_pixels-1:0];
        

        // Internal Signal
        reg [N_CONTRIB_bit - 1:0] n_contrib [num_pixels-1:0];
        // reg started [num_pixels-1:0];


    //////////////////////// Comb Register ////////////////////////

    //////////////////////// Wire Register ////////////////////////

    //////////////////////// Others ////////////////////////
    integer i, j;

    always_ff @(posedge clk) begin
        if (!rst_n) begin

            for (i = 0; i < num_pixels; i = i + 1) begin
                // started[i] <= 1'b0;
                state[i] <= IDLE;
                n_contrib[i] <= 'h0;
            end

        end

        else begin
            for (i = 0; i < num_pixels; i = i + 1) begin
                if (!stall_from_rasterizer[i]) begin
                    state[i] <= state_next[i];

                    // if (!started[i]) begin
                    //     if (start_to_rasterizer[i]) begin
                    //         started[i] <= 1'b1;
                    //     end
                    // end

                    // else begin
                    //     if (last_input_done_to_rasterizer[i]) begin
                    //         started[i] <= 1'b0;
                    //     end
                    // end

                end

            end
        end
    end


    always_comb begin
        integer idx;

        for (idx = 0; idx < num_pixels; idx = idx + 1) begin
            state_next[idx] = state[idx];
        
            case (state[idx])
                IDLE: begin
                    if (start_from_group) begin
                        state_next[idx] = NOT_STARTED_BUSY;
                    end
                end

                NOT_STARTED_BUSY: begin //픽셀 초기값 + 초기 윈도우 받아야함
                    if (start_to_rasterizer[idx]) begin
                        state_next[idx] = STARTED_BUSY;
                    end
                end

                STARTED_BUSY: begin // 정상 작동중 , 윈도우 필요조건시 충돌 생각해서 state 정해야 함.
                    if (last_input_done_to_rasterizer[idx]) begin
                        state_next[idx] = IDLE;
                    end

                    else if (window_size_full[idx]) begin // 이 한 pixel controller만 바뀌는거지 window 바뀌는 조건은 다시 봐야함
                        state_next[idx] = WINDOW_UPDATE_REQUIRED;
                        
                    end
                end

                WINDOW_UPDATE_REQUIRED: begin // 윈도우 업데이트 필요
                    if (new_window_from_group_valid) begin
                        state_next[idx] = STARTED_BUSY;
                    end
                end



                default: begin 
                    state_next[idx] = state[idx];
                end

            endcase

        end
    end

    genvar k;
    generate    
        for (k = 0; k < num_pixels; k = k + 1) begin
            assign window_size_full[k] =  ; //  window size가 full이어도, 픽셀 Queue에 따라 다르게 끔
        end
    endgenerate


endmodule