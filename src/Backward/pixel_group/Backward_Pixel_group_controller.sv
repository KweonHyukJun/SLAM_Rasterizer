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
    input wire [(2 * $clog2(BLOCK_SIZE) - 1): 0] start_pixel_id [num_pixels-1:0],



    // Output to Block Controller (Currently Testbench)


    // Input from Backward Pixel Group Unit
    input wire stall_to_controller [num_pixels-1:0],
    input wire last_input_done [num_pixels-1:0],

    // Output to Backward Pixel Group Unit

    output reg start [num_pixels-1:0],
    output reg [(3 * precision) - 1:0] dL_dpixel [num_pixels-1:0],
    output reg [precision - 1:0] dL_dpixel_depth [num_pixels-1:0],
    output reg [precision - 1:0] T_first [num_pixels-1:0],
    output reg i_valid [gaussian_inputs * num_pixels - 1:0],
    output reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id_to_pixel [num_pixels-1:0],



    // Input from Backward Gradient Merge Unit

    // Output to Backward Gradient Merge Unit
    output wire WEB_to_SRAM [num_pixels-1:0],
    output wire REB_to_SRAM [num_pixels-1:0],




    // Input from SRAM (Currently Testbench)
        // As Backward Rasterizer Input
    input wire [23:0] n_contrib_from_SRAM [num_pixels-1:0]


    // Output to SRAM (Currently Testbench)
        // As Backward Gradient Merge Unit Control to SRAM
    // output wire WEB_to_SRAM [num_pixels-1:0],
    // output wire REB_to_SRAM [num_pixels-1:0]

    );

    //////////////////////// GlobalPixel Control ////////////////////////
        // FF Register

            // Out Register

            // Next State Register


        // Comb Register


        // Wire


    

    //////////////////////// SubPixel Control ////////////////////////

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