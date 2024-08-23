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
    
    // input color instance  
    // color RGB channel required
    input wire [31:0] input_color [1:0],
    input wire [31:0] background_color [1:0],
    
    // opacity cut and n_touched
    input wire [31:0] transmittance_cut,
    input wire [31:0] n_touched [19:0],
    
    // shared memory
    input wire [31:0] shared_id [19:0],
    // x for one dim, y for one dim unsigned 20 bit = 542487
    input wire [31:0] shared_xy [19:0][1:0],
    input wire [31:0] shared_conic_opacity [19:0],
    input wire [31:0] shared_depth [19:0],
    
    // output value
    output reg [31:0] out_depth,
    output reg [31:0] out_color [1:0],
    output reg [31:0] transmittance,
    output reg [31:0] n_contrib,
    output reg [31:0] out_opacity,

    // Using ready-valid handshake
    // input ready-valid protocol
    input wire i_valid,
    output reg o_ready,
    
    // output ready-valid protocol
    input wire i_ready,
    output reg o_valid
    );
    
    always @ (posedge clk) begin
        if (!rstn) begin
        
        end

        else begin

        end
    
    end
    
    
    
        
    
endmodule
