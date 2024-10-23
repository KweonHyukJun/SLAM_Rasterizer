module Pixel_group_module #(
    parameter max_num_rendered = 500000,
    parameter max_blocks = 8160,
    parameter max_num_gaussian = 200000,

    parameter precision = 24,
    parameter mantissa_bit = 15,
    parameter exponent_bit = 8,

    parameter max_W = 1920,
    parameter max_H = 1080,
    parameter num_BLOCK_CTRL = 8,
    parameter num_GROUP_CTRL = 4,
    parameter BLOCK_SIZE = 16,
    
    parameter group_gaussian = 32
)

(
    input wire clk,
    input wire rst_n,

    ////////////////////////////////////////////////////
    /////////// Communication to Memory Ctrl ///////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    ///////// From Top Ctrl //////////
    //////////////////////////////////
    
    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    input wire                              gaussian_valid_from_Top,
    input wire                              gradient_ready_from_Top,


    //////////////////////////////////
    ////////// To Top Ctrl ///////////
    //////////////////////////////////


    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    output reg                              gaussian_ready_to_top,
    output reg                              gradient_valid_to_top,
    output reg                              done_to_top,


    ////////////////////////////////////////////////////
    /////////// Communication to Block Ctrl ////////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    ///////// To Group Ctrl //////////
    //////////////////////////////////
    

    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    
    output reg                              gaussian_valid_to_group                  [num_GROUP_CTRL-1:0],
    output reg                              gradient_ready_to_group                  [num_GROUP_CTRL-1:0],


    //////////////////////////////////
    //////// From Group Ctrl /////////
    //////////////////////////////////

    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    
    input wire                              gaussian_ready_from_group                [num_BLOCK_CTRL-1:0], 
    input wire                              gradient_valid_from_group                [num_BLOCK_CTRL-1:0],




    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // 이전 단계에서 받아야 하는 값들인데, 용량이 커서 (전부를 (모든 Block의 모든 데이터) 이전 단계 연산에서 다 받으면 작은 데이터셋(480x640 해상도) 기준 10MB, 큰 데이터 셋 기준 (1200*680) 29.4MB 소모됩니다.
    // 그걸 메모리 단계에서 생각하는 중에 어떻게 처리할 지 몰라서 맨 밑에 따로 빼놨습니다.

    
    ////////////////////////////////////////////////////
    //////////////// From Top (Inputs) /////////////////
    ////////////////////////////////////////////////////
        
    input wire [11:0]                       W_from_Top,
    input wire [11:0]                       H_from_Top,

    input wire [31:0]                       point_list_from_Top     [999:0],   // 999는 예시고,
                                                                                // point_list_from_Top [ranges_from_Top[0]:ranges_from_Top[1]] 의 범위만 갖고 있으면 됩니다.
                                                                                // 자기 블럭의 range의 시작과 끝 차이만큼 가져오면 됩니다.
    input wire [63:0]                       ranges_from_Top          , // 자기 블럭의 range만 들고 있으면 됩니다.

    ////////////////////////////
    /// Gaussian 단위 Input ////
    ////////////////////////////
    input wire [(2 * precision) - 1 : 0]    mean2D_from_Top          [999:0], // 999는 위의 point_list와 같은 이유로 범위만 메모리에 저장하면 됩니다.

    input wire [(4 * precision) - 1 : 0]    conic_opacity_from_Top   [999:0], 

    input wire [(3 * precision) - 1 : 0]    gaussian_color_from_Top  [999:0], 

    input wire [precision - 1 : 0]          gaussian_depth_from_Top  [999:0], 


    //////////////////////////
    //// Pixel 단위 Input ////
    //////////////////////////

    input wire [precision-1 : 0]            final_Ts_from_Top        [2 * $clog2(BLOCK_SIZE) - 1:0], //자기 block의 pixel 개수 만큼 메모리에 저장하면 됩니다.

    input wire [31:0]                       n_contrib_from_Top       [2 * $clog2(BLOCK_SIZE) - 1:0], //자기 block의 pixel 개수 만큼 메모리에 저장하면 됩니다.

    input wire [(3 * precision) - 1 : 0]    dL_dpixel_from_Top       [2 * $clog2(BLOCK_SIZE) - 1:0], //자기 block의 pixel 개수 만큼 메모리에 저장하면 됩니다.
    input wire [precision - 1 : 0]          dL_dpixel_depth_from_Top [2 * $clog2(BLOCK_SIZE) - 1:0], //자기 block의 pixel 개수 만큼 메모리에 저장하면 됩니다.


    //////////////////////////////////
    ////////// To Top Ctrl ///////////
    //////////////////////////////////


    ////////////////////////////////////////////////////
    //////////////// To Top (Outputs) //////////////////
    ////////////////////////////////////////////////////


    //////////////////////////
    //// Gradient 값 반환 /////
    //////////////////////////
    output reg [(2 * precision) - 1 : 0]    dL_dmean2D_to_Top           [999:0], // 999는 위의 point_list와 같은 이유로 범위만 메모리에 저장하면 됩니다.
    output reg [(4 * precision) - 1 : 0]    dL_dconic_to_Top            [999:0], 
    output reg [(3 * precision) - 1 : 0]    dL_dcolor_to_Top            [999:0], 
    output reg [precision - 1 : 0]          dL_ddepth_to_Top            [999:0], 

    output reg [precision - 1 : 0]          dL_dopacity_to_Top          [999:0], 

    ////////////////////////////////////////////////////
    /////////// Communication to Group Ctrl ////////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    ///////// To Group Ctrl //////////
    //////////////////////////////////

    // Block에 들어가는 point_list와 range의 평균 크기를 구해서 변경하는 걸 목표로
    output reg [31:0]                       point_list_to_Pixel_group             [999:0], // 999는 위의 point_list와 같은 이유로 범위만 메모리에 저장하면 됩니다.

    output reg [63:0]                       ranges_to_Pixel_group                 ,// 자기 블럭의 range만 들고 있으면 되는데, 이게 Block 단위라 같은 Block에서는 모두 다 같은 Range를 가집니다.
    output reg [15:0]                       block_id_to_Pixel_group               [num_GROUP_CTRL-1:0], // 픽셀 계산 시 Block ID가 사용됩니다.

    ////////////////////////////
    /// Gaussian 단위 Output ///
    ////////////////////////////
    output reg [11:0]                       W_to_Pixel_group                      [num_GROUP_CTRL-1:0], // 픽셀 계산 시 H, W가 사용됩니다.
    output reg [11:0]                       H_to_Pixel_group                      [num_GROUP_CTRL-1:0],
    

    output reg [(2 * precision) - 1 : 0]    mean2D_to_Pixel_group                 [num_GROUP_CTRL-1:0]    [999:0], // 999는 위의 point_list와 같은 이유로 범위만 메모리에 저장하면 됩니다.
    output reg [(4 * precision) - 1 : 0]    conic_opacity_to_Pixel_group          [num_GROUP_CTRL-1:0]    [999:0],
    output reg [(3 * precision) - 1 : 0]    gaussian_color_to_Pixel_group         [num_GROUP_CTRL-1:0]    [999:0],
    output reg [precision - 1 : 0]          gaussian_depth_to_Pixel_group         [num_GROUP_CTRL-1:0]    [999:0],

    //////////////////////////
    /// Pixel 단위 Output ////
    //////////////////////////
    output reg [precision-1 : 0]            final_Ts_to_Pixel_group              [(2 * $clog2(BLOCK_SIZE)) - 1:0],

    output reg [31:0]                       n_contrib_to_Pixel_group             [(2 * $clog2(BLOCK_SIZE)) - 1:0],

    output reg [(3 * precision) - 1 : 0]    dL_dpixel_to_Pixel_group             [(2 * $clog2(BLOCK_SIZE)) - 1:0],
    output reg [precision - 1 : 0]          dL_dpixel_depth_to_Pixel_group       [(2 * $clog2(BLOCK_SIZE)) - 1:0],

    //////////////////////////////////
    //////// From Block Ctrl /////////
    //////////////////////////////////

    input wire [(2 * precision) - 1 : 0]    dL_dmean2D_from_block           [num_GROUP_CTRL-1:0]    [999:0], // 999는 위의 point_list와 같은 이유로 범위만 메모리에 저장하면 됩니다.
    input wire [(4 * precision) - 1 : 0]    dL_dconic_from_block            [num_GROUP_CTRL-1:0]    [999:0],
    input wire [(3 * precision) - 1 : 0]    dL_dcolor_from_block            [num_GROUP_CTRL-1:0]    [999:0],
    input wire [precision - 1 : 0]          dL_ddepth_from_block            [num_GROUP_CTRL-1:0]    [999:0],

    input wire [precision - 1 : 0]          dL_dopacity_from_block          [num_GROUP_CTRL-1:0]    
);

