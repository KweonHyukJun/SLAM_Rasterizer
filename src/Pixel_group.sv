module Pixel_group_module #(
    parameter precision = 24,
    parameter mantissa_bit = 15,
    parameter exponent_bit = 8,

    parameter BLOCK_SIZE = 16,
    
    parameter group_gaussian = 32,
    parameter num_GROUP_PIXELS = 32,
    
    parameter input_gaussians_to_pixel = 4

)

(
    input wire clk,
    input wire rst_n,

    ////////////////////////////////////////////////////
    /////////// Communication to Memory Ctrl ///////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    //////// From Block Ctrl ////////
    //////////////////////////////////
    
    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    input wire                              gaussian_valid_from_Block,
    input wire                              gradient_ready_from_Block,


    //////////////////////////////////
    ///////// To Block Ctrl /////////
    //////////////////////////////////


    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    output reg                              gaussian_ready_to_Block,
    output reg                              gradient_valid_to_Block,
    output reg                              done_to_Block,


    ////////////////////////////////////////////////////
    /////////// Communication to Pixel Unit ////////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    ///////// To Pixel Unit //////////
    //////////////////////////////////
    

    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    
    output reg                              gaussian_valid_to_pixel                  [num_GROUP_PIXELS-1:0],
    // output reg                              gradient_ready_to_group                  [num_GROUP_CTRL-1:0],  // FIFO로 Write시 Ready 신호 불필요,
    output reg                              stall_to_pixel                           [num_GROUP_PIXELS-1:0],  // FIFO에서 Pixel에 Stall 신호


    //////////////////////////////////
    //////// From Pixel Unit /////////
    //////////////////////////////////

    //////////////////////////
    /////// Ctrl signal //////
    //////////////////////////
    
    // input wire                              gaussian_ready_from_pixel                [num_BLOCK_CTRL-1:0], // Pixel 유닛은 DataPath이므로, ready - valid protocol 사용 안함.
    input wire                              gradient_valid_from_pixel                [num_GROUP_PIXELS-1:0],




    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // 이전 단계에서 받아야 하는 값들인데, 용량이 커서 (전부를 (모든 Block의 모든 데이터) 이전 단계 연산에서 다 받으면 작은 데이터셋(480x640 해상도) 기준 10MB, 큰 데이터 셋 기준 (1200*680) 29.4MB 소모됩니다.
    // 그걸 메모리 단계에서 생각하는 중에 어떻게 처리할 지 몰라서 맨 밑에 따로 빼놨습니다.

    
    ////////////////////////////////////////////////////
    //////////////// From Block (Inputs) ///////////////
    ////////////////////////////////////////////////////
        
    input wire [11:0]                       W_from_Block,
    input wire [11:0]                       H_from_Block,

    // input wire [31:0]                       point_list_from_Block     [999:0],   // Block에서 관할하고, Group은 Block에서 Gaussian ID를 받아서 처리하므로 필요 없음.
    // input wire [63:0]                       ranges_from_Block         ,

    ////////////////////////////
    /// Gaussian 단위 Input ////
    ////////////////////////////
    input wire [(2 * precision) - 1 : 0]    mean2D_from_Block          [group_gaussian-1:0], // 한 번에 처리할 Gaussian 만큼만 가져오면 되므로 Gaussian 수가 Block에 비해 요구량이 감소합니다.

    input wire [(4 * precision) - 1 : 0]    conic_opacity_from_Block   [group_gaussian-1:0], 

    input wire [(3 * precision) - 1 : 0]    gaussian_color_from_Block  [group_gaussian-1:0], 

    input wire [precision - 1 : 0]          gaussian_depth_from_Block  [group_gaussian-1:0], 


    //////////////////////////
    //// Pixel 단위 Input ////
    //////////////////////////

    input wire [precision-1 : 0]            final_Ts_from_Block        [num_GROUP_PIXELS-1:0], // 맡은 Pixel의 수만큼 가져옵니다.

    input wire [31:0]                       n_contrib_from_Block       [num_GROUP_PIXELS-1:0], 

    input wire [(3 * precision) - 1 : 0]    dL_dpixel_from_Block       [num_GROUP_PIXELS-1:0], 
    input wire [precision - 1 : 0]          dL_dpixel_depth_from_Block [num_GROUP_PIXELS-1:0], 


    //////////////////////////////////
    ////////// To Top Ctrl ///////////
    //////////////////////////////////


    ////////////////////////////////////////////////////
    //////////////// To Top (Outputs) //////////////////
    ////////////////////////////////////////////////////


    //////////////////////////
    //// Gradient 값 반환 /////
    //////////////////////////
    output reg [(2 * precision) - 1 : 0]    dL_dmean2D_to_Block           [group_gaussian-1:0], // 한번에 처리할 gaussian 숫자만큼만 가져오면 되므로 Block 유닛에서의 output 크기보다는 작습니다.
    output reg [(4 * precision) - 1 : 0]    dL_dconic_to_Block            [group_gaussian-1:0], 
    output reg [(3 * precision) - 1 : 0]    dL_dcolor_to_Block            [group_gaussian-1:0], 
    output reg [precision - 1 : 0]          dL_ddepth_to_Block            [group_gaussian-1:0], 

    output reg [precision - 1 : 0]          dL_dopacity_to_Block          [group_gaussian-1:0], 

    ////////////////////////////////////////////////////
    /////////// Communication to Pixel ////////////
    ////////////////////////////////////////////////////

    //////////////////////////////////
    ///////// To Pixel Unit //////////
    //////////////////////////////////

    // Block에 들어가는 point_list와 range의 평균 크기를 구해서 변경하는 걸 목표로
    // output reg [31:0]                       point_list_to_Pixel_group             [999:0], // 999는 위의 point_list와 같은 이유로 범위만 메모리에 저장하면 됩니다.

    // output reg [63:0]                       ranges_to_Pixel_group                 ,// 자기 블럭의 range만 들고 있으면 되는데, 이게 Block 단위라 같은 Block에서는 모두 다 같은 Range를 가집니다.

    output reg [15:0]                           block_id_to_Pixel               [num_GROUP_PIXELS-1:0], // 픽셀 계산 시 Block ID가 사용됩니다.
    output reg [2 * $clog2(BLOCK_SIZE) - 1:0]   pixel_id_to_Pixel               [num_GROUP_PIXELS-1:0], // 픽셀 계산 시 pixel ID가 사용됩니다.


    ////////////////////////////
    /// Gaussian 단위 Output ///
    ////////////////////////////

    output reg [(2 * precision) - 1 : 0]    mean2D_to_Pixel                 [num_GROUP_PIXELS-1:0], 
    output reg [(4 * precision) - 1 : 0]    conic_opacity_to_Pixel          [num_GROUP_PIXELS-1:0],
    output reg [(3 * precision) - 1 : 0]    gaussian_color_to_Pixel         [num_GROUP_PIXELS-1:0],
    output reg [precision - 1 : 0]          gaussian_depth_to_Pixel         [num_GROUP_PIXELS-1:0],

    //////////////////////////
    /// Pixel 단위 Output ////
    //////////////////////////
    output reg [precision-1 : 0]            final_Ts_to_Pixel              [(2 * $clog2(BLOCK_SIZE)) - 1:0],

    output reg [31:0]                       n_contrib_to_Pixel             [(2 * $clog2(BLOCK_SIZE)) - 1:0],

    output reg [(3 * precision) - 1 : 0]    dL_dpixel_to_Pixel             [(2 * $clog2(BLOCK_SIZE)) - 1:0],
    output reg [precision - 1 : 0]          dL_dpixel_depth_to_Pixel       [(2 * $clog2(BLOCK_SIZE)) - 1:0],

    //////////////////////////////////
    //////// From Pixel Unit /////////
    //////////////////////////////////

    input wire [(2 * precision) - 1 : 0]    dL_dmean2D_from_Pixel           [num_GROUP_PIXELS-1:0], // 999는 위의 point_list와 같은 이유로 범위만 메모리에 저장하면 됩니다.
    input wire [(4 * precision) - 1 : 0]    dL_dconic_from_Pixel            [num_GROUP_PIXELS-1:0],
    input wire [(3 * precision) - 1 : 0]    dL_dcolor_from_Pixel            [num_GROUP_PIXELS-1:0],
    input wire [precision - 1 : 0]          dL_ddepth_from_Pixel            [num_GROUP_PIXELS-1:0],

    input wire [precision - 1 : 0]          dL_dopacity_from_Pixel          [num_GROUP_PIXELS-1:0]    
);

