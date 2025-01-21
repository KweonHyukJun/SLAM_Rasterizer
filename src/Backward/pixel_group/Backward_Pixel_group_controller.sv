module Backward_Pixel_group_controller #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 3, // in one pixel unit, gaussians
    parameter num_pixels = 16, // number of pixel units
    parameter GID_bit = 24    
    ) 

    (
    input wire clk,
    input wire rst_n,

    // Input from Block Controller (Currently Testbench)
    input wire [11:0] W,
    input wire [11:0] H,
    input wire [15:0] block_id,
    // input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] start_pixel_id [num_pixels-1:0],



    // Output to Block Controller (Currently Testbench)
    output wire all_block_work_done_out, // Gradient도 인지 아니면 Raster만 done인지도 판단 필요
    output wire request_pixel_values_out, // 다음 Pixel 값 n_contrib, T, Loss 요청
    output wire request_gaussian_window_values_out, // Window에 넣을 다음 Gaussian 값 요청

    // Input from Backward Pixel Group Unit
    input wire stall_to_controller_from_rasterizer [num_pixels-1:0],
    input wire last_input_done_from_rasterizer [num_pixels-1:0],


    // Output to Backward Pixel Group Unit

    output reg start [num_pixels-1:0],
    output reg [(3 * precision) - 1:0] dL_dpixel [num_pixels-1:0],
    output reg [precision - 1:0] dL_dpixel_depth [num_pixels-1:0],
    output reg [precision - 1:0] T_first [num_pixels-1:0],
    output reg i_valid [gaussian_inputs * num_pixels - 1:0],
    output reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id_to_pixel [num_pixels-1:0],
    output reg last_input_done_to_pixel [num_pixels-1:0],



    // Input from Backward Gradient Merge Unit SRAM


    // Output to Backward Gradient Merge Unit SRAM
    output wire WEB_to_SRAM [num_pixels-1:0],
    output wire REB_to_SRAM [num_pixels-1:0],


    // Input from SRAM, Pixel values (Currently Testbench)
        // As Backward Rasterizer Input
    input wire [GID_bit-1:0] next_n_contrib_from_SRAM [num_pixels-1:0],
    input wire [precision-1:0] next_T_first_from_SRAM [num_pixels-1:0],
    input wire [(3 * precision)-1:0] next_dL_dpixel_from_SRAM [num_pixels-1:0],
    input wire [precision-1:0] next_dL_dpixel_depth_from_SRAM [num_pixels-1:0],


    // Input from SRAM, Window values
    input wire [GID_bit-1:0] gaussian_id_from_SRAM [num_pixels-1:0],
    input wire [(3 * precision)-1:0] gaussian_color_from_SRAM [num_pixels-1:0],
    input wire [precision-1:0] gaussian_depth_from_SRAM [num_pixels-1:0],
    input wire [(2 * precision)-1:0] mean2D_from_SRAM [num_pixels-1:0],
    input wire [(4 * precision)-1:0] conic_opacity_from_SRAM [num_pixels-1:0]
    
    

    // Output to SRAM (Currently Testbench)
        // As Backward Gradient Merge Unit Control to SRAM
    // output wire WEB_to_SRAM [num_pixels-1:0],
    // output wire REB_to_SRAM [num_pixels-1:0]

    );



    //////////////////////// GlobalPixel Control ////////////////////////
    // Window value and W, H, Block id 보관
    // 가동중인 Row에 대한 컨트롤 

        // FF Register

        reg [$clog2(num_pixels):0] row_current;
        reg [$clog2(num_pixels):0] last_input_done_current;



            // Out Register

            // Next State Register


        // Comb Register
        reg [$clog2(num_pixels):0] row_next;
        reg [$clog2(num_pixels):0] last_input_done_next;
        


        // Wire


    

    //////////////////////// SubPixel Control ////////////////////////

        // FF Register
        reg started [num_pixels-1:0];


            // Next State Register
            reg [precision-1:0] T_first_next [num_pixels-1:0];
            reg [(3 * precision)-1:0] dL_dpixel_next [num_pixels-1:0];
            reg [precision-1:0] dL_dpixel_depth_next [num_pixels-1:0];
            reg [GID_bit-1:0] gaussian_id_next [num_pixels-1:0];


        // Comb Register


        // Wire


    //////////////////////// Gaussian Window ////////////////////////

        // FF Register

            // Out Register

            // Next State Register


        // Comb Register


        // Wire


    //////////////////////// Gradient Merge SRAM Control ////////////////////////

        // FF Register

            // Out Register

            // Next State Register


        // Comb Register


        // Wire
    

    always_ff @(posedge clk) begin
        if (!rst_n) begin

        end
        
        else begin
            


        end
    end






endmodule