// 컨트롤러에 들어갈 신호들을 정의하였습니다.
// 컨트롤러에서는 W, H를 받아서 Block ID의 최대치를 정하고 그에 따라서 Gaussian의 범위를 정하고
// (point_list라는 block 단위로 모아놓은 전체 gaussiasn id 묶음과 range를 통해 각 block에서 쓰는 범위값을 통해서 알 수 있습니다), 
// Gaussian의 정보를 받아서 각 Block에 Gaussian ID와 Gaussian 정보 (color, depth 등) 넣어주는 역할을 합니다.

// 메모리 관련 주소 정보는 아직 처리하지 않았습니다.

Block_controller #()
    Block_control (
        .clk(clk),
        .rst_n(rst_n),

        .W_from_memory(W_from_Top),
        .H_from_memory(H_from_Top),
        .gaussian_valid_from_memory(gaussian_valid_from_Top),
        .gradient_ready_from_memory(gradient_ready_from_Top),

        .gaussian_ready_to_memory(gaussian_ready_to_memory),
        .gradient_valid_to_memory(gradient_valid_to_memory),
        .done_to_memory(done_to_memory),

        .gaussian_valid_to_block(gaussian_valid_to_block),
        .gradient_ready_to_block(gradient_ready_to_block),

        .gaussian_ready_from_block(gaussian_ready_from_block),
        .gradient_valid_from_block(gradient_valid_from_block)
    );




