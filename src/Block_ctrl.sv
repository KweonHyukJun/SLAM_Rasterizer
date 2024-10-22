module Block_ctrl
    #(       
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 7,
        parameter precision = 16,
        parameter max_H = 1080,
        parameter max_W = 1920,
        parameter max_ranges = 10000,
        parameter num_gaussian = 200000
    ) 
(
    // input은 wire, output은 reg로 통일하겠습니다

    input wire clk,
    input wire rst_n,

    ////////////////////////////////////////////////////
    /////////// Communication to Block Ctrl ////////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    ///////// To Group Ctrl //////////
    //////////////////////////////////

    // Block에 들어가는 point_list와 range의 평균 크기를 구해서 변경하는 걸 목표로
    input wire [31:0]                       point_list_from_block             [num_rendered-1:0],                             // int 32, 전체 Gaussian에 대해서 순서 정렬된 정보 [(block 1 내부 depth로 인한 순서 ~) ,  (block 2 내부 depth로 인한 순서 ~) ...] 이런식으로 block마다의 depth 기준 정렬된 Gaussian ID만 들어있음
                                                                                                                            // 이 (block 1 내부 depth로 인한 순서 ~) 의 범위는 ranges라는 함수로 (카메라 제일 가까운 depth ~ 카메라 가장 먼 depth)의 index 범위값 저장 ex) Block 0은 [0 ~ 548] , Block 1는 [549 ~ 810] 이면
                                                                                                                            // ranges[0] = [0, 548] , ranges[1] = [549,810] 이고, point_list[0] = 0x00001579 이런식으로 Gaussian의 ID 가 저장되어 있습니다. 
                                                                                                                            // SLAM_Rasterizer/verif/hex/fp32/gaussian_id.hex에 한 Block의 Gaussian ID의 값을 저장해 놨습니다.

    input wire [63:0]                       ranges_from_block                 [max_blocks-1:0],                               // INT32, 각 block당 사용하는 gaussian의 범위 (Forward 단에서 depth 기준으로 정리한 gaussian의 depth 와 id로 구성되어 있습니다.) 
    input wire [15:0]                       block_id_from_block,

    ////////////////////////////
    /// Gaussian 단위 Output ///
    ////////////////////////////
    input wire [11:0]                       H_from_block,
    input wire [11:0]                       W_from_block,

    input wire [(2 * precision) - 1 : 0]    mean2D_from_block                 [num_gaussian-1:0],     // FP16 Target, bit size precision * 2는 각각 MSB 부터 projection한 x, y값 () , Forward preprocess에서 정의
    input wire [(4 * precision) - 1 : 0]    conic_opacity_from_block          [num_gaussian-1:0],     // FP16 Target, bit size precision * 4는 각각 MSB 부터 conic opacity x, y, z, w값,  Forward preprocess에서 정의
    input wire [(3 * precision) - 1 : 0]    gaussian_color_from_block         [num_gaussian-1:0],     // FP16 Target, bit size precision * 3은 각각 MSB 부터 Gaussian color R, G ,B값,  Forward preprocess에서 정의
    input wire [precision - 1 : 0]          gaussian_depth_from_block         [num_gaussian-1:0],     // FP16 Target, Gaussian Depth 값 , Forward preprocess에서 정의

    //////////////////////////
    /// Pixel 단위 Output ////
    //////////////////////////
    input wire [precision-1 : 0]            final_Ts_to_memory              [(2 * $clog2(BLOCK_SIZE)) - 1:0],               // FP16 Target, Forward Render에서 최종 Transmittance 값 (1 - 최종 opacity)

    input wire [31:0]                       n_contrib_to_memory             [(2 * $clog2(BLOCK_SIZE)) - 1:0],               // INT32, Forward Render에서 각 타일에 입힌 Gaussian의 수, skip도 같이 세어서 숫자가 큼 (PPT에 보여드린 히트맵 중 800~1200에 해당되는 큰 값),
                                                                                                                            // CUDA 함수에서 한 Block은 끝날때까지 공유하기 때문에 시작점으로 사용 가능 (Range의 담긴 값이) 0 ~ 1300이면 n_contrib이 타일마다 100 ~ 700이면, backward 특성상 1300 -> 0을 계산해야 하므로, 이 n_contrib 값으로 시작 위치를 조정해야함. 
                                                                                                                            // 안 그러면 Gaussian index가 벗어나서 Pixel Unit에서 Gradient를 계산하지 않아야 하는데 (skip = 1), Gaussian 값 자체로 인한 skip = 0이 뜨는 경우가 생겨서 필수적으로 이 값을 사용해서 조정해야 합니다.

    input wire [(3 * precision) - 1 : 0]    dL_dpixel_to_memory             [(2 * $clog2(BLOCK_SIZE)) - 1:0],               // FP16 Target, Loss RGB 함수에서 오는 gradient로 추정. bit size precision * 3은 각각 MSB 부터 Gaussian color R, G ,B값이고, 특징으로는 절댓값은 같고 부호가 다른 경우입니다 (-0.000015 ,0.000015, 0.000015) 이런 느낌의 값이 주로 보였습니다
    input wire [precision - 1 : 0]          dL_dpixel_depth_to_memory       [(2 * $clog2(BLOCK_SIZE)) - 1:0],               // FP16 Target, Loss depth 함수에서 오는 gradient로 추정. 
    

    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    
    input wire                              valid_from_block                  [num_BLOCK_CTRL-1:0],


    //////////////////////////////////
    ////////// To Block Ctrl /////////
    //////////////////////////////////

    output reg [(2 * precision) - 1 : 0]    dL_dmean2D_from_block           [num_BLOCK_CTRL-1:0]    [num_gaussian-1:0],     // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함, CUDA backward에서는 3차원으로 처리하는데, 실질적으로 사용은 (backward preprocess를 봐도) x,y 두 차원만 해서 2 * precision으로 했습니다.
    output reg [(4 * precision) - 1 : 0]    dL_dconic_from_block            [num_BLOCK_CTRL-1:0]    [num_gaussian-1:0],     // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함
    output reg [(3 * precision) - 1 : 0]    dL_dcolor_from_block            [num_BLOCK_CTRL-1:0]    [num_gaussian-1:0],     // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함
    output reg [precision - 1 : 0]          dL_ddepth_from_block            [num_BLOCK_CTRL-1:0]    [num_gaussian-1:0],     // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함

    output reg [precision - 1 : 0]          dL_dopacity_from_block          [num_BLOCK_CTRL-1:0]    [num_gaussian-1:0],     // FP16 Target, 연산 완료 후 Gaussian마다 생긴 Gradient를 반환함

    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    
    output reg                              ready_from_block                [num_BLOCK_CTRL-1:0]

);
// (
//     input wire clk,
//     input wire rst_n,