// 컨트롤러에 들어갈 신호들을 정의하였습니다.
// 컨트롤러에서는 W, H를 받아서 Block ID의 최대치를 정하고 그에 따라서 Gaussian의 범위를 정하고
// (point_list라는 block 단위로 모아놓은 전체 gaussiasn id 묶음과 range를 통해 각 block에서 쓰는 범위값을 통해서 알 수 있습니다), 
// Gaussian의 정보를 받아서 각 Block에 Gaussian ID와 Gaussian 정보 (color, depth 등) 넣어주는 역할을 합니다.


// 메모리 관련 주소 정보는 아직 처리하지 않았습니다.

Pixel_group_controller #()
    Pixel_group_control (
        .clk(clk),
        .rst_n(rst_n),

        .W_from_Block(W_from_Block),
        .H_from_Block(H_from_Block),

        .gaussian_valid_from_Block(gaussian_valid_from_Block),
        .gradient_ready_from_Block(gradient_ready_from_Block),

        .gaussian_ready_to_Block(gaussian_ready_to_Block),
        .gradient_valid_to_Block(gradient_valid_to_Block),
        .done_to_Block(done_to_Block),

        .gaussian_valid_to_pixel(gaussian_valid_to_pixel),
        // .gradient_ready_to_pixel(gradient_ready_to_pixel),
        .stall_to_pixel(stall_to_pixel),

        .gaussian_ready_from_pixel(gaussian_ready_from_pixel),
        .gradient_valid_from_pixel(gradient_valid_from_pixel)
    );

