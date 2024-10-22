module Top_module #(
    parameter max_num_rendered = 500000,  // point list에 사용되는 Block 마다 depth 기준 복제된 Gaussian의 총 수로 사용됩니다.  Replica Dataset 기준 최대 450k 여서 넉넉히 500k로 설정했습니다.
    parameter max_blocks = 8160, // 1920 x 1080 에 Block마다 16x16 픽셀이라고 가정 시 최대의 block 수 (120 * 67.5 -> 68) = (120 * 68) = 8160
    parameter max_num_gaussian = 200000, //

    parameter precision = 24,
    parameter mantissa_bit = 15,
    parameter exponent_bit = 8,

    parameter max_W = 1920,
    parameter max_H = 1080,
    parameter num_BLOCK_CTRL = 8,
    parameter BLOCK_SIZE = 16,
    
    parameter group_gaussian = 32

)
(
    // input은 wire, output은 reg로 통일하겠습니다

    input wire clk,
    input wire rst_n,

    ////////////////////////////////////////////////////
    /////////// Communication to Memory Ctrl ///////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    //////// From Memory Ctrl ////////
    //////////////////////////////////
    input wire [11:0]                       W_from_memory,                                                                  // 최대 1920 x 1080 기준으로 할때 2048인 2^11 기준 (혹시 몰라서 1비트 추가한 11비트로 W, H 책정했습니다)
    input wire [11:0]                       H_from_memory,

    input wire [31:0]                       point_list_from_memory      [max_num_rendered-1:0],                                 // int 32, 전체 Gaussian에 대해서 순서 정렬된 정보 [(block 1 내부 depth로 인한 순서 ~) ,  (block 2 내부 depth로 인한 순서 ~) ...] 이런식으로 block마다의 depth 기준 정렬된 Gaussian ID만 들어있음
                                                                                                                            // 이 (block 1 내부 depth로 인한 순서 ~) 의 범위는 ranges라는 함수로 (카메라 제일 가까운 depth ~ 카메라 가장 먼 depth)의 index 범위값 저장 ex) Block 0은 [0 ~ 548] , Block 1는 [549 ~ 810] 이면
                                                                                                                            // ranges[0] = [0, 548] , ranges[1] = [549,810] 이고, point_list[0] = 0x00001579 이런식으로 Gaussian의 ID 가 저장되어 있습니다. 
                                                                                                                            // SLAM_Rasterizer/verif/hex/fp32/gaussian_id.hex에 한 Block의 Gaussian ID의 값을 저장해 놨습니다.

    input wire [63:0]                       ranges_from_memory          [max_blocks-1:0],                                   // INT32, 각 block당 사용하는 gaussian의 범위 (Forward 단에서 depth 기준으로 정리한 gaussian의 depth 와 id로 구성되어 있습니다.) 

    ////////////////////////////
    /// Gaussian 단위 Input ////
    ////////////////////////////
    input wire [(2 * precision) - 1 : 0]    mean2D_from_memory          [max_num_gaussian-1:0],                                 // FP16 Target, bit size precision * 2는 각각 MSB 부터 projection한 x, y값 () , Forward preprocess에서 정의

    input wire [(4 * precision) - 1 : 0]    conic_opacity_from_memory   [max_num_gaussian-1:0],                                 // FP16 Target, bit size precision * 4는 각각 MSB 부터 conic opacity x, y, z, w값,  Forward preprocess에서 정의

    input wire [(3 * precision) - 1 : 0]    gaussian_color_from_memory  [max_num_gaussian-1:0],                                 // FP16 Target, bit size precision * 3은 각각 MSB 부터 Gaussian color R, G ,B값,  Forward preprocess에서 정의

    input wire [precision - 1 : 0]          gaussian_depth_from_memory  [max_num_gaussian-1:0],                                 // FP16 Target, Gaussian Depth 값 , Forward preprocess에서 정의

    //////////////////////////
    //// Pixel 단위 Input ////
    //////////////////////////
    input wire [precision-1 : 0]            final_Ts_from_memory        [(max_H * max_W) - 1:0],                            // FP16 Target, Forward Render에서 최종 Transmittance 값 (1 - 최종 opacity)

    input wire [31:0]                       n_contrib_from_memory       [(max_H * max_W) - 1:0],                            // INT32, Forward Render에서 각 타일에 입힌 Gaussian의 수, skip도 같이 세어서 숫자가 큼 (PPT에 보여드린 히트맵 중 800~1200에 해당되는 큰 값),
                                                                                                                            // CUDA 함수에서 한 Block은 끝날때까지 공유하기 때문에 시작점으로 사용 가능 (Range의 담긴 값이) 0 ~ 1300이면 n_contrib이 타일마다 100 ~ 700이면, backward 특성상 1300 -> 0을 계산해야 하므로, 이 n_contrib 값으로 시작 위치를 조정해야함. 
                                                                                                                            // 안 그러면 Gaussian index가 벗어나서 Pixel Unit에서 Gradient를 계산하지 않아야 하는데 (skip = 1), Gaussian 값 자체로 인한 skip = 0이 뜨는 경우가 생겨서 필수적으로 이 값을 사용해서 조정해야 합니다.

    input wire [(3 * precision) - 1 : 0]    dL_dpixel_from_memory       [(max_H * max_W) - 1:0],                            // FP16 Target, Loss RGB 함수에서 오는 gradient로 추정. bit size precision * 3은 각각 MSB 부터 Gaussian color R, G ,B값이고, 특징으로는 절댓값은 같고 부호가 다른 경우입니다 (-0.000015 ,0.000015, 0.000015) 이런 느낌의 값이 주로 보였습니다
    input wire [precision - 1 : 0]          dL_dpixel_depth_from_memory [(max_H * max_W) - 1:0],                            // FP16 Target, Loss depth 함수에서 오는 gradient로 추정. 
    
    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    input wire                              gaussian_valid_from_memory,
    input wire                              gradient_ready_from_memory,



    //////////////////////////////////
    ///////// To Memory Ctrl /////////
    //////////////////////////////////
    
    // Input과 gradient의 순서를 동일하게 설정하고 추가 변수는 그 밑에 작성하였습니다.

    //////////////////////////
    //// Gradient 값 반환 /////
    //////////////////////////
    output reg [(2 * precision) - 1 : 0]    dL_dmean2D_to_memory        [max_num_gaussian-1:0],                                 // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함, CUDA backward에서는 3차원으로 처리하는데, 실질적으로 사용은 (backward preprocess를 봐도) x,y 두 차원만 해서 2 * precision으로 했습니다.
    output reg [(4 * precision) - 1 : 0]    dL_dconic_to_memory         [max_num_gaussian-1:0],                                 // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함
    output reg [(3 * precision) - 1 : 0]    dL_dcolor_to_memory         [max_num_gaussian-1:0],                                 // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함
    output reg [precision - 1 : 0]          dL_ddepth_to_memory         [max_num_gaussian-1:0],                                 // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함

    output reg [precision - 1 : 0]          dL_dopacity_to_memory       [max_num_gaussian-1:0],                                 // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함


    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    output reg                              gaussian_ready_to_memory,
    output reg                              gradient_valid_to_memory,




    ////////////////////////////////////////////////////
    /////////// Communication to Block Ctrl ////////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    ///////// To Block Ctrl //////////
    //////////////////////////////////

    // Block에 들어가는 point_list와 range의 평균 크기를 구해서 변경하는 걸 목표로
    output reg [31:0]                       point_list_to_block             [max_num_rendered-1:0],                             // int 32, 전체 Gaussian에 대해서 순서 정렬된 정보 [(block 1 내부 depth로 인한 순서 ~) ,  (block 2 내부 depth로 인한 순서 ~) ...] 이런식으로 block마다의 depth 기준 정렬된 Gaussian ID만 들어있음
                                                                                                                            // 이 (block 1 내부 depth로 인한 순서 ~) 의 범위는 ranges라는 함수로 (카메라 제일 가까운 depth ~ 카메라 가장 먼 depth)의 index 범위값 저장 ex) Block 0은 [0 ~ 548] , Block 1는 [549 ~ 810] 이면
                                                                                                                            // ranges[0] = [0, 548] , ranges[1] = [549,810] 이고, point_list[0] = 0x00001579 이런식으로 Gaussian의 ID 가 저장되어 있습니다. 
                                                                                                                            // SLAM_Rasterizer/verif/hex/fp32/gaussian_id.hex에 한 Block의 Gaussian ID의 값을 저장해 놨습니다.

    output reg [63:0]                       ranges_to_block                 [max_blocks-1:0],                               // INT32, 각 block당 사용하는 gaussian의 범위 (Forward 단에서 depth 기준으로 정리한 gaussian의 depth 와 id로 구성되어 있습니다.) 
    output reg [15:0]                       block_id_to_block               [num_BLOCK_CTRL-1:0],                           // Block index x at [0] y at [1]

    ////////////////////////////
    /// Gaussian 단위 Output ///
    ////////////////////////////
    output reg [11:0]                       W_to_block                      [num_BLOCK_CTRL-1:0],
    output reg [11:0]                       H_to_block                      [num_BLOCK_CTRL-1:0],
    

    output reg [(2 * precision) - 1 : 0]    mean2D_to_block                 [num_BLOCK_CTRL-1:0]    [max_num_gaussian-1:0],     // FP16 Target, bit size precision * 2는 각각 MSB 부터 projection한 x, y값 () , Forward preprocess에서 정의
    output reg [(4 * precision) - 1 : 0]    conic_opacity_to_block          [num_BLOCK_CTRL-1:0]    [max_num_gaussian-1:0],     // FP16 Target, bit size precision * 4는 각각 MSB 부터 conic opacity x, y, z, w값,  Forward preprocess에서 정의
    output reg [(3 * precision) - 1 : 0]    gaussian_color_to_block         [num_BLOCK_CTRL-1:0]    [max_num_gaussian-1:0],     // FP16 Target, bit size precision * 3은 각각 MSB 부터 Gaussian color R, G ,B값,  Forward preprocess에서 정의
    output reg [precision - 1 : 0]          gaussian_depth_to_block         [num_BLOCK_CTRL-1:0]    [max_num_gaussian-1:0],     // FP16 Target, Gaussian Depth 값 , Forward preprocess에서 정의

    //////////////////////////
    /// Pixel 단위 Output ////
    //////////////////////////
    output reg [precision-1 : 0]            final_Ts_to_memory              [(2 * $clog2(BLOCK_SIZE)) - 1:0],               // FP16 Target, Forward Render에서 최종 Transmittance 값 (1 - 최종 opacity)

    output reg [31:0]                       n_contrib_to_memory             [(2 * $clog2(BLOCK_SIZE)) - 1:0],               // INT32, Forward Render에서 각 타일에 입힌 Gaussian의 수, skip도 같이 세어서 숫자가 큼 (PPT에 보여드린 히트맵 중 800~1200에 해당되는 큰 값),
                                                                                                                            // CUDA 함수에서 한 Block은 끝날때까지 공유하기 때문에 시작점으로 사용 가능 (Range의 담긴 값이) 0 ~ 1300이면 n_contrib이 타일마다 100 ~ 700이면, backward 특성상 1300 -> 0을 계산해야 하므로, 이 n_contrib 값으로 시작 위치를 조정해야함. 
                                                                                                                            // 안 그러면 Gaussian index가 벗어나서 Pixel Unit에서 Gradient를 계산하지 않아야 하는데 (skip = 1), Gaussian 값 자체로 인한 skip = 0이 뜨는 경우가 생겨서 필수적으로 이 값을 사용해서 조정해야 합니다.

    output reg [(3 * precision) - 1 : 0]    dL_dpixel_to_memory             [(2 * $clog2(BLOCK_SIZE)) - 1:0],               // FP16 Target, Loss RGB 함수에서 오는 gradient로 추정. bit size precision * 3은 각각 MSB 부터 Gaussian color R, G ,B값이고, 특징으로는 절댓값은 같고 부호가 다른 경우입니다 (-0.000015 ,0.000015, 0.000015) 이런 느낌의 값이 주로 보였습니다
    output reg [precision - 1 : 0]          dL_dpixel_depth_to_memory       [(2 * $clog2(BLOCK_SIZE)) - 1:0],               // FP16 Target, Loss depth 함수에서 오는 gradient로 추정. 
    

    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    
    output reg                              gaussian_valid_to_block                  [num_BLOCK_CTRL-1:0],
    output reg                              gradient_ready_to_block                  [num_BLOCK_CTRL-1:0],


    //////////////////////////////////
    //////// From Block Ctrl /////////
    //////////////////////////////////

    input wire [(2 * precision) - 1 : 0]    dL_dmean2D_from_block           [num_BLOCK_CTRL-1:0]    [max_num_gaussian-1:0],     // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함, CUDA backward에서는 3차원으로 처리하는데, 실질적으로 사용은 (backward preprocess를 봐도) x,y 두 차원만 해서 2 * precision으로 했습니다.
    input wire [(4 * precision) - 1 : 0]    dL_dconic_from_block            [num_BLOCK_CTRL-1:0]    [max_num_gaussian-1:0],     // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함
    input wire [(3 * precision) - 1 : 0]    dL_dcolor_from_block            [num_BLOCK_CTRL-1:0]    [max_num_gaussian-1:0],     // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함
    input wire [precision - 1 : 0]          dL_ddepth_from_block            [num_BLOCK_CTRL-1:0]    [max_num_gaussian-1:0],     // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함

    input wire [precision - 1 : 0]          dL_dopacity_from_block          [num_BLOCK_CTRL-1:0]    [max_num_gaussian-1:0],     // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함

    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    
    input wire                              gaussian_ready_from_block                [num_BLOCK_CTRL-1:0], 
    input wire                              gradient_valid_from_block                [num_BLOCK_CTRL-1:0]
);

    // Register declaration
    reg [15:0] block_id [num_BLOCK_CTRL-1:0]; // [14:7] x, [6:0] y
    reg [15:0] block_id_max_x, block_id_max_y;

    // Register declaration for inputs from memory
    reg [11:0] W_from_memory_reg;
    reg [11:0] H_from_memory_reg;
    reg [31:0] point_list_from_memory_reg [max_num_rendered-1:0];
    reg [63:0] ranges_from_memory_reg [max_blocks-1:0];
    reg [(2 * precision) - 1 : 0] mean2D_from_memory_reg [max_num_gaussian-1:0];
    reg [(4 * precision) - 1 : 0] conic_opacity_from_memory_reg [max_num_gaussian-1:0];
    reg [(3 * precision) - 1 : 0] gaussian_color_from_memory_reg [max_num_gaussian-1:0];
    reg [precision - 1 : 0] gaussian_depth_from_memory_reg [max_num_gaussian-1:0];
    reg [precision-1 : 0] final_Ts_from_memory_reg [(max_H * max_W) - 1:0];
    reg [31:0] n_contrib_from_memory_reg [(max_H * max_W) - 1:0];
    reg [(3 * precision) - 1 : 0] dL_dpixel_from_memory_reg [(max_H * max_W) - 1:0];
    reg [precision - 1 : 0] dL_dpixel_depth_from_memory_reg [(max_H * max_W) - 1:0];



    // Register declaration for outputs to memory



    // Register declaration for inputs from block control
    // FIFO에 넣어야 하는 dL_dmean2D 값 (inputs from block ctrl)
    reg [(2 * precision) - 1 : 0]    dL_dmean2D        [max_num_gaussian-1:0];                                 // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함, CUDA backward에서는 3차원으로 처리하는데, 실질적으로 사용은 (backward preprocess를 봐도) x,y 두 차원만 해서 2 * precision으로 했습니다.
    reg [(4 * precision) - 1 : 0]    dL_dconic         [max_num_gaussian-1:0];                                 // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함
    reg [(3 * precision) - 1 : 0]    dL_dcolor         [max_num_gaussian-1:0];                                 // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함
    reg [precision - 1 : 0]          dL_ddepth         [max_num_gaussian-1:0];                                 // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함
    reg [precision - 1 : 0]          dL_dopacity       [max_num_gaussian-1:0];        


    // Wire declaration
    wire gaussian_to_block_handshake [num_BLOCK_CTRL-1:0];
    wire gradient_from_block_handshake [num_BLOCK_CTRL-1:0];
    wire top_gaussian_from_memory_handshake;
    wire top_gradient_to_memory_handshake;


    // Max Block ID determination
    always_comb begin
        if (W_from_memory[3:0] == 4'b0) begin
            block_id_max_x = W_from_memory >> 4;
        end
        else begin
            block_id_max_x = W_from_memory >> 4 + 'd1;
        end

        if (H_from_memory[3:0] == 4'b0) begin
            block_id_max_y = H_from_memory >> 4;
        end
        else begin
            block_id_max_y = (H_from_memory >> 4) + 'd1;
        end
    end


    // Generate handshake signals for each block control
    generate
        for (genvar i = 0; i < num_BLOCK_CTRL; i++) begin : BLOCK_HANDSHAKE_GEN
            assign gaussian_to_block_handshake[i] = gaussian_valid_to_block[i] && gaussian_ready_from_block[i];
            assign gradient_from_block_handshake[i] = gradient_valid_from_block[i] && gradient_ready_to_block[i];
        end
    endgenerate

    assign top_gaussian_from_memory_handshake = gaussian_ready_to_memory && gaussian_valid_from_memory;
    assign top_gradient_to_memory_handshake = gradient_valid_to_memory && gradient_ready_from_memory;


    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            W_from_memory_reg <= 12'b0;
            H_from_memory_reg <= 12'b0;

            for (int i = 0; i < max_num_rendered; i++) begin
                point_list_from_memory_reg[i] <= 32'b0;
            end

            for (int i = 0; i < max_blocks; i++) begin
                ranges_from_memory_reg[i] <= 64'b0;
            end

            for (int i = 0; i < max_num_gaussian; i++) begin
                mean2D_from_memory_reg[i] <= {(2 * precision){1'b0}};
                conic_opacity_from_memory_reg[i] <= {(4 * precision){1'b0}};
                gaussian_color_from_memory_reg[i] <= {(3 * precision){1'b0}};
                gaussian_depth_from_memory_reg[i] <= {precision{1'b0}};
            end

            for (int i = 0; i < (max_H * max_W); i++) begin
                final_Ts_from_memory_reg[i] <= {precision{1'b0}};
                n_contrib_from_memory_reg[i] <= 32'b0;
                dL_dpixel_from_memory_reg[i] <= {(3 * precision){1'b0}};
                dL_dpixel_depth_from_memory_reg[i] <= {precision{1'b0}};
            end

            // Reset all output registers
            for (int i = 0; i < max_num_gaussian; i++) begin
                dL_dmean2D_to_memory[i] <= 'h0;
                dL_dconic_to_memory[i] <= 'h0;
                dL_dcolor_to_memory[i] <= 'h0;
                dL_ddepth_to_memory[i] <= 'h0;
                dL_dopacity_to_memory[i] <= 'h0;
            end

            for (int i = 0; i < max_num_rendered; i++) begin
                point_list_to_block[i] <= 'h0;
            end

            for (int i = 0; i < max_blocks; i++) begin
                ranges_to_block[i] <= 'h0;
            end

            for (int i = 0; i < num_BLOCK_CTRL; i++) begin
                block_id_to_block[i] <= 'h0;
                W_to_block[i] <= 'h0;
                H_to_block[i] <= 'h0;
                gaussian_valid_to_block[i] <= 'b0;
                for (int j = 0; j < max_num_gaussian; j++) begin
                    mean2D_to_block[i][j] <= 'h0;
                    conic_opacity_to_block[i][j] <= 'h0;
                    gaussian_color_to_block[i][j] <= 'h0;
                    gaussian_depth_to_block[i][j] <= 'h0;
                end
            end

            for (int i = 0; i < (2 * $clog2(BLOCK_SIZE)); i++) begin
                final_Ts_to_memory[i] <= 'h0;
                n_contrib_to_memory[i] <= 'd0;
                dL_dpixel_to_memory[i] <= 'h0;
                dL_dpixel_depth_to_memory[i] <= 'h0;
            end
            gaussian_ready_to_memory <= 1'b0;

        end 
        

        else begin

            // Memory에서 Gaussian 받기
            if (top_gaussian_from_memory_handshake) begin
                W_from_memory_reg <= W_from_memory;
                H_from_memory_reg <= H_from_memory;

                for (int i = 0; i < max_num_rendered; i++) begin
                    point_list_from_memory_reg[i] <= point_list_from_memory[i];
                end

                for (int i = 0; i < max_blocks; i++) begin
                    ranges_from_memory_reg[i] <= ranges_from_memory[i];
                end

                for (int i = 0; i < max_num_gaussian; i++) begin
                    mean2D_from_memory_reg[i] <= mean2D_from_memory[i];
                    conic_opacity_from_memory_reg[i] <= conic_opacity_from_memory[i];
                    gaussian_color_from_memory_reg[i] <= gaussian_color_from_memory[i];
                    gaussian_depth_from_memory_reg[i] <= gaussian_depth_from_memory[i];
                end

                for (int i = 0; i < (max_H * max_W); i++) begin
                    final_Ts_from_memory_reg[i] <= final_Ts_from_memory[i];
                    n_contrib_from_memory_reg[i] <= n_contrib_from_memory[i];
                    dL_dpixel_from_memory_reg[i] <= dL_dpixel_from_memory[i];
                    dL_dpixel_depth_from_memory_reg[i] <= dL_dpixel_depth_from_memory[i];
                end
            end


            // Memory에 gradient 전송하기 
            if (top_gradient_to_memory_handshake) begin
                // Assign gradient values to memory
                for (int i = 0; i < max_num_gaussian; i++) begin
                    dL_dmean2D_to_memory[i] <= dL_dmean2D[i];
                    dL_dconic_to_memory[i] <= dL_dconic[i];
                    dL_dcolor_to_memory[i] <= dL_dcolor[i];
                    dL_ddepth_to_memory[i] <= dL_ddepth[i];
                    dL_dopacity_to_memory[i] <= dL_dopacity[i];

                    gradient_valid_to_memory <= 1'b0;
                end
            end
            
            
            for (int i = 0; i < num_BLOCK_CTRL; i++) begin

                // Block에 Gaussian 전송하기
                if (gaussian_to_block_handshake[i]) begin
                    block_id[i] <= block_id_to_block[i];
                    gaussian_valid_to_block[i] <= 1'b0;
                end

                // Block에서 Gradient 받기
                if (gradient_from_block_handshake[i]) begin

                end

            end
        end
    end

    // FIFO instantiation for each Gaussian using generate syntax
    // gradient from block control
    generate
        for (genvar i = 0; i < max_num_gaussian; i++) begin : Gradient_FIFO_GEN
            FIFO #( .FIFO_depth(4), .input_data_width(8), .output_data_width(16)) 
                gaussian_fifo (
                .clk(clk),
                .rst_n(rst_n),
                .write_valid_in(),
                .read_valid_in(),
                .write_data_in(),
                .read_data_out(),
                .full_out(),
                .empty_out()
            );
        end
    endgenerate


    // // Block Unit declaration
    // genvar i;
    // generate
    //     for (i = 0; i < num_BLOCK_CTRL; i++) begin : BLOCK_CONTROLS
    //         Block_ctrl #(.BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision), .group_gaussians(group_gaussians), .group_pixels(group_pixels), .gaussians_to_pixels(2)) 
    //         block_unit(.clk(clk), .rst_n(rst_n), .W(W_to_block[i]), .H(H_to_block[i]), .ranges(ranges[i]), .gaussian_id(gaussian_id[i]));
            


    //     end
    // endgenerate






endmodule