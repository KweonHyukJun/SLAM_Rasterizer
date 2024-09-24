//////////////////////////////////////////////////////////////////////////////////
// Company: Sungkyunkwan Univ. IDS LAB  
// Engineer: Kweon Hyuk Jun 
// 
// Create Date: 2024/08/23 18:02:07
// Design Name: Rasterizer
// Module Name: Rasterizer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// One Unit for One pixel
module Rasterizer_unit(

    //reset and clock
    input wire clk,
    input wire rstn,
    
    // Backward input and output
    input wire [31:0] block_gaussian_range [1:0],
    input wire [31:0] block_point_list,

    input wire [31:0] block_index [1:0], // block index x at [0] y at [1]

    input wire [31:0] width,
    input wire [31:0] height,
    
    input wire [31:0] background_color [2:0],

    input wire [31:0] means2D [1:0], 
    input wire [31:0] conic_opacity [3:0],
    
    input wire [31:0] colors [2:0],
    input wire [31:0] depths,
    input wire [31:0] final_T,

    input wire [31:0] n_contrib,

    input wire [31:0] dL_dpixels [2:0],
    input wire [31:0] dL_dpixel_depths,

    output reg [31:0] dL_dmean2D [1:0],
    output reg [31:0] dL_dconic [3:0],
    output reg [31:0] dL_dopacity,
    output reg [31:0] dL_dcolors [2:0],
    output reg [31:0] dL_ddepths,

    // Using ready-valid handshake
    // input ready-valid protocol
    input wire i_valid,
    output reg o_ready,
    
    // output ready-valid protocol
    input wire i_ready,
    output reg o_valid
    );

    //gaussian ID 기록해서 Gradient 계산 후 반환해야함

    reg skip = 1'b0;
    reg [31:0] T;
    reg [31:0] next_T;
    reg [31:0] alpha;

    reg [31:0] current_contributor;

    // Phase 0, check for done
    always_comb begin

    end

    // Phase 1, skip logic + alpha return
    always_comb begin
        if (!rstn) begin
            
        end
        else begin
            
        end
    
    end
    
    //skip Logic 이후에 T가 업데이트되어 배출 가능 및 Phase 2의 Gradient Logic에 사용

    // Phase 2, Gradient Logic 1 (depth, color)




    // Phase 3, T and alpha update Logic




    // Phase 4, Gradient Logic 2 (mean2D, conic2D, opacity)
    


    // Phase 5, Gradient Summation Logic 
    
        
    
endmodule
