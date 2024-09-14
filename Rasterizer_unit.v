`timescale 1ns / 1ps
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


module Rasterizer_unit(

    //reset and clock
    input wire clk,
    input wire rstn,
    
    // Backward 다시 짜기
    input wire [31:0] block_gaussian_range [1:0],
    input wire [31:0] block_point_list,

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
    input wire [31:0] dL_ddepths,

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
    
    reg [31:0] alpha;
    reg [31:0] T = 32'h3f80_0000;

    reg skip = 1'b0;
    reg [31:0] T;
    reg [31:0] alpha;

    reg [31:0] contributor = 32'h0000_0000; //unsigned int
    reg [31:0] last_contributor = 32'h0000_0000; //unsigned int


    // Phase 1, skip logic
    always @ (posedge clk) begin
        if (!rstn) begin
            
        end

        else begin

        end
    
    end
    
    // Phase 2, Gradient Logic 1 (depth, color)




    // Phase 3, T and alpha update Logic




    // Phase 4, Gradient Logic 2 (mean2D, conic2D, opacity)
    


    // Phase 5, Gradient Summation Logic 
    
        
    
endmodule
