//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/19 11:25:32
// Design Name: 
// Module Name: tb_INT_tester
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

module tb_gradient_depth_color();
    //input
    reg clk, rst_n, skip;

    reg [31:0] alpha_before; // last_alpha 픽셀에서 유지하는 값
    reg [95:0] color_before; // last_color
    reg [31:0] depth_before; // last_depth
    reg [95:0] accum_rec_before; // accum_rec_before
    reg [31:0] accum_rec_depth_before;

    reg [31:0] alpha_in; // alpha_i (이전 step에서 계산한거)
    reg [31:0] T_in; // T_i
    
    reg [95:0] gaussian_color; // | R | G | B |
    reg [31:0] gaussian_depth;

    reg [95:0] dL_dpixel; // dL_dpixel
    reg [31:0] dL_dpixel_depth;

    wire [31:0] dL_dalpha;
    wire [95:0] dL_dcolor;
    wire [31:0] dL_ddepth;

    wire [95:0] accum_rec;
    wire [95:0] color_out;
    wire [31:0] accum_rec_depth;
    wire [31:0] depth_out;
    wire [31:0] alpha_out;
    

   
    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_gradient_depth_color, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    gradient_depth_color uut (
        .clk(clk),
        .rst_n(rst_n),
        .skip(skip),

        .alpha_before(alpha_before),
        .color_before(color_before),
        .depth_before(depth_before),
        .accum_rec_before(accum_rec_before),
        .accum_rec_depth_before(accum_rec_depth_before),

        .alpha_in(alpha_in),
        .T_in(T_in),

        .gaussian_color(gaussian_color),
        .gaussian_depth(gaussian_depth),

        .dL_dpixel(dL_dpixel),
        .dL_dpixel_depth(dL_dpixel_depth),

        .dL_dalpha(dL_dalpha),
        .dL_dcolor(dL_dcolor),
        .dL_ddepth(dL_ddepth),

        .accum_rec(accum_rec),
        .color_out(color_out),
        .accum_rec_depth(accum_rec_depth),
        .depth_out(depth_out),
        .alpha_out(alpha_out)
        
    );
    
    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        skip = 1'b1;
        alpha_before = 32'h0;    
        color_before = 96'h0;
        depth_before = 32'h0;
        accum_rec_before =96'h0;
        accum_rec_depth_before = 32'h0;
        alpha_in = 32'h0;
        T_in = 32'h0;
        gaussian_color = 96'h0;
        gaussian_depth = 32'h0;
        dL_dpixel = 96'h0;
        dL_dpixel_depth = 32'h0;
        #10;


        //input 목록
        skip = 1'b0;
        T_in = 32'h3f5473ac; // Tin = Ti , Ti+1 / (1- ai) 0.829890
        alpha_in = 32'h3c7398e9; // 0.014868

        alpha_before = 32'h3bb6ae7d; // 0.005575
        color_before = 96'h3f83a494_3f8380aa_3f809a67; // R: 1.028460 G: 1.027364 B: 1.004712
        depth_before = 32'h3f867808 ;// 1.0505380630
        accum_rec_before = 96'h3f56cce6_3f4b1e3a_3f49b9fa; // R: 0.839064 G: 0.793430 B: 0.787994
        accum_rec_depth_before = 32'h3f8b82f5 ; // 1.089934

        gaussian_color = 96'h3f700885_3f6c03de_3f6eeec8; // R: 0.937630 , G: 0.921934, B: 0.933331
        gaussian_depth = 32'h3f85aa26; //1.044255

        dL_dpixel = 96'hb58313b8_b58313b8_b58313b8; // R, G, B: -0.0000009766
        dL_dpixel_depth = 32'hb4aec061; // -0.0000003255




        #10;
        skip = 1'b0;
        T_in = 32'h3f07430f; // Tin = Ti , Ti+1 / (1- ai) 0.528367
        alpha_in = 32'h3d001712; // 0.031272

        alpha_before = 32'h3de05144; // 0.109530
        color_before = 96'h3f7f1444_3f7c2d28_3f7fccf3; // R: 0.996403 G: 0.985064 B: 1.004712
        depth_before = 32'h3f8616e7 ;// 1.0475739241
        accum_rec_before = 96'h3f4e527a_3f403b92_3f3accc4; // R: 0.805946 G: 0.750909 B: 0.729687
        accum_rec_depth_before = 32'h3f88d659 ; // 1.06904137

        gaussian_color = 96'h3f8127d4_3f8105af_3f813059; // R: 1.009028 , G: 1.007986, B: 1.009288
        gaussian_depth = 32'h3f858ef3; //1.043425

        dL_dpixel = 96'hb58313b8_b58313b8_358313b8; // R, G  -0.0000009766, B: 0.0000009766
        dL_dpixel_depth = 32'hb4aec061; // -0.0000003255


        #10; //for skip = 1 data



        $display("Test is finished without Error!\n");


        $finish;
    end

endmodule
