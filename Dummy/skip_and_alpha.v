`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/14 17:31:43
// Design Name: 
// Module Name: skip_logic
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


module skip_and_alpha
    #(BLOCK_SIZE = 16)
    (
    input wire clk,
    input wire rst_n,

    input wire [31:0] block_id [1:0], // block id x:0 y:1 (int)

    input wire done,

    input wire [31:0] mean2D [1:0], // fp32 {x, y} = {0, 1}
    input wire [31:0] conic_opacity [3:0], // fp32 {x, y, z, w} = {0, 1, 2 ,3}
    input wire [7:0] pixel_id, // int 0 ~ 255

    output reg skip, // can Be work as valid
    // output reg done,
    output reg [31:0] alpha

    //for test
    ,output reg [31:0] pixel_using [1:0] //int 32
    );

    // 0 : x , 1 : y ...

    // const float2 xy = collected_xy[j];
    // const float2 d = { xy.x - pixf.x, xy.y - pixf.y };
    // const float4 con_o = collected_conic_opacity[j];
    // const float power = -0.5f * (con_o.x * d.x * d.x + con_o.z * d.y * d.y) - con_o.y * d.x * d.y;

    reg [31:0] d [1:0]; // fp32  fp32 - int32 이거 계산해야되고
    reg [31:0] power;
    
    wire [7:0] current_pixel_helper;
    wire [31:0] current_pixel [1:0];
    wire [31:0] temp1, temp2, temp3;
    
    // assign current_pixel [0] = {block_id[0] << $clog2(BLOCK_SIZE), pixel_id[7:4]}; // int 32, pixel coordinate
    // assign current_pixel [1] = {block_id[1] << $clog2(BLOCK_SIZE), pixel_id[3:0]}; // int 32, pixel coordinate


    assign current_pixel [0] = {block_id[0][(31-$clog2(BLOCK_SIZE)):0], pixel_id[7:4]}; // int 32, pixel coordinate
    assign current_pixel [1] = {block_id[1][(31-$clog2(BLOCK_SIZE)):0], pixel_id[3:0]}; // int 32, pixel coordinate

    // assign temp1 
    // assign temp2 

    always @ (*) begin
        skip = 1'b0;
        alpha = 32'b0;

        pixel_using [0] = current_pixel[0];
        pixel_using [1] = current_pixel[1];
        skip = done;

    end




endmodule
