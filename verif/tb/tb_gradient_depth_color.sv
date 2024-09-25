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
    wire [95:0] dL_dcolors;
    wire [31:0] dL_ddepth;

    wire [95:0] accum_rec;
    wire [95:0] color_out;
    wire [31:0] accum_rec_depth;
    wire [31:0] depth_out;
    wire [31:0] alpha_out;
    
   
    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_skip_and_alpha, "+all");
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
        .dL_dcolors(dL_dcolors),
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


        skip = 1'b0;
        T_in = 32'h3ee0296b; // Tin = Ti , Ti+1 / (1- ai) 0.437816
        alpha_in = 32'h3b8d21bc; // 0.004307

        alpha_before = 32'h3f05dce8; // 0.522902
        color_before = 96'h3f83ccb8_3f832d1b_3f886b40; // R: 1.029685 G: 1.024814 B: 1.065773
        depth_before = 32'h3f821a80 ;// 1.0164337158
        accum_rec_before = 96'h3f81a5a9_3f7d3d21_3f75e7a7 ; // R: 1.012868 G: 0.989214 B: 0.960566
        accum_rec_depth_before = 32'h3f826e22 ; // 1.018986

        gaussian_color = 96'h3f7c8206_3f7167ec_3f68c415; // R: 0.986359 , G: 0.942992, B: 0.909242
        gaussian_depth = 32'h3f76e7e6; //0.964476

        dL_dpixel; 
        dL_dpixel_depth;


        #10;



        
        // xy : 320.0527 232.1980
        mean2D = 64'h43a006bf_436832b0;
        // conic opacity : 0.0069 0.0063 0.0083 0.9328
        conic_opacity =128'h3be21965_3bce703b_3c07fcb9_3f6ecbfb;

        $display("Expected alpha %h\n",32'h3f3a0f91);
        $display("Result alpha %h\n\n",alpha);
        #10;



        $display("Test is finished without Error!\n");


        $finish;
    end

endmodule
