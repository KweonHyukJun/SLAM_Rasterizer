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
    reg i_valid;

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

    wire dL_dalpha_valid;
   
    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_gradient_depth_color, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    gradient_depth_color uut (
        .clk(clk),
        .rst_n(rst_n),
        .skip(skip),
        .i_valid(i_valid),

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
        .alpha_out(alpha_out),
        
        .dL_dalpha_valid(dL_dalpha_valid)
    );
    
    always begin
        #5 clk = ~clk;  // Toggle clock every half period
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        skip = 1'b1;
        i_valid = 1'b0;
        alpha_before = 32'h0;    
        color_before = 96'h0;
        depth_before = 32'h0;
        accum_rec_before = 96'h0;
        accum_rec_depth_before = 32'h0;
        alpha_in = 32'h0;
        T_in = 32'h0;
        gaussian_color = 96'h0;
        gaussian_depth = 32'h0;
        dL_dpixel = 96'h0;
        dL_dpixel_depth = 32'h0;
        #12;
        rst_n = 1'b1;
        #1;


       //input 목록
        skip = 1'b0;
        i_valid = 1'b1;
        T_in = 32'h3d89b845; // 0.067246
        alpha_in = 32'h3d9741d1; // 0.073856

        alpha_before = 32'h3d46b378; // 0.048511
        color_before = 96'h3f4b67e4_3f2d5183_3f0a12a5; // R: 0.794554 G: 0.677025 B: 0.539347
        depth_before = 32'h3f871c0e ;// 1.0555436611
        accum_rec_before = 96'h3f78e3ce_3f78a6b9_3f831a76; // R: 0.972226 G: 0.971294 B: 1.024245
        accum_rec_depth_before = 32'h3f86e173 ; // 1.05375516

        gaussian_color = 96'h3e3a8da8_3e14a59c_3e45870e; // R: 0.182181 , G: 0.145163, B: 0.192898
        gaussian_depth = 32'h3f84c6b5; // 1.037314

        dL_dpixel = 96'h358313b8_b58313b8_b58313b8; // R: 0.0000009766, G: -0.0000009766 B : -0.0000009766
        dL_dpixel_depth = 32'hb4aec061; // -0.0000003255  

        //expected dL_dalpha = 0.000000055411938


        #10;
        i_valid = 1'b1;
        skip = 1'b1;
        T_in = 32'h3d89b845; // 0.067246
        alpha_in = 32'h3b6c204f; // 0.003603

        alpha_before = 32'h3d9741d1; // 0.073856
        color_before = 96'h3e3a8da8_3e14a59c_3e45870e; // R: 0.182181 G: 0.145163 B: 0.192898
        depth_before = 32'h3f84c6b8 ;// 1.0373144150
        accum_rec_before = 96'h3f76aef3_3f74ff22_3f8017a9; // R: 0.963607 G : 0.957018 B: 1.000722
        accum_rec_depth_before = 32'h3f86e44a ; // 1.05384183

        gaussian_color = 96'h3f79450f_3f780e39_3f783b82; // R: 0.973710 , G: 0.968967, B:  0.969658
        gaussian_depth = 32'h3f84556d; //1.033857

        dL_dpixel = 96'h358313b8_b58313b8_b58313b8; // R : 0.0000009766 G ,B : -0.0000009766,
        dL_dpixel_depth = 32'hb4aec061; // -0.0000003255

        // expected dL_dalpha = 0.000000002356258
        // #15; //for skip = 1 data
        #15;


        $display("Test is finished without Error!\n");


        $finish;
    end

endmodule