// 메모리 이동 관련인데 아직 어떻게 해야 할지 몰라서 모듈이 없고, 외부 메모리 -> 내부 메모리에는 이걸 이동해야 된다 라고 생각하시면 될 것 같습니다.

Block_memory #()
    Exp_memory_to_Top_memory(
        .clk(clk),
        .rst_n(rst_n),

         // Top 메모리 -> Block 메모리로 진입하는 신호 (Top -> Bottom)
        .point_list_from_memory(point_list_from_Top),
        .ranges_from_memory(ranges_from_Top),
        .mean2D_from_memory(mean2D_from_Top),
        .conic_opacity_from_memory(conic_opacity_from_Top),
        .gaussian_color_from_memory(gaussian_color_from_Top),
        .gaussian_depth_from_memory(gaussian_depth_from_Top),
        .final_Ts_from_memory(final_Ts_from_Top),
        .n_contrib_from_memory(n_contrib_from_Top),
        .dL_dpixel_from_memory(dL_dpixel_from_Top),
        .dL_dpixel_depth_from_memory(dL_dpixel_depth_from_Top),
        .W_from_memory(W_from_Top),
        .H_from_memory(H_from_Top),

        // Block 메모리 -> Pixel Group 메모리로 나가는 신호 (Top -> Bottom)
        .W_to_block(W_to_Pixel_group),
        .H_to_block(H_to_Pixel_group),
        .mean2D_to_block(mean2D_to_Pixel_group),
        .conic_opacity_to_block(conic_opacity_to_Pixel_group),
        .gaussian_color_to_block(gaussian_color_to_Pixel_group),
        .gaussian_depth_to_block(gaussian_depth_to_Pixel_group),
        .final_Ts_to_memory(final_Ts_to_Pixel_group),
        .n_contrib_to_memory(n_contrib_to_Pixel_group),
        .dL_dpixel_to_memory(dL_dpixel_to_Pixel_group),
        .dL_dpixel_depth_to_memory(dL_dpixel_depth_to_Pixel_group),


        // Pixel Group 메모리 -> Block 메모리로 진입하는 신호 (Bottom -> Top)
        .dL_dmean2D_from_block(dL_dmean2D_from_block),
        .dL_dconic_from_block(dL_dconic_from_block),
        .dL_dcolor_from_block(dL_dcolor_from_block),
        .dL_ddepth_from_block(dL_ddepth_from_block),
        .dL_dopacity_from_block(dL_dopacity_from_block),


        // Block 메모리 -> Top 메모리로 나가는 신호 (Bottom -> Top)
        .dL_dmean2D_to_memory(dL_dmean2D_to_memory),
        .dL_dconic_to_memory(dL_dconic_to_memory), 
        .dL_dcolor_to_memory(dL_dcolor_to_memory),
        .dL_ddepth_to_memory(dL_ddepth_to_memory),
        .dL_dopacity_to_memory(dL_dopacity_to_memory)
    );




endmodule
