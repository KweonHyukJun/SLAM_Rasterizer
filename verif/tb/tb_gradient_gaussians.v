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

module tb_gradient_gaussians();
    //input
    // reg clk;
    // reg rst_n;
    // reg skip;

    reg [31:0] H, W;
    reg i_valid;

    reg [31:0] G;
    reg [63:0] d;
    reg [31:0] dL_dalpha;
    reg [127:0] conic_opacity; // | X | Y | Z | W |

    reg [63:0] dL_dmean2D;
    reg [127:0] dL_dconic;
    reg [31:0] dL_dopacity; //tracking시 불필요
 
    reg gradient_valid;

    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_gradient_gaussians, "+all");
    end


    // Instantiate the DUT (Device Under Test)
    gradient_gaussians uut (
        //input
        // .clk(clk),
        // .rst_n(rst_n),
        // .skip(skip),
        .i_valid(i_valid),

        .H(H),
        .W(W),

        .G(G),
        .d(d),
        .dL_dalpha(dL_dalpha),
        .conic_opacity(conic_opacity),

        //output
        .dL_dmean2D(dL_dmean2D),
        .dL_dconic(dL_dconic),
        .dL_dopacity(dL_dopacity),

        .gradient_valid(gradient_valid)
    );

    initial begin
        i_valid = 1'b0;
        G = 32'h0;
        d = 64'h0;
        dL_dalpha = 32'h0;
        conic_opacity = 128'h0;
        H = 32'd0;
        W = 32'd0;
        #5;


        //input 목록
        i_valid = 1'b1;
        H = 32'd480;
        W = 32'd640;

        G = 32'h3f01289e; // 0.504526 
        d = 64'hc0b64b40_bfa085fd ; // -5.696686 -1.254089
        dL_dalpha = 32'hb4b5c8d4 ; // -0.0000003386
        conic_opacity = 128'h3d245910_39638a7e_3d243351_3f7e61bf ; // 0.040124 0.000217 0.040088 0.993679
        #20;

        G = 32'h3f19859d; // 0.599695
        d = 64'h4051afff_40581f00 ; // 3.276367 3.376892
        dL_dalpha = 32'hb4f2fcdf ; // -0.0000004526
        conic_opacity = 128'h3d413db8_b9e7bc3c_3d3cf0b7_3f7e7925 ; // 0.047178 -0.000442 0.046128 0.994036
        

        #20; //for skip = 1 data
        i_valid = 1'b0;


        #10 
        i_valid = 1'b1;

        // G : 0.090177

        G = 32'h3db8aeb8;

        // d : -4.856506 9.832947
        d = 64'hc09b687f_411d53c0;
        // dL_dalpha : -0.0000003382
        dL_dalpha = 32'hb4b591db;
        // conic opacity : 0.041181 -0.000942 0.038792 0.994194
        conic_opacity = 128'h3d28ad69_ba76f08d_3d1ee45c_3f7e837f;

        // skip 0
        // dL_dmean2D : -0.0000020305 0.0000028092 // -0.0000020303617 0.0000028090235
        // dL_dconic2D : 0.0000003576 -0.0000007240 0.0000014659 0.9941938519
        // dL_dopacity -0.0000000305

        # 10;

        $display("Test is finished without Error!\n");


        $finish;
    end

endmodule
