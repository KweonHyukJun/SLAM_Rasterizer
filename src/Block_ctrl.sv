module Block_ctrl 
    #(       
        parameter BLOCK_SIZE = 16,
        parameter exponent_bit = 8,
        parameter mantissa_bit = 7,
        parameter precision = 16,
        parameter max_H = 1080,
        parameter max_W = 1920,
        parameter max_ranges = 10000
    ) 
(
    input wire clk,
    input wire rst_n,

    input wire [11:0] W,
    input wire [11:0] H,

    input wire [31:0] ranges [1:0], // gaussian ranges in this block

    input wire [31:0] gaussian_id [max_ranges - 1 :0], // gaussian range만큼 만들어야 함
    input wire [(2*precision)-1 :0] mean2D [max_ranges - 1 :0], // gaussian range만큼 만들어야 함
    input wire [(4*precision)-1 :0] conic_opacity [max_ranges - 1 :0],
    input wire [(3*precision)-1 :0] gaussian_color [max_ranges - 1 :0],
    input wire [precision-1 :0] gaussian_depth [max_ranges - 1 :0],
    
    // H * W만큼 만들어야 하는 변수들
    input wire [31:0] Final_T [( max_H * max_W )-1:0],
    input wire [(3*precision)-1 :0] dL_dpixel [( max_H * max_W)-1:0],
    input wire [precision-1 :0] dL_dpixel_depth [( max_H * max_W)-1:0], 

    input wire [31:0] pixel_touches [( max_H * max_W)-1:0],

    output reg [31:0] gaussian_id_out [max_ranges - 1 :0],
    output reg [(2 * precision) - 1:0] dL_dmean2D_out [max_ranges - 1 :0], 
    output reg [(4 * precision) - 1:0] dL_dconic_out [max_ranges - 1 :0], 
    output reg [precision - 1:0] dL_dopacity_out [max_ranges - 1 :0], 
    output reg [(3 * precision) - 1:0] dL_dcolor_out [max_ranges - 1 :0], 
    output reg [precision - 1:0] dL_ddepth_out [max_ranges - 1 :0] 
);



endmodule