genvar i ;
generate
    for (i = 0; i < num_GROUP_PIXELS; i = i + 1) begin : rasterizer_units
        Rasterizer_unit #(
            .precision(precision),
            .mantissa_bit(mantissa_bit),
            .exponent_bit(exponent_bit),
            .input_gaussians_to_pixel(input_gaussians_to_pixel)
        ) 
        Pixel_unit (
            // Input
            .clk(clk),
            .rst_n(rst_n),
            .W(W_from_Block),
            .H(H_from_Block),
            .i_valid(gaussian_valid_to_pixel[i]),
            .stall(stall_to_pixel[i]),
            .block_id(block_id_to_Pixel[i]),
            .pixel_id(pixel_id_to_Pixel[i]),
            .mean2D(mean2D_to_Pixel[i]),
            .conic_opacity(conic_opacity_to_Pixel[i]),
            .gaussian_color(gaussian_color_to_Pixel[i]),
            .gaussian_depth(gaussian_depth_to_Pixel[i]),
            .dL_dpixel(dL_dpixel_to_Pixel[i]),
            .dL_dpixel_depth(dL_dpixel_depth_to_Pixel[i]),
            .T_first(final_Ts_to_Pixel[i]),

            // Output
            .dL_dmean2D_out(dL_dmean2D_from_Pixel[i]),
            .dL_dconic_out(dL_dconic_from_Pixel[i]),
            .dL_dcolor_out(dL_dcolor_from_Pixel[i]),
            .dL_ddepth_out(dL_ddepth_from_Pixel[i]),
            .dL_dopacity_out(dL_dopacity_from_Pixel[i]),
            .gradient_valid(gradient_valid_from_pixel[i])
        );

        // FIFO Store gradient form Pixel
        FIFO_unit #(
            .mantissa_bit(mantissa_bit),
            .input_data_width(128),
            .output_data_width(32)
        )
        FIFO_unit_pixel (
            // Input
            .clk(clk),
            .rst_n(rst_n),
            .write_data_in(dL_dmean2D_from_Pixel[i]),
            .write_valid_in(gradient_valid_from_pixel[i]),
            .read_valid_in(gradient_valid_from_pixel[i]),

            // Output
            .read_data_out(dL_dmean2D_from_Pixel[i]),
            .full_out(),
            .empty_out(),
            .valid_out()
        );


        Gradient_Merge_unit #(
            .precision(precision),
            .mantissa_bit(mantissa_bit),
            .exponent_bit(exponent_bit),
            .input_gaussians_to_pixel(input_gaussians_to_pixel)
        )
        
         Pixel_group_gradient_merge
        (


        );

    end

    


endgenerate






// 메모리 이동 관련인데 아직 어떻게 해야 할지 몰라서 모듈이 없고, 외부 메모리 -> 내부 메모리에는 이걸 이동해야 된다 라고 생각하시면 될 것 같습니다.

Pixel_group_memory #()
    Exp_memory_to_Block_memory(
        .clk(clk),
        .rst_n(rst_n),

         // Top 메모리 -> Block 메모리로 진입하는 신호 (Top -> Bottom)
        .point_list_from_memory(point_list_from_Block),
        .ranges_from_memory(ranges_from_Block),
        .mean2D_from_memory(mean2D_from_Block),
        .conic_opacity_from_memory(conic_opacity_from_Block),
        .gaussian_color_from_memory(gaussian_color_from_Block),
        .gaussian_depth_from_memory(gaussian_depth_from_Block),
        .final_Ts_from_memory(final_Ts_from_Block),
        .n_contrib_from_memory(n_contrib_from_Block),
        .dL_dpixel_from_memory(dL_dpixel_from_Block),
        .dL_dpixel_depth_from_memory(dL_dpixel_depth_from_Block),
        .W_from_memory(W_from_Block),
        .H_from_memory(H_from_Block),

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