//     input wire [11:0] W,
//     input wire [11:0] H,

//     input wire [63:0] ranges, // gaussian ranges in this block

//     input wire [31:0] gaussian_id [num_gaussian - 1 :0], // gaussian range만큼 만들어야 함
//     input wire [(2*precision)-1 :0] mean2D [num_gaussian - 1 :0], // gaussian range만큼 만들어야 함
//     input wire [(4*precision)-1 :0] conic_opacity [num_gaussian - 1 :0],
//     input wire [(3*precision)-1 :0] gaussian_color [num_gaussian - 1 :0],
//     input wire [precision-1 :0] gaussian_depth [num_gaussian - 1 :0],
    
//     // H * W만큼 만들어야 하는 변수들
//     input wire [31:0] Final_T [( max_H * max_W )-1:0],
//     input wire [(3*precision)-1 :0] dL_dpixel [( max_H * max_W)-1:0],
//     input wire [precision-1 :0] dL_dpixel_depth [( max_H * max_W)-1:0], 

//     input wire [31:0] pixel_touches [( max_H * max_W)-1:0],

//     output reg [31:0] gaussian_id_out [num_gaussian - 1 :0],
//     output reg [(2 * precision) - 1:0] dL_dmean2D_out [num_gaussian - 1 :0], 
//     output reg [(4 * precision) - 1:0] dL_dconic_out [num_gaussian - 1 :0], 
//     output reg [precision - 1:0] dL_dopacity_out [num_gaussian - 1 :0], 
//     output reg [(3 * precision) - 1:0] dL_dcolor_out [num_gaussian - 1 :0], 
//     output reg [precision - 1:0] dL_ddepth_out [num_gaussian - 1 :0] 
// );



endmodule